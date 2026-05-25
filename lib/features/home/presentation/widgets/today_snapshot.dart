import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../features/daily/presentation/providers/daily_providers.dart';
import '../../../../../features/finance/presentation/providers/finance_providers.dart';
import '../providers/home_providers.dart';

class TodaySnapshot extends ConsumerWidget {
  const TodaySnapshot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    final todos = ref.watch(quadrantTodoProvider);
    final transactions = ref.watch(todayTransactionsProvider);
    final done = todos.where((t) => t.isCompleted).length;
    final total = todos.length;
    final spent = transactions.fold<double>(0, (s, t) => s + t.amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日动态', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatItem(context, Icons.check_circle_outline, '待办', '$done/$total', ModuleColors.daily, () => context.go(AppRoutes.daily))),
              _buildDivider(),
              Expanded(child: _buildStatItem(context, Icons.account_balance_wallet_outlined, '花费', '¥${spent.toStringAsFixed(0)}', ModuleColors.finance, () => context.go(AppRoutes.finance))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatItem(context, Icons.water_drop_outlined, '喝水', '${summary.waterMl.toInt()}ml', const Color(0xFF42A5F5), null)),
              _buildDivider(),
              Expanded(child: _buildStatItem(context, Icons.fitness_center_outlined, '运动', '${summary.sportMinutes.toInt()}min', const Color(0xFF66BB6A), null)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatItem(context, Icons.bed_outlined, '睡眠', '${summary.sleepHours}h', const Color(0xFF7E57C2), null)),
              _buildDivider(),
              Expanded(child: _buildStatItem(context, Icons.local_fire_department_outlined, '消耗', '${summary.caloriesOut.toInt()}kcal', const Color(0xFFFF7043), null)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label, String value, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 14, color: Color(0xFFBDBDBD)),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 28, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 8));
  }
}
