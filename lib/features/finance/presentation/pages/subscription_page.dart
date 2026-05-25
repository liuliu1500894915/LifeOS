import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/finance_providers.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subscriptionListProvider);
    final monthlyTotal = subs.fold<double>(0, (s, sub) => s + sub.amount);
    final now = DateTime.now();
    final upcomingBills = subs.where((s) => s.daysUntilBilling(now) <= 7).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('周期订阅管理'),
        backgroundColor: const Color(0xFFF8F9FA),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('扣费预测', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBar(monthlyTotal, subs.length, upcomingBills),
          Expanded(
            child: subs.isEmpty
                ? const Center(child: Text('暂无订阅，点击 + 添加', style: TextStyle(fontSize: 15, color: Color(0xFF9E9E9E))))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: subs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _SubscriptionCard(sub: subs[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addSubscription),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryBar(double monthly, int count, int upcomingBills) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('月度订阅开销', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
              const SizedBox(height: 4),
              Text('¥${monthly.toStringAsFixed(0)}/月',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ModuleColors.finance)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$count 项服务', style: const TextStyle(fontSize: 13, color: Color(0xFF757575))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: upcomingBills > 0 ? ModuleColors.warning.withAlpha(25) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  upcomingBills > 0 ? '⚠️ 本周$upcomingBills笔待扣' : '本月暂无待扣',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: upcomingBills > 0 ? ModuleColors.warning : const Color(0xFF9E9E9E),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub});
  final SubscriptionItem sub;

  @override
  Widget build(BuildContext context) {
    final daysLeft = sub.daysUntilBilling(DateTime.now());
    final isUrgent = daysLeft <= 3 && daysLeft >= 0;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.addSubscription, extra: sub),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isUrgent
              ? Border.all(color: ModuleColors.warning.withAlpha(80))
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(_serviceIcon(sub.serviceName), style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.serviceName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        sub.billingCycle == 'MONTHLY' ? '每月付' : (sub.billingCycle == 'YEARLY' ? '每年付' : '每季付'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('¥${sub.amount.toStringAsFixed(0)}/月',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(sub.accountName, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? ModuleColors.warning.withAlpha(25)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysLeft >= 0 ? '${daysLeft}天后扣费' : '已过${-daysLeft}天',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isUrgent ? ModuleColors.warning : const Color(0xFF616161),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ModuleColors.warning.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'T-${daysLeft} 强预警',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ModuleColors.warning),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _serviceIcon(String name) {
    if (name.contains('ChatGPT')) return '🧠';
    if (name.contains('Netflix')) return '🎬';
    if (name.contains('Spotify')) return '🎵';
    return '🔄';
  }
}
