import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/cream_glass.dart';
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

    // 奶油玻璃：L1 光晕背景铺底，内容浮在其上。
    return Scaffold(
      backgroundColor: CreamGlass.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 14),
                  _buildNetWorthCard(context, netWorth, totalLiability),
                  const SizedBox(height: 12),
                  _buildSpendingRow(context, todayExpense, todayTxCount, monthExpense, budgetPercent),
                  const SizedBox(height: 12),
                  _buildQuickRecordButton(context),
                  const SizedBox(height: 20),
                  const SectionLabel('账户管理'),
                  _buildEntryCard(
                    context,
                    icon: Icons.account_balance_wallet,
                    title: '钱包账户',
                    subtitle: '微信 · 支付宝 · 银行卡',
                    onTap: () => context.push(AppRoutes.accounts),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel('资产与固定账单'),
                  _buildEntryCard(
                    context,
                    icon: Icons.chair_outlined,
                    title: '固定资产库',
                    subtitle: '${assets.length} 件 · 估值 ¥${assets.fold<double>(0, (s, a) => s + a.purchasePrice).toStringAsFixed(0)}',
                    onTap: () => context.push(AppRoutes.assets),
                  ),
                  const SizedBox(height: 10),
                  _buildEntryCard(
                    context,
                    icon: Icons.autorenew,
                    title: '自动化订阅管理',
                    subtitle: '${subs.length} 项 · 月均 ¥${subs.fold<double>(0, (s, sub) => s + sub.amount).toStringAsFixed(0)}',
                    onTap: () => context.push(AppRoutes.subscriptions),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // L1 氛围层：状态 chip 用毛玻璃，透出背景光晕。
        const GlassPanel(
          radius: 999,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 11, color: CreamGlass.brand),
              SizedBox(width: 4),
              Text(
                '已加密',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: CreamGlass.brand),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Text(
          '财务中心',
          style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: CreamGlass.ink),
        ),
        const Spacer(),
        GlassPanel(
          radius: 999,
          padding: EdgeInsets.zero,
          child: IconButton(
            onPressed: () => context.push(AppRoutes.financeAnalysis),
            icon: const Icon(Icons.bar_chart, size: 18, color: CreamGlass.brand),
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  /// L3 主角层：核心数字用完整软陶（本屏视觉重量最大的元素）。
  Widget _buildNetWorthCard(BuildContext context, double netWorth, double totalLiability) {
    return ClaySurface(
      onTap: () => context.push(AppRoutes.accounts),
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前总净资产',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.3,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '¥${netWorth.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 33,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.05,
                letterSpacing: -0.8,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '总负债 ¥${totalLiability.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 15),
              ],
            ),
          ],
        ),
      ),
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
            detail: '$todayCount 笔支出',
            // 奶油玻璃色板：支出用蜜桃，替代旧的正红。
            color: CreamGlass.peach,
            onTap: () => context.push(AppRoutes.todayExpenses),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.calendar_month,
            title: '本月花费',
            amount: '¥${monthExpense.toStringAsFixed(0)}',
            detail: budgetPercent > 0 ? '预算剩余 ${budgetPercent.toStringAsFixed(1)}%' : '未设预算',
            // 本月为中性统计值，用主绿而非旧的亮蓝。
            color: CreamGlass.brand,
            onTap: () => context.push(AppRoutes.monthlySpending),
          ),
        ),
      ],
    );
  }

  /// L2 内容层：数据卡用不透明奶油实体（要被阅读，不用玻璃）。
  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String amount,
    required String detail,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CreamCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w600,
                  color: CreamGlass.inkMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(detail,
              style: const TextStyle(fontSize: 11, color: CreamGlass.inkSoft)),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    // L2 内容层：入口列表同为奶油实体卡。
    return CreamCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CreamGlass.brand.withAlpha(24),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: CreamGlass.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: CreamGlass.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, color: CreamGlass.inkSoft)),
              ],
            ),
          ),
          if (trailing != null)
            trailing
          else
            const Icon(Icons.chevron_right, color: Color(0xFFC3D0C8), size: 20),
        ],
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
      // L3 主角层：主行动按钮用蜜桃软陶，与净资产卡形成绿/橙双主角。
      child: ClaySurface(
        from: CreamGlass.peachLight,
        to: CreamGlass.peach,
        radius: 19,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text('记一笔', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
