import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

import '../../../../core/widgets/number_keyboard.dart';
import 'category_grid.dart';

class TransactionDrawer extends StatefulWidget {
  const TransactionDrawer({super.key});

  @override
  State<TransactionDrawer> createState() => _TransactionDrawerState();
}

class _TransactionDrawerState extends State<TransactionDrawer> {
  String _amount = '';
  String? _categoryId;
  String _accountName = '微信支付';
  final _remarkController = TextEditingController();
  DateTime _date = DateTime.now();

  static const _accounts = ['微信支付', '支付宝', '花呗(负债)', '招商银行卡'];

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

  void _save() {
    if (_amount.isEmpty || _categoryId == null) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
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
            // Amount display
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
            // Account selector
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _accounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final acc = _accounts[index];
                  final selected = _accountName == acc;
                  return GestureDetector(
                    onTap: () => setState(() => _accountName = acc),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          acc,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected ? Colors.white : const Color(0xFF616161),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Category grid
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
            // Date + remark row
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
            // Number keyboard
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
