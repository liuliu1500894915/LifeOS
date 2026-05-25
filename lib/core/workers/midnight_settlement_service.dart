import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/tables/app_defaults.dart';
import 'worker_types.dart';

class MidnightSettlementService {
  MidnightSettlementService(this.db);

  final AppDatabase db;

  Future<bool> hasRunForDate(DateTime targetDate) async {
    final workerType = WorkerType.midnightRollover.name.toUpperCase();
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
            workerType: WorkerType.midnightRollover.name.toUpperCase(),
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
      await _subscriptionAutoBilling(normalized);
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

  Future<void> _subscriptionAutoBilling(DateTime targetDate) async {
    final dueSubs = await (db.select(db.subscriptionServices)
          ..where((t) => t.isActive.equals(true) & t.nextBillingDate.isSmallerOrEqualValue(targetDate)))
        .get();

    for (final sub in dueSubs) {
      await db.into(db.financialTransaction).insert(
            FinancialTransactionCompanion.insert(
              transactionId: 'sub-${sub.subscriptionId}-${targetDate.toIso8601String()}',
              userId: sub.userId,
              flowType: 'EXPENSE',
              amount: sub.amount,
              categoryId: 'subscription',
              accountId: sub.accountId,
              loggedAt: targetDate,
              remark: Value('${sub.serviceName} 自动扣费'),
            ),
          );

      await (db.update(db.subscriptionServices)..where((t) => t.subscriptionId.equals(sub.subscriptionId))).write(
        SubscriptionServicesCompanion(
          nextBillingDate: Value(_advanceBillingDate(sub.nextBillingDate, sub.billingCycle)),
        ),
      );
    }
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
    final petLogs = await (db.select(db.petActionQuickLog)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerThanValue(end)))
        .get();
    final reviews = await (db.select(db.dailyReviewLog)
          ..where((t) => t.reviewDate.equals(targetDate)))
        .get();

    final totalExpense = transactions.where((t) => t.flowType == 'EXPENSE').fold<double>(0, (sum, t) => sum + t.amount);
    final totalIncome = transactions.where((t) => t.flowType == 'INCOME').fold<double>(0, (sum, t) => sum + t.amount);
    final calorieIn = petLogs.where((t) => t.actionType == 'FEED').fold<double>(0, (sum, t) => sum + t.valueNumeric);
    final calorieOut = petLogs.where((t) => t.actionType == 'SPORT').fold<double>(0, (sum, t) => sum + t.valueNumeric);
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
