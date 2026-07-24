import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/nutrition.dart';
import '../providers/meal_providers.dart';

const _accent = Color(0xFFFF7043);

/// 打开称重 / 选餐次表单，确认后写 `MealLog`（冻结 snap）。
Future<void> showMealLogSheet(
  BuildContext context,
  FoodLibraryData food, {
  MealType? initialMeal,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => MealLogSheet(food: food, initialMeal: initialMeal),
  );
}

class MealLogSheet extends ConsumerStatefulWidget {
  const MealLogSheet({super.key, required this.food, this.initialMeal});

  final FoodLibraryData food;
  final MealType? initialMeal;

  @override
  ConsumerState<MealLogSheet> createState() => _MealLogSheetState();
}

class _MealLogSheetState extends ConsumerState<MealLogSheet> {
  late final TextEditingController _gramsCtrl;
  late MealType _meal;

  @override
  void initState() {
    super.initState();
    _gramsCtrl = TextEditingController(
      text: widget.food.defaultServingGrams.toStringAsFixed(0),
    );
    _meal = widget.initialMeal ?? _guessMealByTime();
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    super.dispose();
  }

  double get _grams {
    final v = double.tryParse(_gramsCtrl.text) ?? 0;
    return v < 0 ? 0 : v;
  }

  NutritionSnapshot get _preview => nutritionForGrams(
        per100: NutritionPer100g(
          calories: widget.food.caloriesPer100g,
          protein: widget.food.proteinPer100g,
          fat: widget.food.fatPer100g,
          carbs: widget.food.carbsPer100g,
        ),
        grams: _grams,
      );

  void _bump(double delta) {
    final next = (_grams + delta).clamp(0, 99999);
    _gramsCtrl.text = next.toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _confirm() async {
    final grams = _grams;
    if (grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入大于 0 的克数'), duration: Duration(seconds: 1)),
      );
      return;
    }
    await ref.read(mealLogProvider.notifier).addMealLog(
          foodId: widget.food.foodId,
          mealType: _meal,
          grams: grams,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 4,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.food.foodName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.food.caloriesPer100g.toStringAsFixed(0)} kcal/100g',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${preview.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _accent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('克数', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => _bump(-10),
                  icon: const Icon(Icons.remove_circle_outline, color: _accent),
                ),
                Expanded(
                  child: TextField(
                    controller: _gramsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      suffixText: 'g',
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  onPressed: () => _bump(10),
                  icon: const Icon(Icons.add_circle_outline, color: _accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _PresetChip(
                  label: '默认 ${widget.food.defaultServingGrams.toStringAsFixed(0)}g',
                  onTap: () {
                    _gramsCtrl.text = widget.food.defaultServingGrams.toStringAsFixed(0);
                    setState(() {});
                  },
                ),
                _PresetChip(label: '100g', onTap: () { _gramsCtrl.text = '100'; setState(() {}); }),
                _PresetChip(label: '150g', onTap: () { _gramsCtrl.text = '150'; setState(() {}); }),
                _PresetChip(label: '200g', onTap: () { _gramsCtrl.text = '200'; setState(() {}); }),
              ],
            ),
            const SizedBox(height: 16),
            const Text('餐次', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final t in MealType.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _meal = t),
                      child: Container(
                        margin: EdgeInsets.only(right: t == MealType.snack ? 0 : 6),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _meal == t ? _accent : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _meal == t ? Colors.white : const Color(0xFF616161),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // 实时预览：与 repo 冻结同公式（nutritionForGrams），保证所见即所存。
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MacroPreview(label: '蛋白', value: preview.protein, color: const Color(0xFF42A5F5)),
                  _MacroPreview(label: '脂肪', value: preview.fat, color: const Color(0xFFFFB300)),
                  _MacroPreview(label: '碳水', value: preview.carbs, color: const Color(0xFF66BB6A)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('确认记录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF616161))),
      ),
    );
  }
}

class _MacroPreview extends StatelessWidget {
  const _MacroPreview({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color.withAlpha(180))),
        const SizedBox(height: 2),
        Text('${value.toStringAsFixed(1)}g',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

/// 按当前时间猜默认餐次（早 10 点前 / 午 14 点前 / 加餐 18 点前 / 晚）。
MealType _guessMealByTime() {
  final h = DateTime.now().hour;
  if (h < 10) return MealType.breakfast;
  if (h < 14) return MealType.lunch;
  if (h < 18) return MealType.snack;
  return MealType.dinner;
}
