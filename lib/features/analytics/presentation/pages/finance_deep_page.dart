import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/analytics_providers.dart';

class FinanceDeepPage extends ConsumerWidget {
  const FinanceDeepPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(financeAnalyticsProvider);
    final categories = summary.categoryExpenses.entries.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('财务深度分析'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow(summary),
            const SizedBox(height: 16),
            _buildExpenseBarChart(categories),
            const SizedBox(height: 16),
            _buildBudgetAlert(summary),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(FinanceAnalyticsSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('收入', summary.income, ModuleColors.income),
          _stat('支出', summary.expense, ModuleColors.expense),
          _stat('结余', summary.balance, ModuleColors.analytics),
        ],
      ),
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 4),
        Text('¥${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildExpenseBarChart(List<MapEntry<String, double>> categories) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分类支出柱状图', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= categories.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(categories[index].key, style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < categories.length; i++)
                    BarChartGroupData(x: i, barRods: [BarChartRodData(toY: categories[i].value, color: ModuleColors.finance, width: 18, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAlert(FinanceAnalyticsSummary summary) {
    final overBudget = summary.expense > 40;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overBudget ? ModuleColors.expense.withAlpha(12) : ModuleColors.success.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        overBudget ? '预算爆舱预警：今日支出偏高，建议暂停冲动消费。' : '预算平稳：今日支出仍处于安全区间。',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: overBudget ? ModuleColors.expense : ModuleColors.success),
      ),
    );
  }
}
