import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/analytics_providers.dart';

class DailyEfficiencyPage extends ConsumerWidget {
  const DailyEfficiencyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dailyAnalyticsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('日常效率分析'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTopStats(summary),
            const SizedBox(height: 16),
            _buildRadarLikeCard(summary),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStats(DailyAnalyticsSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('Todo清空率', '${(summary.completionRate * 100).toStringAsFixed(1)}%', ModuleColors.daily),
          _stat('饮水', '${summary.waterMl.toInt()}ml', const Color(0xFF42A5F5)),
          _stat('睡眠', '${summary.sleepHours.toStringAsFixed(1)}h', const Color(0xFF7E57C2)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildRadarLikeCard(DailyAnalyticsSummary summary) {
    final values = [
      summary.completionRate * 100,
      (summary.waterMl / 20).clamp(0, 100),
      (summary.sleepHours / 10 * 100).clamp(0, 100),
      summary.habitTotal == 0 ? 0 : (summary.habitChecked / summary.habitTotal) * 100,
    ];

    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('执行力趋势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Todo', '饮水', '睡眠', '习惯'];
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Text(labels[i], style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i].toDouble())],
                    isCurved: true,
                    color: ModuleColors.daily,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
