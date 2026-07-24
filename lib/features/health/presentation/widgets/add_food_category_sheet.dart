import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/meal_providers.dart';

const _accent = Color(0xFFFF7043);

const _iconPresets = <String>[
  '🍚', '🥗', '🍎', '🍗', '🐟', '🥛', '🥜', '🥤', '🧂', '🍳', '🍰', '🥑',
];

/// 新建食物品类 → `FoodCategory(isBuiltIn=false)`。
///
/// 成功后 `pop(newCategoryId)`，供自定义食物表单直接选中；取消/关闭返回 null。
Future<String?> showAddFoodCategorySheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => const AddFoodCategorySheet(),
  );
}

class AddFoodCategorySheet extends ConsumerStatefulWidget {
  const AddFoodCategorySheet({super.key});

  @override
  ConsumerState<AddFoodCategorySheet> createState() =>
      _AddFoodCategorySheetState();
}

class _AddFoodCategorySheetState extends ConsumerState<AddFoodCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _icon = _iconPresets.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final id = await ref.read(foodCategoryProvider.notifier).addFoodCategory(
          categoryName: _nameCtrl.text.trim(),
          categoryIcon: _icon,
        );
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
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
              const Text('新建品类', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              const Text('品类名称', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: '如：轻食',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入品类名称' : null,
              ),
              const SizedBox(height: 16),
              const Text('图标', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _iconPresets.map((e) {
                  final selected = e == _icon;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = e),
                    child: Container(
                      width: 40, height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFFFF3EE) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: selected ? Border.all(color: _accent, width: 1.5) : null,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
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
                      : const Text('创建', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
