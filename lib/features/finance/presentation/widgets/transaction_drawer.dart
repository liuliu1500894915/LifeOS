import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/number_keyboard.dart';
import '../providers/finance_providers.dart';
import 'category_grid.dart';

class TransactionDrawer extends ConsumerStatefulWidget {
  /// 传入 [editing] 则进入「编辑」模式：预填该交易、保存时走 updateTransaction。
  const TransactionDrawer({super.key, this.editing});

  final FinancialTransactionData? editing;

  @override
  ConsumerState<TransactionDrawer> createState() => _TransactionDrawerState();
}

class _TransactionDrawerState extends ConsumerState<TransactionDrawer> {
  String _amount = '';
  String? _categoryId;
  String? _selectedAccountId;
  final _remarkController = TextEditingController();
  DateTime _date = DateTime.now();

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _amount = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toString();
      _categoryId = e.categoryId;
      _selectedAccountId = e.accountId;
      _remarkController.text = e.remark ?? '';
      _date = e.loggedAt;
      _isLongTerm = e.expenseNature == 'AMORTIZED';
      _amortizeStart = e.amortizeStartDate;
      _amortizeEnd = e.amortizeEndDate;
    }
  }
  // P1-2:一次性摊销开关。日常(SPOT,默认)= 当日记一笔全额支出;
  // 长期(AMORTIZED)= 把全额平摊到覆盖区间每一天(见 domain/amortization.dart)。
  // 两种模式余额都按全额扣,长期仅多带覆盖起止日期。
  bool _isLongTerm = false;
  DateTime? _amortizeStart;
  DateTime? _amortizeEnd;

  /// 把 [DateTime] 截断到本地日零点(仅保留年月日)。
  /// 与 domain/amortization.dart、Repository 同口径(风险 §5.6),覆盖区间按日比较。
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

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

    // P1-2:长期摊销需带合法覆盖区间(含头含尾,end >= start;end==start 即单日合法)。
    // 日常模式保持 SPOT,不传区间。Repository 也会做防御性兜底校验。
    final expenseNature = _isLongTerm ? 'AMORTIZED' : 'SPOT';
    DateTime? amortizeStart;
    DateTime? amortizeEnd;
    if (_isLongTerm) {
      if (_amortizeStart == null || _amortizeEnd == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择长期支出的覆盖起止日期'), behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
      final start = _dateOnly(_amortizeStart!);
      final end = _dateOnly(_amortizeEnd!);
      if (end.isBefore(start)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('覆盖结束日期不能早于开始日期'), behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
      amortizeStart = start;
      amortizeEnd = end;
    }

    try {
      final notifier = ref.read(transactionProvider.notifier);
      final remark =
          _remarkController.text.isEmpty ? null : _remarkController.text;
      if (_isEditing) {
        await notifier.updateTransaction(
          transactionId: widget.editing!.transactionId,
          amount: amount,
          categoryId: _categoryId!,
          accountId: _selectedAccountId!,
          remark: remark,
          loggedAt: _date,
          expenseNature: expenseNature,
          amortizeStart: amortizeStart,
          amortizeEnd: amortizeEnd,
        );
      } else {
        await notifier.addTransaction(
          flowType: 'EXPENSE',
          amount: amount,
          categoryId: _categoryId!,
          accountId: _selectedAccountId!,
          remark: remark,
          loggedAt: _date,
          expenseNature: expenseNature,
          amortizeStart: amortizeStart,
          amortizeEnd: amortizeEnd,
        );
      }

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

  /// P1-2:「日常 / 长期」分段切换。日常=SPOT(当日记全额),长期=AMORTIZED(平摊到覆盖区间)。
  Widget _buildNatureToggle() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: _buildNatureSegment('日常', !_isLongTerm, () {
            HapticFeedback.selectionClick();
            setState(() => _isLongTerm = false);
          })),
          Expanded(child: _buildNatureSegment('长期', _isLongTerm, () {
            HapticFeedback.selectionClick();
            setState(() => _isLongTerm = true);
          })),
        ],
      ),
    );
  }

  Widget _buildNatureSegment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF616161),
          ),
        ),
      ),
    );
  }

  /// 日期选择 chip:[label]M月D日。label 为空时不显示前缀(日常模式的「记一笔日期」)。
  Widget _dateChip({String label = '', required DateTime date, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
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
              '$label${date.month}月${date.day}日',
              style: const TextStyle(fontSize: 13, color: Color(0xFF616161)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _remarkField() {
    return TextField(
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
    );
  }

  /// 日期/备注区:随「日常/长期」模式切换。
  /// 日常 = [记一笔日期] + 备注(单行);长期 = [覆盖起]~[覆盖止] + 备注(两行)。
  /// 长期模式下「记一笔日期」(loggedAt)用默认今天,用户只关心覆盖区间。
  Widget _buildDateAndRemarkArea() {
    if (!_isLongTerm) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _dateChip(
              date: _date,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(width: 8),
            Expanded(child: _remarkField()),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _dateChip(
                label: '覆盖起 ',
                date: _amortizeStart ?? _date,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _amortizeStart ?? _amortizeEnd ?? _date,
                    firstDate: DateTime(2020),
                    lastDate: _amortizeEnd ?? DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (d != null) setState(() => _amortizeStart = d);
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('~', style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
              ),
              _dateChip(
                label: '覆盖止 ',
                date: _amortizeEnd ?? _date,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _amortizeEnd ?? _amortizeStart ?? _date,
                    firstDate: _amortizeStart ?? DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (d != null) setState(() => _amortizeEnd = d);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _remarkField(),
        ],
      ),
    );
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
              child: _buildNatureToggle(),
            ),
            const SizedBox(height: 8),
            _buildDateAndRemarkArea(),
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
