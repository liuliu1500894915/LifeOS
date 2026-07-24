import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tdee_calculator.dart';
import '../providers/exercise_providers.dart' show userProfileProvider;
import '../providers/goal_providers.dart';

/// 设置 / 修改每日营养目标（P2-4）。
///
/// 两条路径（执行计划 P2-4 规格「目标未设时引导走 TDEE 或手填」）：
/// - **自动（TDEE）**：档案完整时，按「性别/身高/体重/年龄 + 活动量 + 目标」用
///   [TdeeCalculator] 算出四项目标，`isAutoCalculated=true`；
/// - **手动**：用户直接填四项目标（档案不完整时唯一可用路径），`isAutoCalculated=false`。
///
/// 写入经 [NutritionGoalNotifier.upsertGoal]（upsert），写完后 [watchGoal] 流自动
/// 重发，环/条即时刷新 —— 无 invalidate。读取 [userProfileProvider]（运动侧已暴露
/// 的只读档案流，避免重复建一份档案仓库）。
void showNutritionGoalSetupSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _NutritionGoalSetupSheet(),
  );
}

class _NutritionGoalSetupSheet extends ConsumerStatefulWidget {
  const _NutritionGoalSetupSheet();

  @override
  ConsumerState<_NutritionGoalSetupSheet> createState() =>
      _NutritionGoalSetupSheetState();
}

class _NutritionGoalSetupSheetState
    extends ConsumerState<_NutritionGoalSetupSheet> {
  late ActivityLevel _activity;
  late GoalType _goalType;
  late bool _manual;

  late final TextEditingController _calCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _carbCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 用已有目标预填（无则默认 中度活动 / 维持 / 自动模式）。
    final existing = ref.read(nutritionGoalProvider).valueOrNull;
    _activity = existing == null
        ? ActivityLevel.moderate
        : ActivityLevel.fromCode(existing.activityLevel);
    _goalType = existing == null
        ? GoalType.maintain
        : GoalType.fromCode(existing.goalType);
    _manual = existing == null ? false : !existing.isAutoCalculated;

    _calCtrl = TextEditingController(
      text: existing == null ? '' : existing.calorieTarget.toStringAsFixed(0),
    );
    _proteinCtrl = TextEditingController(
      text: existing == null ? '' : existing.proteinTarget.toStringAsFixed(0),
    );
    _fatCtrl = TextEditingController(
      text: existing == null ? '' : existing.fatTarget.toStringAsFixed(0),
    );
    _carbCtrl = TextEditingController(
      text: existing == null ? '' : existing.carbTarget.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbCtrl.dispose();
    super.dispose();
  }

  /// 由当前档案 + 选中项算 TDEE；档案不完整返回 null。
  TdeeResult? _computeTdee() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return null;
    return TdeeCalculator.calculate(
      gender: Gender.fromCode(profile.gender),
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      birthDate: profile.birthDate,
      activityLevel: _activity,
      goalType: _goalType,
    );
  }

  void _fillFromTdee(TdeeResult t) {
    _calCtrl.text = t.calorieTarget.toStringAsFixed(0);
    _proteinCtrl.text = t.proteinTarget.toStringAsFixed(0);
    _fatCtrl.text = t.fatTarget.toStringAsFixed(0);
    _carbCtrl.text = t.carbTarget.toStringAsFixed(0);
  }

  Future<void> _save() async {
    final tdee = _computeTdee();

    double cal;
    double protein;
    double fat;
    double carb;
    bool isAutoCalculated;

    // 自动模式（非手动 且 TDEE 可算）→ 用计算结果；否则取手动输入。
    if (!_manual && tdee != null) {
      cal = tdee.calorieTarget;
      protein = tdee.proteinTarget;
      fat = tdee.fatTarget;
      carb = tdee.carbTarget;
      isAutoCalculated = true;
    } else {
      cal = double.tryParse(_calCtrl.text.trim()) ?? -1;
      protein = double.tryParse(_proteinCtrl.text.trim()) ?? -1;
      fat = double.tryParse(_fatCtrl.text.trim()) ?? -1;
      carb = double.tryParse(_carbCtrl.text.trim()) ?? -1;
      isAutoCalculated = false;
    }
    if (cal <= 0 || protein < 0 || fat < 0 || carb < 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('请填写合法目标（热量 > 0，宏量 ≥ 0）')),
      );
      return;
    }

    setState(() => _saving = true);
    await ref.read(nutritionGoalProvider.notifier).upsertGoal(
          activityLevel: _activity.code,
          goalType: _goalType.code,
          calorieTarget: cal,
          proteinTarget: protein,
          fatTarget: fat,
          carbTarget: carb,
          isAutoCalculated: isAutoCalculated,
        );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('清除目标'),
            content: const Text('清除后今日进度卡片将回到「设置目标」状态。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清除')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    setState(() => _saving = true);
    await ref.read(nutritionGoalProvider.notifier).deleteGoal();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final tdee = _computeTdee();
    final hasExistingGoal = ref.watch(nutritionGoalProvider).valueOrNull != null;
    // 档案不完整时强制手动（无 TDEE 可用）。
    final manual = _manual || tdee == null;
    final missing = TdeeCalculator.missingFields(
      gender: Gender.fromCode(profile?.gender),
      heightCm: profile?.heightCm,
      weightKg: profile?.weightKg,
      birthDate: profile?.birthDate,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('每日营养目标', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),

            // 活动量
            const _FieldLabel('活动量'),
            _ChoiceChips<ActivityLevel>(
              values: ActivityLevel.values,
              selected: _activity,
              labelOf: (e) => e.label,
              onSelected: (e) => setState(() => _activity = e),
            ),
            const SizedBox(height: 14),

            // 健身目标
            const _FieldLabel('目标'),
            _ChoiceChips<GoalType>(
              values: GoalType.values,
              selected: _goalType,
              labelOf: (e) => e.label,
              onSelected: (e) => setState(() => _goalType = e),
            ),
            const SizedBox(height: 16),

            // TDEE 自动计算结果
            if (tdee != null)
              _TdeeSummary(tdee: tdee, onUse: () => setState(() { _manual = true; _fillFromTdee(tdee); }))
            else
              _IncompleteProfileHint(missing: missing),

            const SizedBox(height: 12),

            // 手动调整
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: manual,
              onChanged: tdee == null
                  ? null
                  : (v) => setState(() {
                        _manual = v;
                        if (v) {
                          final t = _computeTdee();
                          if (t != null && _calCtrl.text.isEmpty) _fillFromTdee(t);
                        }
                      }),
              title: const Text('手动调整目标', style: TextStyle(fontSize: 14)),
              subtitle: manual && tdee != null
                  ? const Text('已切换为手动值', style: TextStyle(fontSize: 11))
                  : null,
            ),
            if (manual) ...[
              _NumberField(controller: _calCtrl, label: '热量目标 (kcal)'),
              _NumberField(controller: _proteinCtrl, label: '蛋白质 (g)'),
              _NumberField(controller: _fatCtrl, label: '脂肪 (g)'),
              _NumberField(controller: _carbCtrl, label: '碳水 (g)'),
            ],

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7043),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(manual ? '保存目标' : '保存（按 TDEE 计算）'),
              ),
            ),
            if (hasExistingGoal) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _delete,
                  child: const Text('清除目标', style: TextStyle(color: Color(0xFFEF5350))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF616161))));
}

