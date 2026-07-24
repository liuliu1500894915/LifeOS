import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../providers/meal_providers.dart';
import 'add_food_category_sheet.dart';

const _accent = Color(0xFFFF7043);

/// 新增自定义食物 → `FoodLibrary(isCustom=true)`。
class AddCustomFoodSheet extends ConsumerStatefulWidget {
  const AddCustomFoodSheet({super.key});

  @override
  ConsumerState<AddCustomFoodSheet> createState() => _AddCustomFoodSheetState();
}

class _AddCustomFoodSheetState extends ConsumerState<AddCustomFoodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _servingCtrl = TextEditingController(text: '100');
  String? _categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    _servingCtrl.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cats = ref.read(foodCategoryProvider).valueOrNull ??
        const <FoodCategoryData>[];
    final catId = _categoryId ?? cats.firstOrNull?.categoryId;
    if (catId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择品类'), duration: Duration(seconds: 1)),
      );
      return;
    }
    setState(() => _saving = true);
    await ref.read(foodLibraryProvider.notifier).addCustomFood(
          foodName: _nameCtrl.text.trim(),
          categoryId: catId,
          caloriesPer100g: _parse(_calCtrl),
          proteinPer100g: _parse(_proteinCtrl),
          fatPer100g: _parse(_fatCtrl),
          carbsPer100g: _parse(_carbsCtrl),
          defaultServingGrams: _parse(_servingCtrl) > 0 ? _parse(_servingCtrl) : 100,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(foodCategoryProvider).valueOrNull ??
        const <FoodCategoryData>[];
    // 首次有品类时默认选中第一个（不在此 mutate 字段，避免 build 期间改状态）。
    final effectiveCategoryId = _categoryId ?? categories.firstOrNull?.categoryId;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 4,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('自定义食物', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _Label('食物名称'),
              TextFormField(
                controller: _nameCtrl,
                decoration: _fieldDeco('如：自制沙拉'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('品类', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final newId = await showAddFoodCategorySheet(context);
                      if (newId != null) setState(() => _categoryId = newId);
                    },
                    child: const Text('＋ 新建品类', style: TextStyle(fontSize: 13, color: _accent)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    GestureDetector(
                      onTap: () => setState(() => _categoryId = c.categoryId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: effectiveCategoryId == c.categoryId
                              ? _accent
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${c.categoryIcon} ${c.categoryName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: effectiveCategoryId == c.categoryId
                                ? Colors.white
                                : const Color(0xFF616161),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _Label('热量 (kcal / 100g)'),
              TextFormField(
                controller: _calCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: _fieldDeco('必填'),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) return '请输入有效数值';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _MacroField(label: '蛋白/100g', ctrl: _proteinCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _MacroField(label: '脂肪/100g', ctrl: _fatCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _MacroField(label: '碳水/100g', ctrl: _carbsCtrl)),
                ],
              ),
              const SizedBox(height: 14),
              _Label('默认份量 (g)'),
              TextFormField(
                controller: _servingCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: _fieldDeco('默认 100'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('保存', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String? hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF616161))));
}

class _MacroField extends StatelessWidget {
  const _MacroField({required this.label, required this.ctrl});
  final String label;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
