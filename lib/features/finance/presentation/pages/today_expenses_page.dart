import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/finance_providers.dart';
import '../widgets/transaction_drawer.dart';

class TodayExpensesPage extends ConsumerWidget {
  const TodayExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(todayTransactionsProvider);
    final total = transactions.fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('今日花费明细'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: Column(
        children: [
          _buildSummaryBar(total, transactions.length),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = transactions[index];
                return _TransactionCard(tx: t);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const TransactionDrawer(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryBar(double total, int count) {
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
              const Text('今日消费', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
              const SizedBox(height: 4),
              Text('¥${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count 笔支出',
                style: const TextStyle(fontSize: 13, color: Color(0xFF757575))),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.tx});
  final TransactionItem tx;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _getCategoryIcon(tx.categoryId),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${tx.loggedAt.hour}:${tx.loggedAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                    const SizedBox(width: 8),
                    Text(tx.categoryName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
                if (tx.remark != null && tx.remark!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('备注: ${tx.remark}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('-¥${tx.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE53935))),
              const SizedBox(height: 2),
              Text(tx.accountName, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryIcon(String id) {
    const icons = {'food': '🍱', 'transport': '🚗', 'entertainment': '🎉', 'drink': '💧', 'shopping': '🛒', 'housing': '🏠', 'pet': '🐱'};
    return icons[id] ?? '📌';
  }
}
