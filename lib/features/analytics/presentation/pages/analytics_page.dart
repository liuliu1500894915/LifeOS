import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedPeriod = '本月';
  static const _periods = ['本周', '本月', '近90天', '自定义'];

  @override
  Widget build(BuildContext context) {
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
              _buildInsightCard(),
              const SizedBox(height: 12),
              _buildSectionLabel('财务多维收支简报'),
              const SizedBox(height: 8),
              _buildFinanceSummary(context),
              const SizedBox(height: 12),
              _buildSectionLabel('日常习惯与执行力统计'),
              const SizedBox(height: 8),
              _buildDailySummary(context),
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

  Widget _buildInsightCard() {
    return GestureDetector(
      onTap: () {},
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
            const Row(
              children: [
                Text('🎯', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '冲动消费与睡眠关联',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '系统注意到，当你深夜睡眠少于 5.5 小时后的第二天，'
              '你的冲动购物消费（如咖啡、外卖）平均会上升 42%。',
              style: TextStyle(fontSize: 13, color: Color(0xFF616161), height: 1.5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '查看关联数据流水',
                  style: TextStyle(fontSize: 13, color: ModuleColors.analytics, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: ModuleColors.analytics),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceSummary(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.financeDeep),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('总收入', '¥15,000', ModuleColors.income),
                _buildStat('总支出', '¥4,520', ModuleColors.expense),
                _buildStat('结余', '¥10,480', ModuleColors.analytics),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Text('消费大头: ', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
                Text('🍱 餐饮 (40%)', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
                SizedBox(width: 8),
                Text('🛒 购物 (25%)', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
                SizedBox(width: 8),
                Text('🚗 交通 (15%)', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
              ],
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

  Widget _buildDailySummary(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.dailyDeep),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildProgressItem('Todo 清空率', '84.5%', 0.845, ModuleColors.daily),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildProgressItem('饮水达标', '78.2%', 0.782, const Color(0xFF42A5F5)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildProgressItem('睡眠', '7.2h', 0.72, const Color(0xFF7E57C2)),
            ),
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
