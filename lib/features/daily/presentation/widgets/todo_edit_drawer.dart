import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../providers/daily_providers.dart';

class TodoEditDrawer extends StatefulWidget {
  const TodoEditDrawer({super.key, this.todo});
  final TodoItem? todo;

  @override
  State<TodoEditDrawer> createState() => _TodoEditDrawerState();
}

class _TodoEditDrawerState extends State<TodoEditDrawer> {
  late TextEditingController _titleController;
  late QuadrantType _selectedQuadrant;
  late DateTime _targetDate;
  DateTime? _reminderClock;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    final t = widget.todo;
    _titleController = TextEditingController(text: t?.title ?? '');
    _selectedQuadrant = t?.quadrant ?? QuadrantType.D;
    _targetDate = t?.targetDate ?? DateTime.now();
    _reminderClock = t?.reminderClock;
    _isCompleted = t?.isCompleted ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
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
                  const SizedBox(height: 16),
                  _buildQuadrantSelector(),
                  const SizedBox(height: 16),
                  _buildDateRow(),
                  const SizedBox(height: 16),
                  if (widget.todo != null) _buildCompletedSwitch(),
                  const SizedBox(height: 20),
                  _buildSaveButton(),
                  const SizedBox(height: 16),
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
        autofocus: widget.todo == null,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          hintText: '任务名称',
          hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildQuadrantSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('优先级象限', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF616161))),
        const SizedBox(height: 8),
        Row(
          children: QuadrantType.values.map((q) {
            final selected = q == _selectedQuadrant;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedQuadrant = q);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? q.color : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${q.shortLabel}.${q.label}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF9E9E9E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateRow() {
    return Row(
      children: [
        Expanded(child: _buildDatePill(
          icon: Icons.calendar_today,
          label: '${_targetDate.month}月${_targetDate.day}日',
          onTap: _pickDate,
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildDatePill(
          icon: Icons.alarm,
          label: _reminderClock != null
              ? '${_reminderClock!.hour}:${_reminderClock!.minute.toString().padLeft(2, '0')}'
              : '不提醒',
          onTap: _pickReminder,
        )),
      ],
    );
  }

  Widget _buildDatePill({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF9E9E9E)),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF616161)), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('标记完成', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF616161))),
      value: _isCompleted,
      activeTrackColor: ModuleColors.success.withAlpha(80),
      onChanged: (v) => setState(() => _isCompleted = v),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: ModuleColors.daily,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          widget.todo != null ? '保存修改' : '添加任务',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _pickReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderClock != null
          ? TimeOfDay.fromDateTime(_reminderClock!)
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _reminderClock = DateTime(
          _targetDate.year, _targetDate.month, _targetDate.day,
          picked.hour, picked.minute,
        );
      });
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) return;
    Navigator.of(context).pop();
  }
}
