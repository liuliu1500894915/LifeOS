import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/finance_providers.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountProvider);
    final netWorth = ref.watch(netWorthProvider);
    final totalLiability = ref.watch(totalLiabilityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('钱包与账户'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: Column(
        children: [
          _buildSummaryCard(netWorth, totalLiability),
          Expanded(
            child: accountsAsync.when(
              data: (accounts) => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _AccountCard(account: accounts[index]),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(double netWorth, double totalLiability) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ModuleColors.finance, Color(0xFF1B8C5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('总净资产', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 4),
              Text('¥${netWorth.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('总负债', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 4),
              Text('¥${totalLiability.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddAccountSheet(BuildContext context, WidgetRef ref) {
    final nameCtl = TextEditingController();
    final balanceCtl = TextEditingController();
    String type = 'CASH';
    bool isLiability = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: nameCtl, decoration: const InputDecoration(labelText: '账户名称', hintText: '如：招商银行卡')),
                      const SizedBox(height: 12),
                      TextField(controller: balanceCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '初始余额', hintText: '0.00')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('类型: '),
                          const SizedBox(width: 8),
                          ChoiceChip(label: const Text('现金/电子'), selected: type == 'CASH', onSelected: (_) => setModalState(() => type = 'CASH')),
                          const SizedBox(width: 8),
                          ChoiceChip(label: const Text('借记卡'), selected: type == 'DEBIT', onSelected: (_) => setModalState(() => type = 'DEBIT')),
                          const SizedBox(width: 8),
                          ChoiceChip(label: const Text('信用卡'), selected: type == 'CREDIT', onSelected: (_) => setModalState(() => type = 'CREDIT')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('负债账户'),
                        value: isLiability,
                        onChanged: (v) => setModalState(() => isLiability = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            final name = nameCtl.text.trim();
                            final balance = double.tryParse(balanceCtl.text) ?? 0;
                            if (name.isEmpty) return;
                            ref.read(accountProvider.notifier).addAccount(name, type, isLiability, balance);
                            Navigator.pop(ctx);
                          },
                          child: const Text('添加账户'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});
  final PaymentAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeIcons = {'CASH': '💰', 'DEBIT': '🏦', 'CREDIT': '💳'};
    final icon = typeIcons[account.accountType] ?? '💰';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: account.isLiability ? Border.all(color: ModuleColors.warning.withAlpha(60)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(account.accountName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    if (account.isLiability) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ModuleColors.warning.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('负债', style: TextStyle(fontSize: 10, color: ModuleColors.warning)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  account.accountType == 'CASH' ? '现金/电子钱包' : (account.accountType == 'DEBIT' ? '借记卡' : '信用卡'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${account.balance >= 0 ? "" : "-"}¥${account.balance.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: account.isLiability ? ModuleColors.warning : const Color(0xFF43A047),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showAdjustSheet(context, ref, account),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('调整余额', style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAdjustSheet(BuildContext context, WidgetRef ref, PaymentAccount account) {
    final ctl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('调整「${account.accountName}」余额', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('当前余额: ¥${account.balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
              const SizedBox(height: 16),
              TextField(
                controller: ctl,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(
                  labelText: '新余额',
                  hintText: '直接输入新余额',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(accountProvider.notifier).deleteAccount(account.accountId);
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('删除账户'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final newBalance = double.tryParse(ctl.text);
                        if (newBalance == null) return;
                        ref.read(accountProvider.notifier).updateAccount(account.accountId, balance: newBalance);
                        Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
