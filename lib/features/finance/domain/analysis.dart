/// 财务分析派生计算（纯 Dart，无 Flutter / Drift 依赖，可独立单测）。
///
/// P-FA：财务分析页（分类占比饼图 / 近 30 天真实日成本趋势 / 三层成本 / 预算
/// 完成度）所需的聚合逻辑。与 [amortization.dart] 同口径——长期摊销按覆盖区间
/// 平摊到每一天，曲线平滑、无「一次性全额尖峰」。
///
/// 这里只接受 domain 边界 DTO（[ExpenseEntry] / [CategoryInfo]），由 data/presentation
/// 层从 Drift 行适配而来（见 finance_providers.dart 的 `_toExpenseEntries`），
/// 故本文件不依赖 Drift，可表驱动单测。
library;

import 'amortization.dart';

/// 一条用于聚合的支出记录（domain 边界，不依赖 Drift）。
///
/// 由 presentation 层从 `FinancialTransactionData` 适配而来，仅保留聚合所需字段。
/// [flowType] / [expenseNature] 用于过滤「日常 SPOT 支出」（与
/// `monthSpotExpenseProvider` 同口径：`flowType == 'EXPENSE' && expenseNature == 'SPOT'`）。
class ExpenseEntry {
  const ExpenseEntry({
    required this.categoryId,
    required this.amount,
    required this.flowType,
    required this.expenseNature,
    required this.loggedAt,
  });

  final String categoryId;
  final double amount;

  /// 'INCOME' | 'EXPENSE' | 'TRANSFER'（与 DB `flow_type` 一致）。
  final String flowType;

  /// 'SPOT' | 'AMORTIZED'（与 DB `expense_nature` 一致）。
  final String expenseNature;
  final DateTime loggedAt;
}

/// 分类元信息（domain 边界，不依赖 Drift）。
class CategoryInfo {
  const CategoryInfo({required this.categoryId, required this.name, required this.icon});

  final String categoryId;
  final String name;

  /// emoji 文本（与 DB `category_icon` 一致，如「🍚」）。
  final String icon;
}

/// 分类占比饼图的一个切片。
///
/// 各切片 [amount] 之和 == 入参 SPOT 支出全额（与 `monthSpotExpenseProvider`
/// 自洽，验收 P-FA）。[pct] ∈ [0, 1]，总切片 pct 之和 == 1（空数据时无切片）。
class CategoryBreakdownSlice {
  const CategoryBreakdownSlice({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.amount,
    required this.pct,
  });

  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final double amount;

  /// 占日常 SPOT 总额的比例（0..1）。总额为 0 时本切片不会产出。
  final double pct;
}

/// 一天的真实日成本拆解（趋势折线用）。
///
/// [total] == [spot] + [amortized]（三层自洽：日常 + 摊销 = 真实，验收 P-FA）。
/// [amortized] 由 [dailyAmortizedCost] 平摊而得，无全额尖峰。
class DailyCostPoint {
  const DailyCostPoint({required this.date, required this.spot, required this.amortized});

  /// 当天零点（仅日期分量参与计算）。
  final DateTime date;
  final double spot;
  final double amortized;

  double get total => spot + amortized;
}

/// 「日常 SPOT 支出」判定：与 `monthSpotExpenseProvider` 同口径。
bool _isSpotExpense(ExpenseEntry t) => t.flowType == 'EXPENSE' && t.expenseNature == 'SPOT';

/// 按 [categoryId] 聚合「日常 SPOT 支出」，输出降序切片。
///
/// 仅统计 [ExpenseEntry] 中 `flowType == 'EXPENSE' && expenseNature == 'SPOT'`
/// 的记录（与 `monthSpotExpenseProvider` 同口径，保证「各分类金额和 == 月度日常」
/// 自洽，验收 P-FA）。[categories] 提供 categoryId → 名/图标；缺失分类回退
/// 「未分类 / 💸」。空数据（无 SPOT 支出）返回空列表。
List<CategoryBreakdownSlice> categoryBreakdown({
  required Iterable<ExpenseEntry> txs,
  required Map<String, CategoryInfo> categories,
}) {
  final byCat = <String, double>{};
  for (final t in txs) {
    if (!_isSpotExpense(t)) continue;
    byCat.update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
  }
  final total = byCat.values.fold<double>(0, (s, v) => s + v);
  if (total <= 0) return const <CategoryBreakdownSlice>[];
  final slices = byCat.entries.map((e) {
    final c = categories[e.key];
    return CategoryBreakdownSlice(
      categoryId: e.key,
      categoryName: c?.name ?? '未分类',
      categoryIcon: c?.icon ?? '💸',
      amount: e.value,
      pct: e.value / total,
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return slices;
}

/// [a] 与 [b] 是否同一天（仅比日期分量，忽略时分秒）。
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 过去 [days] 天（含 [today]）每天的真实日成本序列（旧 → 新，供折线图左→右）。
///
/// 每日 = 当日 SPOT 支出全额 + [dailyAmortizedCost] 平摊份额。复用
/// [dailyAmortizedCost] 作为摊销单一真相，跨月 AMORTIZED 同样贡献到窗口内
/// 覆盖日，曲线平滑、无全额尖峰（验收 P-FA）。
///
/// [today] 取「本地日零点」（由调用方截断），其时分秒被忽略。日期用分量构造
/// `DateTime(year, month, day - i)` 跨月/跨年自动归一化。
List<DailyCostPoint> dailyTrueCostSeries({
  required Iterable<ExpenseEntry> txs,
  required Iterable<AmortizedTx> amortized,
  required DateTime today,
  int days = 30,
}) {
  final result = <DailyCostPoint>[];
  for (var i = days - 1; i >= 0; i--) {
    final day = DateTime(today.year, today.month, today.day - i);
    final spot = txs.where((t) => _isSpotExpense(t) && _sameDay(t.loggedAt, day)).fold<double>(0, (s, t) => s + t.amount);
    final amort = dailyAmortizedCost(amortized, day);
    result.add(DailyCostPoint(date: day, spot: spot, amortized: amort));
  }
  return result;
}

/// 预算完成度 = 真实成本 / 预算。
///
/// 预算 <= 0 视为「未设预算」，返回 0（UI 据此引导去设置）。可 > 1（超支）。
/// 与 `monthTrueExpenseProvider` / `monthBudgetProvider` 配合（验收 P-FA）。
double budgetCompletion(double trueExpense, double budget) {
  if (budget <= 0) return 0;
  return trueExpense / budget;
}
