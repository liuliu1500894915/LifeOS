import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/database_provider.dart';
import 'package:life_os/features/finance/presentation/providers/finance_providers.dart';

/// P1-5 回归测:验证日/月支出派生 Provider 已拆成「日常 SPOT / 长期摊销 /
/// 真实成本」三层 ——
///   - 三层自洽:日常 + 摊销 == 真实(今日 / 本月 各一组);
///   - headline(todayExpenseProvider / monthExpenseProvider)不含 AMORTIZED
///     全额尖峰,等于真实成本;
///   - monthDailyExpenseProvider 把摊销平摊到区间内每日,无单日全额尖峰;
///   - 摊销源取全量交易(跨月覆盖):上月 post 的 AMORTIZED 仍贡献到本月。
///
/// AMORTIZED 交易经 DB companion 直插 —— addTransaction 尚未支持摊销参数
/// (那是 P1-2 记账 UI 的范围),本测聚焦 P1-5 的读取/派生口径,写库走最短
/// 路径。读取仍走真实 Repository `.watch()` 流(transactionProvider)。
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

  /// 轮询泵送事件队列,直到 [test] 为真(或耗尽轮次)—— 让 Drift 流在
  /// 直插 commit 后的异步重发有机会执行,避免写死 sleep。
  Future<void> pumpUntil(bool Function() test, {int rounds = 300}) async {
    for (var i = 0; i < rounds; i++) {
      if (test()) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// 触发首启种子(账户/分类),取一个真实 accountId / categoryId / userId
  /// 供直插交易满足外键(P0-5:交易表 categoryId/accountId 有 FK)。
  Future<({String accountId, String categoryId, String userId})> seedRefs() async {
    await container.read(accountProvider.future);
    await container.read(categoryProvider.future);
    final acc = container.read(accountProvider).requireValue.first;
    final cat = container.read(categoryProvider).requireValue.first;
    return (accountId: acc.accountId, categoryId: cat.categoryId, userId: acc.userId);
  }

  /// 直插一笔 EXPENSE(绕过 Repository.addTransaction —— 它尚不支持摊销参数)。
  Future<void> insertTx({
    required String id,
    required ({String accountId, String categoryId, String userId}) refs,
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
            amortizeStartDate: amortizeStart != null ? Value(amortizeStart) : const Value.absent(),
            amortizeEndDate: amortizeEnd != null ? Value(amortizeEnd) : const Value.absent(),
          ),
        );
  }

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  test('今日三层自洽 + headline 不含 AMORTIZED 全额尖峰', () async {
    final refs = await seedRefs();
    final t = today();

    // 日常 SPOT 100(今日发生)。
    await insertTx(id: 'spot', refs: refs, amount: 100, loggedAt: t);
    // 长期摊销 300,覆盖 [昨日, 明日] = 3 天 → 今日摊销份额 100。
    await insertTx(
      id: 'amort',
      refs: refs,
      amount: 300,
      loggedAt: t,
      expenseNature: 'AMORTIZED',
      amortizeStart: t.subtract(const Duration(days: 1)),
      amortizeEnd: t.add(const Duration(days: 1)),
    );

    await pumpUntil(() => container.read(transactionProvider).valueOrNull?.length == 2);

    expect(container.read(todaySpotExpenseProvider), closeTo(100, 1e-9));
    expect(container.read(todayAmortizedExpenseProvider), closeTo(100, 1e-9));
    // 三层自洽:日常 + 摊销 = 真实日成本。
    expect(container.read(todayTrueExpenseProvider), closeTo(200, 1e-9));
    // headline = 真实成本 200;若仍按全额则会是 100 + 300 = 400(尖峰),已消除。
    expect(container.read(todayExpenseProvider), closeTo(200, 1e-9));
  });

  test('本月三层自洽(摊销区间全在本月)', () async {
    final refs = await seedRefs();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final t = today();

    // 日常 SPOT 150(本月发生)。
    await insertTx(id: 'spot', refs: refs, amount: 150, loggedAt: t);
    // 长期摊销 600,覆盖本月前 6 天 [1, 6],全在本月 → 本月摊销合计 600。
    await insertTx(
      id: 'amort',
      refs: refs,
      amount: 600,
      loggedAt: monthStart,
      expenseNature: 'AMORTIZED',
      amortizeStart: monthStart,
      amortizeEnd: DateTime(now.year, now.month, 6),
    );

    await pumpUntil(() => container.read(transactionProvider).valueOrNull?.length == 2);

    expect(container.read(monthSpotExpenseProvider), closeTo(150, 1e-9));
    expect(container.read(monthAmortizedExpenseProvider), closeTo(600, 1e-9));
    // 三层自洽:日常 + 摊销 = 真实月成本。
    expect(container.read(monthTrueExpenseProvider), closeTo(750, 1e-9));
    expect(container.read(monthExpenseProvider), closeTo(750, 1e-9));
  });

  test('monthDailyExpenseProvider:摊销平摊到区间内每日,无单日全额尖峰', () async {
    final refs = await seedRefs();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    // 长期摊销 300 覆盖本月前 3 天 [1, 3] → 每天各平摊 100。
    await insertTx(
      id: 'amort',
      refs: refs,
      amount: 300,
      loggedAt: monthStart,
      expenseNature: 'AMORTIZED',
      amortizeStart: monthStart,
      amortizeEnd: DateTime(now.year, now.month, 3),
    );

    await pumpUntil(() => container.read(transactionProvider).valueOrNull?.length == 1);

    final daily = container.read(monthDailyExpenseProvider);
    // 1/2/3 号各得 100 平摊,而非 300 堆在 post 当天(1 号)。
    expect(daily[1], closeTo(100, 1e-9));
    expect(daily[2], closeTo(100, 1e-9));
    expect(daily[3], closeTo(100, 1e-9));
    // 没有任何一天出现全额 300 尖峰。
    expect(daily.values.every((v) => v < 300), isTrue);
  });

  test('跨月摊销:上月 post 的交易仍贡献到本月(摊销源取全量非当月新单)', () async {
    final refs = await seedRefs();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    // 上月 post 的交易,覆盖区间落在本月 [1, 3]。
    await insertTx(
      id: 'amort-prev',
      refs: refs,
      amount: 300,
      loggedAt: monthStart.subtract(const Duration(days: 5)), // post 在上月
      expenseNature: 'AMORTIZED',
      amortizeStart: monthStart,
      amortizeEnd: DateTime(now.year, now.month, 3),
    );

    await pumpUntil(() => container.read(transactionProvider).valueOrNull?.length == 1);

    // 本月摊销仍计入 300(前 3 天 × 100)—— 证明摊销源取全量交易,而非仅
    // 当月 loggedAt 的新单(否则这笔上月 post 的会被漏掉)。
    expect(container.read(monthAmortizedExpenseProvider), closeTo(300, 1e-9));
  });
}
