import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/tables/app_defaults.dart';
import '../event_bus/bus.dart';
import '../event_bus/events.dart';
import 'worker_types.dart';

const _uuid = Uuid();

class MidnightSettlementService {
  MidnightSettlementService(this.db);

  final AppDatabase db;

  Future<bool> hasRunForDate(DateTime targetDate) async {
    final workerType = WorkerType.midnightRollover.dbValue;
    final normalized = _dateOnly(targetDate);
    final rows = await (db.select(db.backgroundWorkerLog)
          ..where((t) => t.workerType.equals(workerType) & t.targetDate.equals(normalized)))
        .get();
    return rows.isNotEmpty;
  }

  Future<void> markRunSuccess(DateTime targetDate) async {
    final normalized = _dateOnly(targetDate);
    await db.into(db.backgroundWorkerLog).insertOnConflictUpdate(
          BackgroundWorkerLogCompanion.insert(
            workerId: 'midnight-${normalized.toIso8601String()}',
            userId: _systemUserId,
            workerType: WorkerType.midnightRollover.dbValue,
            executedAt: DateTime.now(),
            targetDate: normalized,
            status: 'SUCCESS',
          ),
        );
  }

  Future<void> run(DateTime targetDate) async {
    final normalized = _dateOnly(targetDate);
    await db.transaction(() async {
      await _todoRollover(normalized);
      await _petStatusSettlement(normalized);
      await _netWorthSnapshot(normalized);
      await postDueSubscriptionBillings(normalized);
      await _relationshipDecay(normalized);
      await _dailyAggregationCache(normalized);
      await markRunSuccess(normalized);
    });
  }

  Future<void> _todoRollover(DateTime targetDate) async {
    final openTodos = await (db.select(db.todoExecutionList)
          ..where((t) => t.isCompleted.equals(false) & t.targetDate.isSmallerOrEqualValue(targetDate)))
        .get();

    for (final todo in openTodos) {
      await (db.update(db.todoExecutionList)..where((t) => t.todoId.equals(todo.todoId))).write(
        TodoExecutionListCompanion(
          delayCount: Value(todo.delayCount + 1),
          targetDate: Value(targetDate.add(const Duration(days: 1))),
        ),
      );
    }
  }

