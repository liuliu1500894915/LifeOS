import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/finance_providers.dart';
import '../widgets/transaction_drawer.dart';

class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorth = ref.watch(netWorthProvider);
    final totalLiability = ref.watch(totalLiabilityProvider);
    final todayExpense = ref.watch(todayExpenseProvider);
    final monthExpense = ref.watch(monthExpenseProvider);
    final monthBudget = ref.watch(monthBudgetProvider);
    final todayTxCount = ref.watch(todayTransactionsProvider).where((t) => t.flowType == 'EXPENSE').length;
    final assets = ref.watch(assetListProvider);
    final subs = ref.watch(subscriptionListProvider);

    final budgetPercent = monthBudget > 0 ? ((monthBudget - monthExpense) / monthBudget * 100).clamp(0.0, 100.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildNetWorthCard(context, netWorth, totalLiability),
              const SizedBox(height: 12),
              _buildSpendingRow(context, todayExpense, todayTxCount, monthExpense, budgetPercent),
              _buildQuickRecordButton(context),
              const SizedBox(height: 16),
              _buildSectionLabel('账户管理'),
              const SizedBox(height: 8),
              _buildEntryCard(
                context,
                icon: Icons.account_balance_wallet,
                title: '钱包账户',
                subtitle: '管理微信、支付宝、银行卡等钱包',
                onTap: () => context.push(AppRoutes.accounts),
              ),
              const SizedBox(height: 16),
              _buildSectionLabel('资产与固定账单管理'),
              const SizedBox(height: 8),
              _buildEntryCard(
                context,
                icon: Icons.chair_outlined,
                title: '固定资产库',
                subtitle: '${assets.length}件设备 | 估值: ¥${assets.fold<double>(0, (s, a) => s + a.purchasePrice).toStringAsFixed(0)}',
                onTap: () => context.push(AppRoutes.assets),
              ),
              const SizedBox(height: 8),
              _buildEntryCard(
                context,
                icon: Icons.autorenew,
                title: '自动化订阅管理',
                subtitle: '${subs.length}项服务 | 月均: ¥${subs.fold<double>(0, (s, sub) => s + sub.amount).toStringAsFixed(0)}',
                onTap: () => context.push(AppRoutes.subscriptions),
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
              Icon(Icons.lock_outline, size: 12, color: ModuleColors.success),
              SizedBox(width: 4),
              Text(
                '同步状态:已加密',
                style: TextStyle(fontSize: 11, color: ModuleColors.success),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Text(
          '财务中心',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => context.push(AppRoutes.financeAnalysis),
          icon: const Icon(Icons.bar_chart, size: 20),
        ),
      ],
    );
  }

  Widget _buildNetWorthCard(BuildContext context, double netWorth, double totalLiability) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.accounts),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [ModuleColors.finance, Color(0xFF1B8C5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前总净资产',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${netWorth.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMiniStat('总负债', '¥${totalLiability.toStringAsFixed(0)}', Colors.white70),
                const SizedBox(width: 16),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildSpendingRow(BuildContext context, double todayExpense, int todayCount, double monthExpense, double budgetPercent) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.receipt_long,
            title: '今日花费',
            amount: '¥${todayExpense.toStringAsFixed(2)}',
            detail: '$todayCount笔支出',
            color: ModuleColors.expense,
            onTap: () => context.push(AppRoutes.todayExpenses),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.calendar_month,
            title: '本月花费',
            amount: '¥${monthExpense.toStringAsFixed(0)}',
            detail: budgetPercent > 0 ? '预算剩余: ${budgetPercent.toStringAsFixed(1)}%' : '未设预算',
            color: ModuleColors.daily,
            onTap: () => context.push(AppRoutes.monthlySpending),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String amount,
    required String detail,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF757575))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF616161)));
  }

  Widget _buildEntryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: const Color(0xFF616161)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
            if (trailing != null) trailing else const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRecordButton(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => const TransactionDrawer(),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: ModuleColors.finance,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text('记一笔', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
