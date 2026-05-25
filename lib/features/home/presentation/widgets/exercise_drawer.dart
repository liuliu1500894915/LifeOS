import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/widgets/number_keyboard.dart';
import '../providers/home_providers.dart';

const _exerciseColor = Color(0xFF66BB6A);

class ExerciseDrawer extends ConsumerStatefulWidget {
  const ExerciseDrawer({super.key});

  @override
  ConsumerState<ExerciseDrawer> createState() => _ExerciseDrawerState();
}

class _ExerciseDrawerState extends ConsumerState<ExerciseDrawer> {
  String? _selectedExercise;
  String _minutes = '';

  static const _exerciseTypes = [
    ('跑步🏃', '跑步'),
    ('走路🚶', '走路'),
    ('骑行🚴', '骑行'),
    ('游泳🏊', '游泳'),
    ('力量💪', '力量'),
    ('瑜伽🧘', '瑜伽'),
  ];

  double get _caloriesBurned {
    if (_selectedExercise == null || _minutes.isEmpty) return 0;
    return calculateCaloriesBurned(_selectedExercise!, int.tryParse(_minutes) ?? 0);
  }

  double get _metValue {
    if (_selectedExercise == null) return 0;
    return metValues[_selectedExercise!] ?? 5.0;
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
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildExerciseTypes(),
                  const SizedBox(height: 12),
                  if (_selectedExercise != null) _buildMetInfo(),
                  const SizedBox(height: 8),
                  _buildDurationDisplay(),
                  if (_caloriesBurned > 0) ...[
                    const SizedBox(height: 8),
                    _buildCalorieResult(),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            NumberKeyboard(
              showDecimal: false,
              onKeyPressed: (key) {
                setState(() {
                  if (_minutes.length >= 4) return;
                  if (_minutes == '0') _minutes = '';
                  _minutes += key;
                });
              },
              onBackspace: () {
                setState(() {
                  if (_minutes.isNotEmpty) _minutes = _minutes.substring(0, _minutes.length - 1);
                });
              },
              onConfirm: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: _exerciseColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.fitness_center, size: 18, color: _exerciseColor)),
        const SizedBox(width: 10),
        const Text('运动记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildExerciseTypes() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _exerciseTypes.map((item) {
        final selected = _selectedExercise == item.$2;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedExercise = item.$2);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? _exerciseColor : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(item.$1,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : const Color(0xFF616161))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: _exerciseColor.withAlpha(10), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Text('$_selectedExercise', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _exerciseColor)),
          const Spacer(),
          Text('MET ${_metValue.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          const SizedBox(width: 8),
          Text('${defaultBodyWeight.toInt()}kg', style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _buildDurationDisplay() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Text('运动时长', style: TextStyle(fontSize: 14, color: Color(0xFF616161))),
          const Spacer(),
          Text(
            _minutes.isEmpty ? '0' : _minutes,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: _exerciseColor, letterSpacing: 1),
          ),
          const SizedBox(width: 4),
          const Text('min', style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _buildCalorieResult() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_exerciseColor.withAlpha(20), _exerciseColor.withAlpha(5)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, size: 18, color: _exerciseColor),
          const SizedBox(width: 6),
          const Text('消耗', style: TextStyle(fontSize: 14, color: Color(0xFF616161))),
          const Spacer(),
          Text('${_caloriesBurned.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _exerciseColor)),
          const SizedBox(width: 4),
          const Text('kcal', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  void _save() {
    if (_minutes.isEmpty || _selectedExercise == null) return;
    ref.read(actionLogNotifierProvider.notifier).addAction(
      PetActionLog(
        logId: DateTime.now().millisecondsSinceEpoch.toString(),
        actionType: ActionType.sport,
        valueNumeric: double.tryParse(_minutes) ?? 0,
        subCategory: _selectedExercise,
        createdAt: DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
  }
}
