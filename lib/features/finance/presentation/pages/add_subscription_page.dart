import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/finance_providers.dart';

class AddSubscriptionPage extends ConsumerStatefulWidget {
  const AddSubscriptionPage({super.key, this.editSub});
  final SubscriptionItem? editSub;

  @override
  ConsumerState<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends ConsumerState<AddSubscriptionPage> {
  late final _nameController = TextEditingController(text: widget.editSub?.serviceName ?? '');
  late final _amountController = TextEditingController(text: widget.editSub?.amount.toStringAsFixed(0) ?? '');
  late DateTime _nextBillingDate = widget.editSub?.nextBillingDate ?? DateTime.now().add(const Duration(days: 30));
  late String _billingCycle = widget.editSub?.billingCycle ?? 'MONTHLY';
  late bool _alertEnabled = widget.editSub?.alertEnabled ?? true;
  String? _selectedAccountId;

  bool get _isEdit => widget.editSub != null;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text);
    if (name.isEmpty || amount == null || amount <= 0) return;

    final accountId = _selectedAccountId ?? widget.editSub?.accountId ?? '';
    if (accountId.isEmpty) return;

    if (_isEdit) {
      await ref.read(subscriptionProvider.notifier).updateSubscription(
            widget.editSub!.id,
            serviceName: name,
            amount: amount,
            billingCycle: _billingCycle,
            nextBillingDate: _nextBillingDate,
            accountId: accountId,
            alertEnabled: _alertEnabled,
          );
    } else {
      await ref.read(subscriptionProvider.notifier).addSubscription(
            serviceName: name,
            amount: amount,
            billingCycle: _billingCycle,
            nextBillingDate: _nextBillingDate,
            accountId: accountId,
            alertEnabled: _alertEnabled,
          );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountProvider);
    final accounts = accountsAsync.valueOrNull ?? [];

    if (_selectedAccountId == null) {
      if (widget.editSub?.accountId != null) {
        _selectedAccountId = widget.editSub!.accountId;
      } else if (accounts.isNotEmpty) {
        _selectedAccountId = accounts.first.accountId;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_isEdit ? '编辑订阅' : '登记订阅服务'),
        backgroundColor: const Color(0xFFF8F9FA),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('服务名称'),
            _buildTextField(_nameController, 'Netflix Premium'),
            const SizedBox(height: 16),
            _buildLabel('扣费金额'),
            _buildTextField(_amountController, '¥ 98.00', keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _buildLabel('扣费账户'),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final acc = accounts[index];
                  final selected = _selectedAccountId == acc.accountId;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAccountId = acc.accountId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          acc.accountName,
                          style: TextStyle(fontSize: 13, color: selected ? Colors.white : const Color(0xFF616161)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('计费周期'),
            const SizedBox(height: 8),
            Row(
              children: ['MONTHLY', 'QUARTERLY', 'YEARLY'].map((cycle) {
                final selected = _billingCycle == cycle;
                final labels = {'MONTHLY': '每月付', 'QUARTERLY': '每季付', 'YEARLY': '每年付'};
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _billingCycle = cycle),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        labels[cycle]!,
                        style: TextStyle(
                          fontSize: 14,
                          color: selected ? Colors.white : const Color(0xFF616161),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildLabel('下次扣款日期'),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _nextBillingDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _nextBillingDate = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Color(0xFF757575)),
                    const SizedBox(width: 8),
                    Text(
                      '${_nextBillingDate.year}-${_nextBillingDate.month.toString().padLeft(2, '0')}-${_nextBillingDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('提前 3 天发出通知栏提醒', style: TextStyle(fontSize: 15)),
              value: _alertEnabled,
              onChanged: (v) => setState(() => _alertEnabled = v),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除订阅'),
                        content: Text('确定删除「${widget.editSub!.serviceName}」吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(subscriptionProvider.notifier).deleteSubscription(widget.editSub!.id);
                      if (mounted) Navigator.of(context).pop();
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('删除此订阅'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF616161))),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}
