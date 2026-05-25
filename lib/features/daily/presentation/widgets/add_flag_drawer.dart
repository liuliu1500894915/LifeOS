import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/number_keyboard.dart';

class AddFlagDrawer extends StatefulWidget {
  const AddFlagDrawer({super.key});

  @override
  State<AddFlagDrawer> createState() => _AddFlagDrawerState();
}

class _AddFlagDrawerState extends State<AddFlagDrawer> {
  final _titleController = TextEditingController();
  final _unitController = TextEditingController();
  String _targetAmount = '';
  DateTime? _deadline;

  @override
  void dispose() {
    _titleController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleField(),
                  const SizedBox(height: 14),
                  _buildTargetDisplay(),
                  const SizedBox(height: 14),
                  _buildDeadlineRow(),
                  const SizedBox(height: 14),
                  _buildUnitField(),
                  const SizedBox(height: 8),
                  NumberKeyboard(
                    showDecimal: true,
                    onKeyPressed: (key) {
                      setState(() {
                        if (_targetAmount.length >= 8) return;
                        if (key == '.' && _targetAmount.contains('.')) return;
                        if (_targetAmount == '0' && key != '.') _targetAmount = '';
                        _targetAmount += key;
                      });
                    },
                    onBackspace: () {
                      setState(() {
                        if (_targetAmount.isNotEmpty) _targetAmount = _targetAmount.substring(0, _targetAmount.length - 1);
                      });
                    },
                    onConfirm: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(
        child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _titleController,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          hintText: 'Flag 目标',
          hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildTargetDisplay() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Text('目标值', style: TextStyle(fontSize: 14, color: Color(0xFF616161))),
          const Spacer(),
          Text(
            _targetAmount.isEmpty ? '0' : _targetAmount,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: ModuleColors.daily, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineRow() {
    return GestureDetector(
      onTap: _pickDeadline,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF9E9E9E)),
            const SizedBox(width: 8),
            Text(
              _deadline != null ? '${_deadline!.year}年${_deadline!.month}月${_deadline!.day}日' : '选择截止日期',
              style: TextStyle(fontSize: 14, color: _deadline != null ? const Color(0xFF616161) : const Color(0xFFBDBDBD)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitField() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _unitController,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: '单位（如：元、kg、次）',
          hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _save() {
    if (_titleController.text.trim().isEmpty || _targetAmount.isEmpty) return;
    Navigator.of(context).pop();
  }
}
