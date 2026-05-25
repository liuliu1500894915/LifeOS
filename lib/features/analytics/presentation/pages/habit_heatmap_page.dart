import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/analytics_providers.dart';

class HabitHeatmapPage extends ConsumerWidget {
  const HabitHeatmapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(yearlyHeatmapProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('365天热力图'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: values.map((v) {
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: ModuleColors.analytics.withOpacity(0.1 + v * 0.9),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
