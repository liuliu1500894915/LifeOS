import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/nutrition.dart';
import '../providers/meal_providers.dart';
import 'add_custom_food_sheet.dart';
import 'meal_log_sheet.dart';

const _accent = Color(0xFFFF7043);

/// 打开食物选择器；选中食物后接续打开称重/餐次表单（[MealLogSheet]）。
///
/// [initialMeal] 由餐次区「+ 记录」带入，预选该餐次。
Future<void> showFoodPicker(
  BuildContext context,
  WidgetRef ref, {
  MealType? initialMeal,
}) async {
  final food = await showModalBottomSheet<FoodLibraryData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => const FoodPickerSheet(),
  );
  if (food != null && context.mounted) {
    await showMealLogSheet(context, food, initialMeal: initialMeal);
  }
}

class FoodPickerSheet extends ConsumerStatefulWidget {
  const FoodPickerSheet({super.key});

  @override
  ConsumerState<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends ConsumerState<FoodPickerSheet> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl =
        TextEditingController(text: ref.read(foodSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(foodCategoryProvider).valueOrNull ??
        const <FoodCategoryData>[];
    final selectedCategory = ref.watch(selectedFoodCategoryProvider);
    final foods = ref.watch(filteredFoodsProvider);
    // 入口前重置筛选，避免残留上次选择。
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: height - bottomInset,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('选择食物', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      showDragHandle: true,
                      builder: (_) => const AddCustomFoodSheet(),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18, color: _accent),
                  label: const Text('自定义', style: TextStyle(color: _accent)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ref.read(foodSearchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: '搜索食物名称',
                hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF9E9E9E)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _CategoryChip(
                  label: '全部',
                  selected: selectedCategory == null,
                  onTap: () => ref
                      .read(selectedFoodCategoryProvider.notifier)
                      .state = null,
                ),
                for (final c in categories)
                  _CategoryChip(
                    label: '${c.categoryIcon} ${c.categoryName}',
                    selected: selectedCategory == c.categoryId,
                    onTap: () => ref
                        .read(selectedFoodCategoryProvider.notifier)
                        .state = c.categoryId,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: foods.isEmpty
                ? const Center(
                    child: Text('没有匹配的食物，试试「自定义」', style: TextStyle(color: Color(0xFF9E9E9E))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: foods.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF2F2F2)),
                    itemBuilder: (context, i) {
                      final f = foods[i];
                      return ListTile(
                        title: Text(f.foodName, style: const TextStyle(fontSize: 15)),
                        subtitle: Text(
                          '${f.caloriesPer100g.toStringAsFixed(0)} kcal/100g · 默认 ${f.defaultServingGrams.toStringAsFixed(0)}g'
                          '${f.isCustom ? ' · 自定义' : ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
                        onTap: () => Navigator.of(context).pop(f),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _accent : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF616161),
            ),
          ),
        ),
      ),
    );
  }
}
