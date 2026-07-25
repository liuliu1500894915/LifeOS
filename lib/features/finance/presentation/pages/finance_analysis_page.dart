import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/analysis.dart';
import '../providers/finance_providers.dart';

/// P-FA 财务分析页：分类占比饼图 / 近 30 天真实日成本趋势 / 三层成本卡 /
/// 预算完成度。全部数据走现有流式派生 provider,本页无 db./Companion/裸查询
/// (架构铁律 1)。计算逻辑在 domain/analysis.dart 纯函数。
class FinanceAnalysisPage extends ConsumerWidget {
  const FinanceAnalysisPage({super.key});

  /// 饼图配色（无 DB 颜色列,按切片索引循环此调色板）。
  static const List<Color> _palette = [
    ModuleColors.finance, // green
    ModuleColors.analytics, // purple
    ModuleColors.daily, // blue
    ModuleColors.home, // orange
    ModuleColors.warning, // amber
    ModuleColors.quadrantD, // lightGreen
    ModuleColors.expense, // red
    ModuleColors.profile, // slate
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = ref.watch(monthCategoryBreakdownProvider);
    final dailyCost = ref.watch(last30DaysDailyCostProvider);
    final spot = ref.watch(monthSpotExpenseProvider);
    final amortized = ref.watch(monthAmortizedExpenseProvider);
    final trueExpense = ref.watch(monthTrueExpenseProvider);
    final budget = ref.watch(monthBudgetProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('财务分析'), backgroundColor: const Color(0xFFF8F9FA)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThreeLayerCard(spot, amortized, trueExpense),
            _buildBudgetCard(context, ref, trueExpense, budget),
            _buildCategoryPieCard(breakdown),
            _buildTrendCard(dailyCost),
          ],
        ),
      ),
    );
  }

  // ── ① 三层成本卡：日常 SPOT / 长期摊销 / 真实成本(= 日常 + 摊销) ──

  Widget _buildThreeLayerCard(double spot, double amortized, double trueExpense) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本月真实成本拆解', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _layerCell('日常', spot, ModuleColors.finance)),
              Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
              Expanded(child: _layerCell('摊销', amortized, ModuleColors.warning)),
              Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
              Expanded(child: _layerCell('真实成本', trueExpense, ModuleColors.expense, emphasize: true)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('日常 = 当月一次性支出 · 摊销 = 长期支出按区间平摊 · 真实成本 = 日常 + 摊销',
              style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _layerCell(String label, double amount, Color color, {bool emphasize = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 4),
        Text('¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: emphasize ? 17 : 15,
              fontWeight: FontWeight.w700,
              color: color,
            )),
      ],
    );
  }

  // ── ④ 预算完成度：真实成本 / 预算 ──

  Widget _buildBudgetCard(BuildContext context, WidgetRef ref, double trueExpense, double budget) {
    final hasBudget = budget > 0;
    final completion = budgetCompletion(trueExpense, budget); // 0 when no budget
    final remaining = budget - trueExpense;
    final over = remaining < 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: hasBudget
          ? Row(
              children: [
                _buildBudgetRing(completion, over),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('预算完成度', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
                      const SizedBox(height: 4),
                      Text('${(completion * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: over ? ModuleColors.expense : ModuleColors.finance,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        over
                            ? '已超支 ¥${remaining.abs().toStringAsFixed(2)}（真实成本 ¥${trueExpense.toStringAsFixed(2)} / 预算 ¥${budget.toStringAsFixed(0)}）'
                            : '剩余 ¥${remaining.toStringAsFixed(2)}（真实成本 ¥${trueExpense.toStringAsFixed(2)} / 预算 ¥${budget.toStringAsFixed(0)}）',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, size: 20, color: Color(0xFF9E9E9E)),
                  onPressed: () => _showBudgetDialog(context, ref, budget),
                ),
              ],
            )
          : _buildNoBudgetGuide(context, ref),
    );
  }

  /// 环形进度(fl_chart PieChart 双段)：已用 + 剩余,超支时整环红。
  Widget _buildBudgetRing(double completion, bool over) {
    final used = completion.clamp(0.0, 1.0);
    final remainder = (1 - used).clamp(0.0, 1.0);
    final usedColor = over ? ModuleColors.expense : ModuleColors.finance;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 26,
              startDegreeOffset: -90,
              sections: [
                PieChartSectionData(value: used, color: usedColor, radius: 8, showTitle: false),
                if (remainder > 0)
                  PieChartSectionData(value: remainder, color: const Color(0xFFEEEEEE), radius: 8, showTitle: false),
              ],
            ),
          ),
          Text('${(used * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: usedColor)),
        ],
      ),
    );
  }

  Widget _buildNoBudgetGuide(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Icon(Icons.savings_outlined, size: 28, color: ModuleColors.finance),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('尚未设置本月预算', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        TextButton(
          onPressed: () => _showBudgetDialog(context, ref, 0),
          child: const Text('去设置'),
        ),
      ],
    );
  }

  // ── ① 分类占比饼图 + 图例 ──

  Widget _buildCategoryPieCard(List<CategoryBreakdownSlice> slices) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本月日常支出分类', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (slices.isEmpty)
            const _EmptyHint(text: '本月暂无日常支出')
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 130, height: 130, child: _buildPie(slices)),
                const SizedBox(width: 16),
                Expanded(child: _buildLegend(slices)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPie(List<CategoryBreakdownSlice> slices) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 34,
        startDegreeOffset: -90,
        sections: [
          for (var i = 0; i < slices.length; i++)
            PieChartSectionData(
              value: slices[i].amount,
              color: _palette[i % _palette.length],
              radius: 26,
              title: slices[i].pct >= 0.08 ? '${(slices[i].pct * 100).toStringAsFixed(0)}%' : '',
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend(List<CategoryBreakdownSlice> slices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _palette[i % _palette.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(slices[i].categoryIcon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(slices[i].categoryName,
                      style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
                Text('¥${slices[i].amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 42,
                  child: Text('${(slices[i].pct * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── ② 近 30 天真实日成本趋势折线 ──

  Widget _buildTrendCard(List<DailyCostPoint> dailyCost) {
    final spots = [
      for (var i = 0; i < dailyCost.length; i++) FlSpot(i.toDouble(), dailyCost[i].total),
    ];
    final maxYRaw = spots.fold<double>(0, (a, s) => s.y > a ? s.y : a);
    final maxY = maxYRaw > 0 ? maxYRaw * 1.2 : 100.0;
    final lastIdx = spots.length - 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8, left: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('近 30 天真实日成本', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                      ),
                    ),
                  ),
                  // 按周稀疏标注 + 末尾（今天）必标。
                  //
                  // interval 用 1 逐点回调、由下面的逻辑决定实际标哪几天：若直接用
                  // interval: 7，末尾的周标记（第 28 天）会和轴末端的今天（第 29 天）
                  // 挨在一起，两个日期糊成一团（如「7/2425」）。
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= dailyCost.length) {
                          return const SizedBox.shrink();
                        }
                        final last = dailyCost.length - 1;
                        final isLast = i == last;
                        // 末尾 4 天内的周标记让位给「今天」，避免标签重叠。
                        if (!isLast && (i % 7 != 0 || last - i < 4)) {
                          return const SizedBox.shrink();
                        }
                        final d = dailyCost[i].date;
                        return SideTitleWidget(
                          meta: meta,
                          child: Text('${d.month}/${d.day}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: ModuleColors.finance,
                    barWidth: 2,
                    belowBarData: BarAreaData(show: true, color: ModuleColors.finance.withAlpha(30)),
                    // 末点强调：仅最后一点画白描边圆点。
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: index == lastIdx ? 5 : 0,
                        color: ModuleColors.finance,
                        strokeColor: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 4),
            child: Text('含已平摊的长期摊销（订阅/保险等），无一次性全额尖峰',
                style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
          ),
        ],
      ),
    );
  }

  // ── 设置预算弹窗（复用 monthly_spending_page 口径）──

  void _showBudgetDialog(BuildContext context, WidgetRef ref, double currentBudget) {
    final ctl = TextEditingController(text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置月预算'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '如：5000', suffixText: '元/月'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(ctl.text);
              if (amount != null && amount > 0) {
                final now = DateTime.now();
                final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                ref.read(budgetProvider.notifier).setBudget(monthKey, amount);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text, style: const TextStyle(color: Color(0xFF9E9E9E)))),
    );
  }
}
