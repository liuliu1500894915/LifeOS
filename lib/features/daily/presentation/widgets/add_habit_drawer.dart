import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../providers/daily_providers.dart';

class AddHabitDrawer extends StatefulWidget {
  const AddHabitDrawer({super.key});

  @override
  State<AddHabitDrawer> createState() => _AddHabitDrawerState();
}

class _AddHabitDrawerState extends State<AddHabitDrawer> {
  final _nameController = TextEditingController();
  HabitTargetType _targetType = HabitTargetType.boolean;
  final _valueController = TextEditingController();
  final _unitController = TextEditingController();
  String _selectedIcon = '✅';

  static const _iconOptions = ['✅', '💧', '📖', '🧘', '🚶', '💪', '🎵', '🎯', '💤', '🧹'];

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildTypeSelector(),
                    if (_targetType == HabitTargetType.numeric) ...[
                      const SizedBox(height: 16),
                      _buildTargetRow(),
                    ],
                    const SizedBox(height: 16),
                    _buildIconSelector(),
                    const SizedBox(height: 20),
                    _buildSaveButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _nameController,
        autofocus: true,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          hintText: '习惯名称',
          hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('打卡方式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF616161))),
        const SizedBox(height: 8),
        Row(
          children: HabitTargetType.values.map((t) {
            final selected = t == _targetType;
            final label = t == HabitTargetType.boolean ? '打卡/不打卡' : '数值追踪';
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _targetType = t);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? ModuleColors.daily : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF9E9E9E),
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTargetRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: '目标值',
                hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _unitController,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: '单位',
                hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('图标', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF616161))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _iconOptions.map((icon) {
            final selected = icon == _selectedIcon;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedIcon = icon);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: selected ? ModuleColors.daily.withAlpha(20) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: selected ? Border.all(color: ModuleColors.daily, width: 2) : null,
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
              ),
            );
          }).toList(),
        ),
      ],
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
        child: const Text('添加习惯', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    Navigator.of(context).pop();
  }
}
