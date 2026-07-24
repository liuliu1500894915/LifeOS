import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/number_keyboard.dart';
import '../providers/finance_providers.dart';
import 'category_grid.dart';

class TransactionDrawer extends ConsumerStatefulWidget {
  const TransactionDrawer({super.key});

  @override
  ConsumerState<TransactionDrawer> createState() => _TransactionDrawerState();
}

class _TransactionDrawerState extends ConsumerState<TransactionDrawer> {
  String _amount = '';
  String? _categoryId;
  String? _selectedAccountId;
  final _remarkController = TextEditingController();
  DateTime _date = DateTime.now();

  void _onKey(String key) {
    setState(() {
      if (key == 'BACKSPACE') {
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
      } else if (key == '.' && _amount.contains('.')) {
        return;
      } else {
        if (_amount.length < 10) _amount += key;
      }
    });
  }

  Future<void> _save() async {
    if (_amount.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入金额'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    if (_categoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择支出类别'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    if (_selectedAccountId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先添加一个钱包账户'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效金额'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    try {
      await ref.read(transactionProvider.notifier).addTransaction(
            flowType: 'EXPENSE',
            amount: amount,
            categoryId: _categoryId!,
            accountId: _selectedAccountId!,
            remark: _remarkController.text.isEmpty ? null : _remarkController.text,
            loggedAt: _date,
          );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountProvider);
    final accounts = accountsAsync.valueOrNull ?? [];
    final selectedId = _selectedAccountId ?? (accounts.isNotEmpty ? accounts.first.accountId : null);
    if (_selectedAccountId == null && selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedAccountId = selectedId);
      });
    }

    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Text('¥', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Text(
                      _amount.isEmpty ? '0.00' : _amount,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: 2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('暂无钱包，请先在财务页添加', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
                  ),
                ),
              )
            else
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final acc = accounts[index];
                  final isSelected = selectedId == acc.accountId;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAccountId = acc.accountId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          acc.accountName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : const Color(0xFF616161),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CategoryGrid(
                selectedId: _categoryId,
                onSelected: (id) {
                  HapticFeedback.mediumImpact();
                  setState(() => _categoryId = id);
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF757575)),
                          const SizedBox(width: 4),
                          Text(
                            '${_date.month}月${_date.day}日',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF616161)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _remarkController,
                      decoration: const InputDecoration(
                        hintText: '备注',
                        hintStyle: TextStyle(fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        filled: true,
                        fillColor: Color(0xFFF5F5F5),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            NumberKeyboard(
              onKeyPressed: _onKey,
              onConfirm: _save,
            ),
          ],
        ),
      ),
    );
  }
}
