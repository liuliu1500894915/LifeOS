import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/features/finance/domain/amortization.dart';
import 'package:life_os/features/finance/domain/analysis.dart';

/// P-FA domain 纯函数表驱动单测：
///   - categoryBreakdown：按 categoryId 聚合 SPOT 支出 / 排除 AMORTIZED·INCOME·
///     TRANSFER / pct 自洽(和=1)/ 降序 / 空数据 / 缺分类回退。
///   - dailyTrueCostSeries：30 点序列 / SPOT 计入当日 / 摊销平摊无全额尖峰 /
///     total = spot + amortized。
///   - budgetCompletion：正常 / 超支 / 未设预算。
void main() {
  // 固定「今天」避免测试依赖系统时钟(与 domain 不用 DateTime.now 一致)。
  final today = DateTime(2026, 7, 25);

  group('categoryBreakdown', () {
    test('按 categoryId 聚合 SPOT 支出，各分类和 = SPOT 总额，pct 和 = 1，降序', () {
      final txs = [
        ExpenseEntry(categoryId: 'food', amount: 100, flowType: 'EXPENSE', expenseNature: 'SPOT', loggedAt: today),
        ExpenseEntry(categoryId: 'food', amount: 50, flowType: 'EXPENSE', expenseNature: 'SPOT', loggedAt: today),
        ExpenseEntry(categoryId: 'transit', amount: 30, flowType: 'EXPENSE', expenseNature: 'SPOT', loggedAt: today),
      ];
      const cats = {
        'food': CategoryInfo(categoryId: 'food', name: '餐饮', icon: '🍚'),
        'transit': CategoryInfo(categoryId: 'transit', name: '交通', icon: '🚌'),
      };

      final slices = categoryBreakdown(txs: txs, categories: cats);

      expect(slices.length, 2);
      // 降序:餐饮 150 > 交通 30。
      expect(slices.first.categoryId, 'food');
      expect(slices.first.amount, 150);
      expect(slices.last.categoryId, 'transit');
      // 各分类和 = SPOT 总额(180)。
      expect(slices.fold<double>(0, (s, c) => s + c.amount), 180);
      // pct 和 = 1,且每片 = amount/total。
      expect(slices.fold<double>(0, (s, c) => s + c.pct), closeTo(1, 1e-9));
      expect(slices.first.pct, closeTo(150 / 180, 1e-9));
      // 名/图标来自 categories。
      expect(slices.first.categoryName, '餐饮');
      expect(slices.first.categoryIcon, '🍚');
    });

    test('排除 AMORTIZED / INCOME / TRANSFER（仅 EXPENSE+SPOT）', () {
      final txs = [
        ExpenseEntry(categoryId: 'food', amount: 100, flowType: 'EXPENSE', expenseNature: 'SPOT', loggedAt: today),
        // 长期摊销不计入分类占比(它会进趋势线的平摊,但不进日常分类)。
        ExpenseEntry(categoryId: 'sub', amount: 999, flowType: 'EXPENSE', expenseNature: 'AMORTIZED', loggedAt: today),
        // 收入不计。
        ExpenseEntry(categoryId: 'salary', amount: 5000, flowType: 'INCOME', expenseNature: 'SPOT', loggedAt: today),
        // 转账不计。
        ExpenseEntry(categoryId: 'food', amount: 200, flowType: 'TRANSFER', expenseNature: 'SPOT', loggedAt: today),
      ];
      const cats = {'food': CategoryInfo(categoryId: 'food', name: '餐饮', icon: '🍚')};

      final slices = categoryBreakdown(txs: txs, categories: cats);

      expect(slices.length, 1);
      expect(slices.single.amount, 100); // 仅 SPOT 支出
    });

    test('空数据(无 SPOT 支出)返回空列表', () {
      final slices = categoryBreakdown(
        txs: const [],
        categories: const {},
      );
      expect(slices, isEmpty);
    });

    test('单分类 → pct = 1.0', () {
      final txs = [
        ExpenseEntry(categoryId: 'food', amount: 88, flowType: 'EXPENSE', expenseNature: 'SPOT', loggedAt: today),
      ];
      const cats = {'food': CategoryInfo(categoryId: 'food', name: '餐饮', icon: '🍚')};
      final slices = categoryBreakdown(txs: txs, categories: cats);
      expect(slices.single.pct, closeTo(1, 1e-9));
    });

    test('缺分类映射 → 回退「未分类 / 💸」', () {
      final txs = [
        ExpenseEntry(categoryId: 'ghost', amount: 10, flowType: 'EXPENSE', expenseNature: 'SPOT', loggedAt: today),
      ];
      final slices = categoryBreakdown(txs: txs, categories: const {});
      expect(slices.single.categoryName, '未分类');
      expect(slices.single.categoryIcon, '💸');
    });
  });

  group('dailyTrueCostSeries', () {
    test('返回 30 个点，旧→新排列，末点 == today', () {
      final points = dailyTrueCostSeries(txs: const [], amortized: const [], today: today);
      expect(points.length, 30);
      // 最旧点 = today - 29,最新点 = today。
      expect(points.first.date, DateTime(2026, 6, 26));
      expect(points.last.date, today);
    });

    test('SPOT 计入当日；total = spot + amortized（三层自洽）', () {
      final day = today.subtract(const Duration(days: 3)); // 窗口内
      final txs = [
        ExpenseEntry(categoryId: 'food', amount: 60, flowType: 'EXPENSE', expenseNature: 'SPOT', loggedAt: day),
      ];
      // 300 元覆盖 [today-5, today-3] = 3 天 → 每天 100 平摊。
      final amort = [
        AmortizedTx(amount: 300, start: DateTime(2026, 7, 20), end: DateTime(2026, 7, 22)),
      ];

      final points = dailyTrueCostSeries(txs: txs, amortized: amort, today: today);

      // today-3(7/22):SPOT 60 + 摊销 100 = 160。
      final p3 = points.firstWhere((p) => p.date == DateTime(2026, 7, 22));
      expect(p3.spot, 60);
      expect(p3.amortized, closeTo(100, 1e-9));
      expect(p3.total, closeTo(160, 1e-9));
      // today-4(7/21):无 SPOT,摊销 100。
      final p4 = points.firstWhere((p) => p.date == DateTime(2026, 7, 21));
      expect(p4.spot, 0);
      expect(p4.amortized, closeTo(100, 1e-9));
    });

    test('摊销平摊无全额尖峰：300 元不会堆在单日', () {
      final amort = [
        AmortizedTx(amount: 300, start: DateTime(2026, 7, 20), end: DateTime(2026, 7, 22)),
      ];
      final points = dailyTrueCostSeries(txs: const [], amortized: amort, today: today);
      // 没有任何一天的 total 出现全额 300 尖峰。
      expect(points.every((p) => p.total < 300), isTrue);
      // 摊销只贡献在覆盖的 3 天(7/20、7/21、7/22),各 100。
      final amortizedDays = points.where((p) => p.amortized > 0).toList();
      expect(amortizedDays.length, 3);
      for (final p in amortizedDays) {
        expect(p.amortized, closeTo(100, 1e-9));
      }
    });
  });

  group('budgetCompletion', () {
    test('正常 < 1', () {
      expect(budgetCompletion(300, 1000), closeTo(0.3, 1e-9));
    });
    test('超支 > 1', () {
      expect(budgetCompletion(1200, 1000), closeTo(1.2, 1e-9));
    });
    test('正好用完 = 1', () {
      expect(budgetCompletion(1000, 1000), closeTo(1, 1e-9));
    });
    test('未设预算(<=0) → 0', () {
      expect(budgetCompletion(500, 0), 0);
      expect(budgetCompletion(500, -1), 0);
    });
  });
}
