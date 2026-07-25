import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/database_provider.dart';
import 'package:life_os/features/finance/domain/analysis.dart';
import 'package:life_os/features/finance/presentation/providers/finance_providers.dart';

/// P-FA DB 集成测：验证三个派生 provider 与现有流式 provider 自洽 ——
///   - monthCategoryBreakdownProvider:分类聚合来自 DB(非硬编码),金额/名/图标
///     join 自如,各分类和 == monthSpotExpenseProvider(同口径),排除 AMORTIZED;
///   - last30DaysDailyCostProvider:30 点真实日成本,SPOT 计入当日 + 摊销平摊无尖峰;
///   - 预算完成度:真实成本 / 预算,未设预算 → 0(UI 引导)。
///
/// 写库走 companion 直插(最短路径),读取仍走真实 Repository `.watch()` 流。
/// 时间锚定真实「今天」(与 finance_cost_layers_test 同口径),使本月/30 天窗口
/// 过滤命中插入数据。
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpUntil(bool Function() test, {int rounds = 300}) async {
    for (var i = 0; i < rounds; i++) {
      if (test()) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// 触发首启种子,取真实 accountId / userId 供直插交易满足外键。
  Future<({String accountId, String userId})> seedRefs() async {
    await container.read(accountProvider.future);
    await container.read(categoryProvider.future);
    final acc = container.read(accountProvider).requireValue.first;
    return (accountId: acc.accountId, userId: acc.userId);
  }

  Future<void> insertTx({
    required String id,
    required ({String accountId, String userId}) refs,
    required String categoryId,
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
            categoryId: categoryId,
            accountId: refs.accountId,
            loggedAt: loggedAt,
            expenseNature: Value(expenseNature),
            amortizeStartDate: amortizeStart != null ? Value(amortizeStart) : const Value.absent(),
            amortizeEndDate: amortizeEnd != null ? Value(amortizeEnd) : const Value.absent(),
          ),
        );
  }

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  test('monthCategoryBreakdownProvider：分类来自 DB 聚合，金额自洽，排除 AMORTIZED', () async {
    final refs = await seedRefs();
    final t = today();

    // 三餐(food)两笔共 150,交通(transport)一笔 30 —— 名/图标来自 seed join。
    await insertTx(id: 'f1', refs: refs, categoryId: 'food', amount: 100, loggedAt: t);
    await insertTx(id: 'f2', refs: refs, categoryId: 'food', amount: 50, loggedAt: t);
    await insertTx(id: 'tr', refs: refs, categoryId: 'transport', amount: 30, loggedAt: t);
    // 长期摊销 999(subscription)—— 不应进分类占比。
    await insertTx(
      id: 'sub',
      refs: refs,
      categoryId: 'subscription',
      amount: 999,
      loggedAt: t,
      expenseNature: 'AMORTIZED',
      amortizeStart: t,
      amortizeEnd: t.add(const Duration(days: 30)),
    );

    await pumpUntil(() => container.read(transactionProvider).valueOrNull?.length == 4);

    final slices = container.read(monthCategoryBreakdownProvider);
    expect(slices.length, 2);
    // 降序:三餐 150 > 交通 30。
    expect(slices.first.categoryId, 'food');
    expect(slices.first.categoryName, '三餐'); // 来自 DB,非硬编码
    expect(slices.first.categoryIcon, '🍱');
    expect(slices.first.amount, 150);
    expect(slices.last.categoryId, 'transport');
    expect(slices.last.categoryName, '交通');
    expect(slices.last.categoryIcon, '🚗');
    // 各分类和 == monthSpotExpenseProvider(同口径 EXPENSE+SPOT,验收 P-FA 自洽)。
    final sum = slices.fold<double>(0, (s, c) => s + c.amount);
    expect(sum, closeTo(container.read(monthSpotExpenseProvider), 1e-9));
    expect(sum, closeTo(180, 1e-9)); // 仅 SPOT:100+50+30;999 摊销不计
    // pct 和 = 1。
    expect(slices.fold<double>(0, (s, c) => s + c.pct), closeTo(1, 1e-9));
    // AMORTIZED 的分类(subscription)不出现在占比里。
    expect(slices.any((c) => c.categoryId == 'subscription'), isFalse);
  });

  test('monthCategoryBreakdownProvider：无 SPOT 支出时返回空列表', () async {
    await seedRefs();
    await pumpUntil(() => container.read(categoryProvider).hasValue);
    expect(container.read(monthCategoryBreakdownProvider), isEmpty);
  });

  test('last30DaysDailyCostProvider：30 点真实日成本，SPOT 入当日，摊销平摊无尖峰', () async {
    final refs = await seedRefs();
    final t = today();

    // 今日 SPOT 60。
    await insertTx(id: 'spot', refs: refs, categoryId: 'food', amount: 60, loggedAt: t);
    // 长期摊销 300 覆盖 [今日-2, 今日] = 3 天 → 每天 100。
    await insertTx(
      id: 'amort',
      refs: refs,
      categoryId: 'subscription',
      amount: 300,
      loggedAt: t,
      expenseNature: 'AMORTIZED',
      amortizeStart: t.subtract(const Duration(days: 2)),
      amortizeEnd: t,
    );

    await pumpUntil(() => container.read(transactionProvider).valueOrNull?.length == 2);

    final points = container.read(last30DaysDailyCostProvider);
    expect(points.length, 30);
    expect(points.last.date, t); // 末点 == 今天
    // 今日:SPOT 60 + 摊销 100 = 160。
    expect(points.last.spot, closeTo(60, 1e-9));
    expect(points.last.amortized, closeTo(100, 1e-9));
    expect(points.last.total, closeTo(160, 1e-9));
    // 昨日:无 SPOT,摊销 100。
    expect(points[points.length - 2].spot, 0);
    expect(points[points.length - 2].amortized, closeTo(100, 1e-9));
    // 无全额尖峰:没有任何一天 total >= 300。
    expect(points.every((p) => p.total < 300), isTrue);
  });

  test('预算完成度 = 真实成本 / 预算；未设预算 → 0', () async {
    final refs = await seedRefs();
    final t = today();

    // 未设预算:completion = 0(UI 据此引导)。
    await pumpUntil(() => container.read(transactionProvider).hasValue);
    expect(container.read(monthBudgetProvider), 0);
    expect(budgetCompletion(container.read(monthTrueExpenseProvider), container.read(monthBudgetProvider)), 0);

    // 设本月预算 1000。
    await container.read(budgetProvider.notifier).setBudget(monthKey(), 1000);
    await pumpUntil(() => container.read(monthBudgetProvider) == 1000);

    // 本月 SPOT 200,无摊销 → 真实成本 200。
    await insertTx(id: 'sp', refs: refs, categoryId: 'food', amount: 200, loggedAt: t);
    await pumpUntil(() => container.read(transactionProvider).valueOrNull?.length == 1);

    final trueExpense = container.read(monthTrueExpenseProvider);
    final budget = container.read(monthBudgetProvider);
    expect(trueExpense, closeTo(200, 1e-9));
    expect(budget, 1000);
    expect(budgetCompletion(trueExpense, budget), closeTo(0.2, 1e-9));
  });
}
