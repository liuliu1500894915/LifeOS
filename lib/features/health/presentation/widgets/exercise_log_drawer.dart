import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_router.dart';
import '../../../../../core/widgets/number_keyboard.dart';
import '../../domain/met_table.dart';
import '../providers/exercise_providers.dart';

const _exerciseColor = Color(0xFF66BB6A);

/// 运动记录录入（P3-2）。底部抽屉：选运动 + 强度 + 时长 → 实时算消耗
/// （MET × 体重kg × 时长h），体重取档案 `UserProfile.weightKg`；档案缺体重时按
/// [MetTable.fallbackWeightKg] 降级估算并提示补全。消耗可手动覆盖。
/// 保存时把算好的 [caloriesBurned] 冻结写入 `ExerciseLog`。
class ExerciseLogDrawer extends ConsumerStatefulWidget {
  const ExerciseLogDrawer({super.key});

  @override
  ConsumerState<ExerciseLogDrawer> createState() => _ExerciseLogDrawerState();
}

class _ExerciseLogDrawerState extends ConsumerState<ExerciseLogDrawer> {
  String? _selectedExercise;
  ExerciseIntensity _intensity = ExerciseIntensity.medium;
  String _minutes = '';

  /// 非 null 表示用户手动覆盖了消耗；null 表示用自动计算值。
  double? _manualCalories;

  static const _exerciseTypes = [
    ('跑步🏃', '跑步'),
    ('走路🚶', '走路'),
    ('骑行🚴', '骑行'),
    ('游泳🏊', '游泳'),
    ('力量💪', '力量'),
    ('瑜伽🧘', '瑜伽'),
    ('跳绳🪢', '跳绳'),
    ('HIIT🔥', 'HIIT'),
    ('🏀篮球', '篮球'),
    ('舞蹈💃', '舞蹈'),
  ];

  double get _met {
    if (_selectedExercise == null) return 0;
    return MetTable.metFor(_selectedExercise!, _intensity);
  }

  int get _minutesValue => int.tryParse(_minutes) ?? 0;

  (double weight, bool isFallback) get _weight {
    final real = ref.read(currentWeightKgProvider);
    if (real != null) return (real, false);
    return (MetTable.fallbackWeightKg, true);
  }

  double get _autoCalories => MetTable.caloriesBurned(
        met: _met,
        weightKg: _weight.$1,
        durationMinutes: _minutesValue,
      );

  double get _displayedCalories => _manualCalories ?? _autoCalories;

  Future<void> _editCaloriesManually() async {
    final controller =
        TextEditingController(text: _displayedCalories.toStringAsFixed(0));
    final result = await showDialog<(double, bool)>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('手动修改消耗'),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '消耗 (kcal)',
              suffixText: 'kcal',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, (0.0, true)),
              child: const Text('恢复自动'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (0.0, false)),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v == null || v < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('请输入有效数字')),
                  );
                  return;
                }
                Navigator.pop(ctx, (v, false));
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (!mounted || result == null) return;
    final (value, resetToAuto) = result;
    setState(() {
      _manualCalories = resetToAuto ? null : value;
    });
  }

  Future<void> _save() async {
    if (_selectedExercise == null) {
      _toast('请选择运动类型');
      return;
    }
    if (_minutesValue <= 0) {
      _toast('请输入运动时长');
      return;
    }
    try {
      await ref.read(exerciseLogProvider.notifier).addExerciseLog(
            exerciseName: _selectedExercise!,
            durationMinutes: _minutesValue,
            intensity: _intensity.code,
            caloriesBurned: _displayedCalories,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _toast('保存失败: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final (weight, isFallback) = _weight;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildExerciseTypes(),
                  const SizedBox(height: 10),
                  _buildIntensitySelector(),
                  const SizedBox(height: 8),
                  _buildWeightInfo(weight, isFallback),
                  const SizedBox(height: 8),
                  _buildDurationDisplay(),
                  const SizedBox(height: 8),
                  _buildCalorieResult(),
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
                  // 重新输入时长则视为回到自动计算（清除手动覆盖）。
                  _manualCalories = null;
                });
              },
              onBackspace: () {
                setState(() {
                  if (_minutes.isNotEmpty) {
                    _minutes = _minutes.substring(0, _minutes.length - 1);
                  }
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
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _exerciseColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fitness_center, size: 18, color: _exerciseColor),
        ),
        const SizedBox(width: 10),
        const Text('运动记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_selectedExercise != null)
          Text('MET ${_met.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
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
            child: Text(
              item.$1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF616161),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIntensitySelector() {
    const levels = ExerciseIntensity.values;
    return Row(
      children: [
        const Text('强度', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: levels.map((lv) {
              final selected = _intensity == lv;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _intensity = lv),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? _exerciseColor.withAlpha(230)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        lv.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? Colors.white : const Color(0xFF616161),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightInfo(double weight, bool isFallback) {
    if (!isFallback) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('体重 ${weight.toStringAsFixed(1)}kg（取自档案）',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
      );
    }
    // 缺体重：降级估算 + 提示补全（点击跳转档案编辑）。
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        context.push(AppRoutes.profileEdit);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.orange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '档案未设体重，按 ${weight.toStringAsFixed(0)}kg 估算，点此补全',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationDisplay() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('运动时长', style: TextStyle(fontSize: 14, color: Color(0xFF616161))),
          const Spacer(),
          Text(
            _minutes.isEmpty ? '0' : _minutes,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _exerciseColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 4),
          const Text('min', style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _buildCalorieResult() {
    final overridden = _manualCalories != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_exerciseColor.withAlpha(20), _exerciseColor.withAlpha(5)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, size: 18, color: _exerciseColor),
          const SizedBox(width: 6),
          const Text('消耗', style: TextStyle(fontSize: 14, color: Color(0xFF616161))),
          const Spacer(),
          Text(
            _displayedCalories.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _exerciseColor,
            ),
          ),
          const SizedBox(width: 4),
          const Text('kcal', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _editCaloriesManually,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: overridden
                    ? _exerciseColor.withAlpha(30)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                overridden ? '已手动' : '手动改',
                style: TextStyle(
                  fontSize: 11,
                  color: overridden ? _exerciseColor : const Color(0xFF757575),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
