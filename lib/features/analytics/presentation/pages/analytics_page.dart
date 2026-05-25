import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/analytics_providers.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  String _selectedPeriod = '本月';
  static const _periods = ['本周', '本月', '近90天', '自定义'];

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeAnalyticsProvider);
    final daily = ref.watch(dailyAnalyticsProvider);
    final insight = ref.watch(insightCardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildPeriodFilter(),
              const SizedBox(height: 16),
              _buildInsightCard(context, insight),
              const SizedBox(height: 12),
              _buildSectionLabel('财务多维收支简报'),
              const SizedBox(height: 8),
              _buildFinanceSummary(context, finance),
              const SizedBox(height: 12),
              _buildSectionLabel('日常习惯与执行力统计'),
              const SizedBox(height: 8),
              _buildDailySummary(context, daily),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push(AppRoutes.report),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: const [
                      Icon(Icons.description_outlined, color: ModuleColors.analytics),
                      SizedBox(width: 8),
                      Expanded(child: Text('查看周/月综合报告', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ModuleColors.success.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 12, color: ModuleColors.success),
              SizedBox(width: 4),
              Text('数据全量加密', style: TextStyle(fontSize: 11, color: ModuleColors.success)),
            ],
          ),
        ),
        const Spacer(),
        const Text('数据中枢', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          onPressed: () => context.push(AppRoutes.calendar),
          icon: const Icon(Icons.calendar_today, size: 20),
        ),
      ],
    );
  }

  Widget _buildPeriodFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map((period) {
          final selected = period == _selectedPeriod;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? ModuleColors.analytics : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: selected ? null : Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF616161),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, dynamic insight) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.insights),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ModuleColors.analytics.withAlpha(20), ModuleColors.analytics.withAlpha(60)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ModuleColors.analytics.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🎯', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(insight.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${insight.summary}（r=${insight.coefficient.toStringAsFixed(2)}）',
              style: const TextStyle(fontSize: 13, color: Color(0xFF616161), height: 1.5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('查看关联矩阵', style: TextStyle(fontSize: 13, color: ModuleColors.analytics, fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: ModuleColors.analytics),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceSummary(BuildContext context, FinanceAnalyticsSummary finance) {
    final topCategories = finance.categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GestureDetector(
      onTap: () => context.push(AppRoutes.financeDeep),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('总收入', '¥${finance.income.toStringAsFixed(0)}', ModuleColors.income),
                _buildStat('总支出', '¥${finance.expense.toStringAsFixed(0)}', ModuleColors.expense),
                _buildStat('结余', '¥${finance.balance.toStringAsFixed(0)}', ModuleColors.analytics),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: topCategories.take(3).map((entry) => Text('${entry.key} ¥${entry.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Color(0xFF616161)))).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildDailySummary(BuildContext context, DailyAnalyticsSummary daily) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.dailyDeep),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(child: _buildProgressItem('Todo 清空率', '${(daily.completionRate * 100).toStringAsFixed(1)}%', daily.completionRate, ModuleColors.daily)),
            const SizedBox(width: 12),
            Expanded(child: _buildProgressItem('饮水达标', '${daily.waterMl.toInt()}ml', (daily.waterMl / 2000).clamp(0.0, 1.0), const Color(0xFF42A5F5))),
            const SizedBox(width: 12),
            Expanded(child: _buildProgressItem('睡眠', '${daily.sleepHours.toStringAsFixed(1)}h', (daily.sleepHours / 10).clamp(0.0, 1.0), const Color(0xFF7E57C2))),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, String value, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF616161)));
  }
}