class _ChoiceChips<T> extends StatelessWidget {
  const _ChoiceChips({required this.values, required this.selected, required this.labelOf, required this.onSelected});

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(labelOf(v)),
            selected: v == selected,
            selectedColor: const Color(0xFFFF7043).withAlpha(30),
            labelStyle: TextStyle(
              fontSize: 13,
              color: v == selected ? const Color(0xFFFF7043) : const Color(0xFF616161),
              fontWeight: v == selected ? FontWeight.w600 : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (_) => onSelected(v),
          ),
      ],
    );
  }
}

class _TdeeSummary extends StatelessWidget {
  const _TdeeSummary({required this.tdee, required this.onUse});
  final TdeeResult tdee;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7043).withAlpha(14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFF7043)),
              const SizedBox(width: 6),
              const Text('按档案自动计算', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF7043))),
              const Spacer(),
              GestureDetector(
                onTap: onUse,
                child: const Text('填入手动', style: TextStyle(fontSize: 12, color: Color(0xFFFF7043), decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TdeeValue(label: '热量', value: tdee.calorieTarget.toStringAsFixed(0), unit: 'kcal'),
              _TdeeValue(label: '蛋白', value: tdee.proteinTarget.toStringAsFixed(0), unit: 'g'),
              _TdeeValue(label: '脂肪', value: tdee.fatTarget.toStringAsFixed(0), unit: 'g'),
              _TdeeValue(label: '碳水', value: tdee.carbTarget.toStringAsFixed(0), unit: 'g'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TdeeValue extends StatelessWidget {
  const _TdeeValue({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 2),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFFF7043)),
              children: [TextSpan(text: ' $unit', style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E), fontWeight: FontWeight.normal))],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncompleteProfileHint extends StatelessWidget {
  const _IncompleteProfileHint({required this.missing});
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFFFB300)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              missing.isEmpty
                  ? '无法计算 TDEE，请在下方手动填写目标。'
                  : '档案不完整（缺少：${missing.join('、')}），无法自动计算。\n可在下方手动填写目标。',
              style: const TextStyle(fontSize: 12, color: Color(0xFF616161), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
