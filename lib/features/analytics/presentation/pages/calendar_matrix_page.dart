import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/analytics_providers.dart';

class CalendarMatrixPage extends ConsumerWidget {
  const CalendarMatrixPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeAnalyticsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('日历账单回溯矩阵'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Text('本期总支出 ¥${finance.expense.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: 35,
                itemBuilder: (_, index) {
                  final intensity = (index % 5) / 4;
                  return Container(
                    decoration: BoxDecoration(
                      color: ModuleColors.finance.withOpacity(0.08 + intensity * 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF616161))),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
