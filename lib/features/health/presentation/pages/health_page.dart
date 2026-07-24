import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/nutrition.dart';
import '../providers/meal_providers.dart';
import '../widgets/food_picker_sheet.dart';
import '../widgets/nutrition_progress_card.dart';

/// 健康模块首页壳（P2-3）。
///
/// 目前承载「饮食摄入」区；P3-2 将在其后追加「运动消耗」区（同 health 模块，
/// 仅扩 exercise_* 文件 + 往本页加一段，互不冲突）。读取全部走 `.watch()` 流
/// （[mealLogProvider] 派生），写库后列表自动刷新。
class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byType = ref.watch(mealLogsByTypeProvider);
    final nutritionByType = ref.watch(nutritionByTypeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFoodPicker(context, ref),
        backgroundColor: const Color(0xFFFF7043),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('记录饮食'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              const SizedBox(height: 12),
              const NutritionOverview(),
              const SizedBox(height: 16),
              for (final type in MealType.values) ...[
                _MealSection(
                  type: type,
                  logs: byType[type]!,
                  sectionNutrition: nutritionByType[type]!,
                  onAdd: () => showFoodPicker(context, ref, initialMeal: type),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.restaurant_menu, size: 22, color: Color(0xFFFF7043)),
        SizedBox(width: 8),
        Text('健康饮食', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MealSection extends ConsumerWidget {
  const _MealSection({
    required this.type,
    required this.logs,
    required this.sectionNutrition,
    required this.onAdd,
  });

  final MealType type;
  final List<MealLogData> logs;
  final NutritionSnapshot sectionNutrition;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(type.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(
                  '${sectionNutrition.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFFF7043), fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7043).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('+ 记录', style: TextStyle(fontSize: 12, color: Color(0xFFFF7043), fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('暂无记录', style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
            )
          else
            ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              for (final log in logs) _MealLogTile(log: log),
            ],
        ],
      ),
    );
  }
}

class _MealLogTile extends ConsumerWidget {
  const _MealLogTile({required this.log});
  final MealLogData log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodName = ref.watch(foodByIdProvider)[log.foodId]?.foodName ?? '食物';
    return Dismissible(
      key: ValueKey(log.logId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除记录'),
                content: const Text('确定删除这条饮食记录？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => ref.read(mealLogProvider.notifier).deleteMealLog(log.logId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(foodName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    '${log.grams.toStringAsFixed(0)}g · '
                    'P${log.snapProtein.toStringAsFixed(1)}/'
                    'F${log.snapFat.toStringAsFixed(1)}/'
                    'C${log.snapCarbs.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ),
            Text(
              '${log.snapCalories.toStringAsFixed(0)} kcal',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFF7043)),
            ),
          ],
        ),
      ),
    );
  }
}