  Future<void> _petStatusSettlement(DateTime targetDate) async {
    final recentSportLogs = await (db.select(db.petActionQuickLog)
          ..where((t) => t.actionType.equals('SPORT') & t.createdAt.isBiggerOrEqualValue(targetDate.subtract(const Duration(days: 7)))))
        .get();

    final petRows = await db.select(db.petStatusCore).get();
    for (final pet in petRows) {
      final totalSport = recentSportLogs.fold<double>(0, (sum, row) => sum + row.valueNumeric);
      final bodyDelta = totalSport >= 120 ? 10 : -2;
      final nextBody = (pet.bodyShapePoints + bodyDelta).clamp(0, 100).toInt();
      await (db.update(db.petStatusCore)..where((t) => t.petId.equals(pet.petId))).write(
        PetStatusCoreCompanion(
          bodyShapePoints: Value(nextBody),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> _netWorthSnapshot(DateTime targetDate) async {
    final assets = await db.select(db.assetInventory).get();
    final accounts = await db.select(db.paymentAccounts).get();

    final totalAsset = assets.fold<double>(0, (sum, asset) => sum + asset.purchasePrice);
    final totalCashAsset = accounts.where((a) => !a.isLiability).fold<double>(0, (sum, a) => sum + a.balance);
    final totalLiability = accounts.where((a) => a.isLiability).fold<double>(0, (sum, a) => sum + a.balance.abs());

    await db.into(db.assetValueSnapshots).insertOnConflictUpdate(
          AssetValueSnapshotsCompanion.insert(
            snapshotId: 'net-worth-${targetDate.toIso8601String()}',
            userId: _systemUserId,
            snapshotDate: targetDate,
            totalAssetValue: Value(totalAsset + totalCashAsset),
            totalLiabilityValue: Value(totalLiability),
            netWorth: Value(totalAsset + totalCashAsset - totalLiability),
          ),
        );
  }

  /// 订阅到期自动入账（P1-4）。
  ///
  /// 对每个到期订阅（`isActive && nextBillingDate <= targetDate`）按计费周期
  /// post 一笔 `AMORTIZED` 交易：金额=账单额、覆盖区间=本计费周期实际天数
  /// （含头含尾）、`sourceSubscriptionId` 回链订阅、扣对应账户余额（按全额，
  /// 现金流不变，摊销只改分析口径 P1-5），并推进 `nextBillingDate`。
  ///
  /// **幂等**：以「`sourceSubscriptionId` + 周期起点 `amortizeStartDate`」为
  /// 语义键查重——同一订阅同一周期已入账则跳过（不重复扣款、不重复入账），但仍
  /// 推进 `nextBillingDate` 跳过该周期（避免死循环 / 上次部分失败时反复处理同一
  /// 周期）。查重走这两列而非 transactionId——因 transactionId 上限 36 字符，
  /// 容不下「订阅 UUID + 周期」拼接；语义列查重更稳且天然区分不同订阅/周期。
  ///
  /// **落后补账（catch-up）**：若 `nextBillingDate` 远早于 `targetDate`（如多日
  /// 未结算），按周期逐个补账，每周期一笔、互不重复。
  ///
  /// 返回本次**新**入账的交易笔数（已入账的周期不计入）。预期调用方已在事务内
  /// （[run]）；单线程 isolate 内顺序执行，查→插原子性天然成立。
  Future<int> postDueSubscriptionBillings(DateTime targetDate) async {
    final target = _dateOnly(targetDate);
    final dueSubs = await (db.select(db.subscriptionServices)
          ..where((t) => t.isActive.equals(true) & t.nextBillingDate.isSmallerOrEqualValue(targetDate)))
        .get();

    var posted = 0;
    for (final sub in dueSubs) {
      // 逐周期推进，直到 nextBillingDate 越过 targetDate。每轮处理一个到期周期。
      var nextBillingDate = _dateOnly(sub.nextBillingDate);
      while (!nextBillingDate.isAfter(target)) {
        final advanced = _advanceBillingDate(nextBillingDate, sub.billingCycle);
        final periodStart = nextBillingDate;
        // 本周期 = [periodStart, advanced 前一天]，含头含尾（与摊销算法 §3.3 同口径）。
        final periodEnd = _dateOnly(advanced).subtract(const Duration(days: 1));

        // 幂等查重：同订阅同周期（sourceSubscriptionId + amortizeStartDate）
        // 是否已入账。注：本查询按两列过滤——P1-4 不改 schema 故未建组合索引，
        // 后台低频查询（每订阅每周期一次）全表扫可接受；下次改 schema 时可补索引。
        final dup = await (db.select(db.financialTransaction)
              ..where((t) =>
                  t.sourceSubscriptionId.equals(sub.subscriptionId) &
                  t.amortizeStartDate.equals(periodStart)))
            .get();
        if (dup.isEmpty) {
          await db.into(db.financialTransaction).insert(
                FinancialTransactionCompanion.insert(
                  transactionId: _uuid.v4(),
                  userId: sub.userId,
                  flowType: 'EXPENSE',
                  amount: sub.amount,
                  categoryId: 'subscription',
                  accountId: sub.accountId,
                  loggedAt: target,
                  remark: Value('${sub.serviceName} 自动扣费'),
                  expenseNature: const Value('AMORTIZED'),
                  amortizeStartDate: Value(periodStart),
                  amortizeEndDate: Value(periodEnd),
                  sourceSubscriptionId: Value(sub.subscriptionId),
                ),
              );
          // 余额增量扣减（SQL 表达式，原子、避免「先读再写回」）。customUpdate
          // 声明受影响表 payment_accounts，使 watchAccounts 流在 commit 后重发，
          // 余额 UI 无需手动 invalidate。AMORTIZED 仍按全额扣（现金流不变）。
          await db.customUpdate(
            'UPDATE payment_accounts SET balance = balance - ? WHERE account_id = ?',
            variables: [Variable.withReal(sub.amount), Variable.withString(sub.accountId)],
            updates: {db.paymentAccounts},
          );
          // 通知其它模块订阅扣费（事件契约，§3.5）。注：worker 跑在后台 isolate，
          // globalEventBus 是进程级单例——主 isolate 的监听者收不到此处 fire；
          // 此调用为前台触发（如 app 打开时补账）时的契约，isolate 内为 no-op。
          globalEventBus.fire(SubscriptionBillingEvent(
            subscriptionId: sub.subscriptionId,
            amount: sub.amount,
            accountId: sub.accountId,
          ));
          posted++;
        }

        // 推进 nextBillingDate 跳过本周期（无论本次是否新入账），避免重复处理。
        await (db.update(db.subscriptionServices)
              ..where((t) => t.subscriptionId.equals(sub.subscriptionId)))
            .write(SubscriptionServicesCompanion(nextBillingDate: Value(_dateOnly(advanced))));
        nextBillingDate = _dateOnly(advanced);
      }
    }
    return posted;
  }

  Future<void> _relationshipDecay(DateTime targetDate) async {
    final contacts = await db.select(db.relationshipNetwork).get();

    for (final contact in contacts) {
      if (contact.lastInteractionDate == null) continue;
      final days = targetDate.difference(_dateOnly(contact.lastInteractionDate!)).inDays;
      if (days < contact.crisisThresholdDays) continue;

      final nextWarmth = (contact.warmthScore - 5).clamp(0, AppDefaults.defaultWarmthScore).toInt();
      await (db.update(db.relationshipNetwork)..where((t) => t.contactId.equals(contact.contactId))).write(
        RelationshipNetworkCompanion(
          warmthScore: Value(nextWarmth),
        ),
      );
    }
  }

  Future<void> _dailyAggregationCache(DateTime targetDate) async {
    final start = targetDate;
    final end = targetDate.add(const Duration(days: 1));

    final transactions = await (db.select(db.financialTransaction)
          ..where((t) => t.loggedAt.isBiggerOrEqualValue(start) & t.loggedAt.isSmallerThanValue(end)))
        .get();
    final todos = await (db.select(db.todoExecutionList)
          ..where((t) => t.targetDate.equals(targetDate)))
        .get();
    // P5-2：摄入/消耗改读健康新表——MealLog.snapCalories（摄入）/ ExerciseLog
    // .caloriesBurned（消耗），均为记录时冻结快照（§1.2.4），不再从宠物
    // FEED/SPORT 汇总。睡眠时长仍来自宠物 REST 记录（休息入口未迁，仍记宠物侧）。
    final mealLogs = await (db.select(db.mealLog)
          ..where((t) => t.loggedAt.isBiggerOrEqualValue(start) & t.loggedAt.isSmallerThanValue(end)))
        .get();
    final exerciseLogs = await (db.select(db.exerciseLog)
          ..where((t) => t.loggedAt.isBiggerOrEqualValue(start) & t.loggedAt.isSmallerThanValue(end)))
        .get();
    final petLogs = await (db.select(db.petActionQuickLog)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerThanValue(end)))
        .get();
    final reviews = await (db.select(db.dailyReviewLog)
          ..where((t) => t.reviewDate.equals(targetDate)))
        .get();

    final totalExpense = transactions.where((t) => t.flowType == 'EXPENSE').fold<double>(0, (sum, t) => sum + t.amount);
    final totalIncome = transactions.where((t) => t.flowType == 'INCOME').fold<double>(0, (sum, t) => sum + t.amount);
    final calorieIn = mealLogs.fold<double>(0, (sum, m) => sum + m.snapCalories);
    final calorieOut = exerciseLogs.fold<double>(0, (sum, e) => sum + e.caloriesBurned);
    final sleepHours = petLogs.where((t) => t.actionType == 'REST').fold<double>(0, (sum, t) => sum + t.valueNumeric);

    await db.into(db.dailyAggregationCache).insertOnConflictUpdate(
          DailyAggregationCacheCompanion.insert(
            cacheDate: targetDate,
            userId: _systemUserId,
            totalExpense: Value(totalExpense),
            totalIncome: Value(totalIncome),
            transactionCount: Value(transactions.length),
            todoCompletedCount: Value(todos.where((t) => t.isCompleted).length),
            todoDelayedCount: Value(todos.where((t) => !t.isCompleted && t.delayCount > 0).length),
            totalCalorieIntake: Value(calorieIn),
            totalCalorieConsumed: Value(calorieOut),
            sleepHours: Value(sleepHours == 0 ? null : sleepHours),
            moodLabel: Value(reviews.isEmpty ? null : reviews.first.moodTag),
          ),
        );
  }

  DateTime _advanceBillingDate(DateTime current, String cycle) {
    switch (cycle) {
      case 'QUARTERLY':
        return DateTime(current.year, current.month + 3, current.day);
      case 'YEARLY':
        return DateTime(current.year + 1, current.month, current.day);
      case 'MONTHLY':
      default:
        return DateTime(current.year, current.month + 1, current.day);
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

const _systemUserId = 'user-001';
