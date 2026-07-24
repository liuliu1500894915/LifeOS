import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/database_provider.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/features/daily/presentation/providers/daily_providers.dart';
import 'package:life_os/features/daily/presentation/providers/review_providers.dart';
import 'package:life_os/features/finance/presentation/providers/finance_providers.dart';
import 'package:life_os/features/health/presentation/providers/exercise_providers.dart';
import 'package:life_os/features/health/presentation/providers/meal_providers.dart';

/// P5-3 复盘聚合一致性测。
///
/// 验收 P5-3「快照字段齐全且与各模块当日值一致」：[todayReviewSnapshotProvider]
/// 组装的 [DailyReviewSnapshot] 各字段，必须等于各模块当日 provider 的值 ——
///   - 财务三层（P1-5 口径）：spotExpense == todaySpotExpenseProvider、
///     amortizedExpense == todayAmortizedExpenseProvider、trueExpense == 日常+摊销
///     == todayExpenseProvider；
///   - 健康：intakeCalories == todayNutritionProvider.calories、
///     burnedCalories == todayCaloriesBurnedProvider、netCalories == 摄入−消耗；
///   - 待办：当日总数 / 已完成 / 完成率 == quadrantTodoProvider 当日子集。
///
/// 写库走最短路径（DB companion 直插），读取仍走真实 Repository `.watch()` 流
/// （finance/health 派生 provider），与 finance_cost_layers_test 同范式。待办源
/// 是内存 mock（daily 模块尚未落库），故 override quadrantTodoProvider 给定值。
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SystemBootstrap(db).ensureSystemUser();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 轮询泵送事件队列，直到 [test] 为真（或耗尽轮次）—— 让 Drift 流在直插
  /// commit 后的异步重发有机会执行，避免写死 sleep。
  Future<void> pumpUntil(bool Function() test, {int rounds = 300}) async {
    for (var i = 0; i < rounds; i++) {
      if (test()) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// 触发首启种子（账户/分类），取一个真实 accountId / categoryId / userId
  /// 供直插交易满足外键（P0-5：交易表 categoryId/accountId 有 FK）。
  Future<({String accountId, String categoryId, String userId})> seedFinanceRefs(
      ProviderContainer c) async {
    await c.read(accountProvider.future);
    await c.read(categoryProvider.future);
    final acc = c.read(accountProvider).requireValue.first;
    final cat = c.read(categoryProvider).requireValue.first;
    return (accountId: acc.accountId, categoryId: cat.categoryId, userId: acc.userId);
  }

  /// 直插一笔 EXPENSE（绕过 Repository.addTransaction —— 它尚不支持摊销参数，
  /// 与 finance_cost_layers_test 同处理）。
  Future<void> insertTx({
    required ({String accountId, String categoryId, String userId}) refs,
    required String id,
    required double amount,
    required DateTime loggedAt,
    String expenseNature = 'SPOT',
    DateTime? amortizeStart,
    DateTime? amortizeEnd,
  }) async {
    await db.into(db.financialTransaction).insert(
          FinancialTransactionCompanion.insert(
            transactionId: id,
            userId: refs.userId,
            flowType: 'EXPENSE',
            amount: amount,
            categoryId: refs.categoryId,
            accountId: refs.accountId,
            loggedAt: loggedAt,
            expenseNature: Value(expenseNature),
            amortizeStartDate:
                amortizeStart != null ? Value(amortizeStart) : const Value.absent(),
            amortizeEndDate:
                amortizeEnd != null ? Value(amortizeEnd) : const Value.absent(),
          ),
        );
  }

  /// 插一条食物（满足 MealLog.foodId 外键），返回 foodId。
  Future<String> seedFood() async {
    await db.into(db.foodCategory).insert(
          FoodCategoryCompanion.insert(
            categoryId: 'cat-staple',
            userId: systemUserId,
            categoryName: '主食',
            categoryIcon: '🍚',
          ),
        );
    await db.into(db.foodLibrary).insert(
          FoodLibraryCompanion.insert(
            foodId: 'food-rice',
            userId: systemUserId,
            foodName: '米饭',
            categoryId: 'cat-staple',
            caloriesPer100g: 116,
          ),
        );
    return 'food-rice';
  }

  test('各模块当日值一致：财务三层 / 健康 / 待办完成率', () async {
    final t = today();
    // 待办：4 条今日（2 完成）+ 1 条明日（不计入当日）。
    final todos = <TodoItem>[
      TodoItem(todoId: 'td1', title: 'A', quadrant: QuadrantType.A, targetDate: t),
      TodoItem(
          todoId: 'td2',
          title: 'B',
          quadrant: QuadrantType.B,
          targetDate: t,
          isCompleted: true),
      TodoItem(todoId: 'td3', title: 'C', quadrant: QuadrantType.C, targetDate: t),
      TodoItem(
          todoId: 'td4',
          title: 'D',
          quadrant: QuadrantType.A,
          targetDate: t,
          isCompleted: true),
      TodoItem(
          todoId: 'td5',
          title: '明日',
          quadrant: QuadrantType.D,
          targetDate: t.add(const Duration(days: 1))),
    ];
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      quadrantTodoProvider.overrideWith((ref) => todos),
    ]);

    // 财务：日常 SPOT 100（今日发生）+ 摊销 300 覆盖 [昨日, 明日]=3 天 → 今日摊销 100。
    final refs = await seedFinanceRefs(container);
    await insertTx(refs: refs, id: 'spot', amount: 100, loggedAt: t);
    await insertTx(
      refs: refs,
      id: 'amort',
      amount: 300,
      loggedAt: t,
      expenseNature: 'AMORTIZED',
      amortizeStart: t.subtract(const Duration(days: 1)),
      amortizeEnd: t.add(const Duration(days: 1)),
    );

    // 健康：摄入 MealLog.snapCalories=500；消耗 ExerciseLog.caloriesBurned=300。
    await seedFood();
    await db.into(db.mealLog).insert(
          MealLogCompanion.insert(
            logId: 'ml1',
            userId: systemUserId,
            foodId: 'food-rice',
            mealType: 'LUNCH',
            grams: 150,
            snapCalories: 500,
            snapProtein: 0,
            snapFat: 0,
            snapCarbs: 0,
            loggedAt: t,
          ),
        );
    await db.into(db.exerciseLog).insert(
          ExerciseLogCompanion.insert(
            logId: 'ex1',
            userId: systemUserId,
            exerciseName: '跑步',
            durationMinutes: 30,
            caloriesBurned: 300,
            loggedAt: t,
          ),
        );

    // 等三路流都重发到含已插数据。
    await pumpUntil(
        () => container.read(transactionProvider).valueOrNull?.length == 2);
    await pumpUntil(
        () => container.read(mealLogProvider).valueOrNull?.length == 1);
    await pumpUntil(
        () => container.read(exerciseLogProvider).valueOrNull?.length == 1);

    final snapshot = container.read(todayReviewSnapshotProvider);

    // ── 财务三层（P1-5 口径）──
    expect(container.read(todaySpotExpenseProvider), closeTo(100, 1e-9));
    expect(snapshot.spotExpense, closeTo(100, 1e-9));
    expect(container.read(todayAmortizedExpenseProvider), closeTo(100, 1e-9));
    expect(snapshot.amortizedExpense, closeTo(100, 1e-9));
    // 三层自洽：日常 + 摊销 = 真实日成本，且与 headline（todayExpenseProvider）一致。
    expect(snapshot.trueExpense, closeTo(200, 1e-9));
    expect(container.read(todayExpenseProvider), closeTo(200, 1e-9));
    expect(snapshot.trueExpense, closeTo(container.read(todayExpenseProvider), 1e-9));

    // ── 健康：摄入 / 消耗 / 净值 ──
    expect(container.read(todayNutritionProvider).calories, closeTo(500, 1e-9));
    expect(snapshot.intakeCalories, closeTo(500, 1e-9));
    expect(container.read(todayCaloriesBurnedProvider), closeTo(300, 1e-9));
    expect(snapshot.burnedCalories, closeTo(300, 1e-9));
    expect(snapshot.netCalories, closeTo(200, 1e-9)); // 摄入 − 消耗

    // ── 待办：当日 4 条（2 完成），完成率 0.5；明日那条不计入 ──
    expect(snapshot.todoTotal, 4);
    expect(snapshot.todoCompleted, 2);
    expect(snapshot.todoCompletionRate, 0.5);
  });

  test('空数据日：各字段为零/默认，完成率不除零', () async {
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      quadrantTodoProvider.overrideWith((ref) => const <TodoItem>[]),
    ]);
    // 触发 finance refs 种子（账户/分类），但不插任何交易。
    await seedFinanceRefs(container);
    await pumpUntil(
        () => container.read(transactionProvider).hasValue);
    await pumpUntil(() => container.read(mealLogProvider).hasValue);
    await pumpUntil(() => container.read(exerciseLogProvider).hasValue);

    final snapshot = container.read(todayReviewSnapshotProvider);
    expect(snapshot.spotExpense, 0);
    expect(snapshot.amortizedExpense, 0);
    expect(snapshot.trueExpense, 0);
    expect(snapshot.intakeCalories, 0);
    expect(snapshot.burnedCalories, 0);
    expect(snapshot.netCalories, 0);
    expect(snapshot.todoTotal, 0);
    expect(snapshot.todoCompleted, 0);
    expect(snapshot.todoCompletionRate, 0); // todoTotal=0 不除零
  });
}
