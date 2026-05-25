import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/analytics_providers.dart';

class InsightDetailPage extends ConsumerWidget {
  const InsightDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(insightCardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('因果明细'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(insight.summary, style: const TextStyle(fontSize: 13, color: Color(0xFF616161))),
                  const SizedBox(height: 8),
                  Text('皮尔逊相关系数 r=${insight.coefficient.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: ModuleColors.analytics)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: insight.points.length.toDouble() - 1,
                  minY: 0,
                  maxY: 80,
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < insight.points.length; i++) FlSpot(i.toDouble(), insight.points[i].x * 10)],
                      color: const Color(0xFF7E57C2),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: [for (var i = 0; i < insight.points.length; i++) FlSpot(i.toDouble(), insight.points[i].y)],
                      color: ModuleColors.expense,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
