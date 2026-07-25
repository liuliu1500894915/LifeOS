import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/cream_glass.dart';
import '../../domain/nutrition.dart';
import '../providers/meal_providers.dart';
import '../widgets/energy_ledger_card.dart';
import '../widgets/food_picker_sheet.dart';
import '../widgets/health_exercise_section.dart';
import '../widgets/nutrition_progress_card.dart';

/// 健康模块首页壳 ——「能量账本」统一视图（P2-3 起，P3-3 合并摄入+消耗）。
///
/// 三段：① [EnergyLedgerCard]「吃 − 动 = 净」能量平衡 + 固定目标额度（消耗不加回）；
/// ② [NutritionOverview] 营养环与三宏量条（P2-4）；③ 按餐次的饮食记录；
/// ④ [HealthExerciseSection] 运动消耗记录与入口（顺带修复 `/home/exercise` 孤儿路由）。
/// 读取全部走 `.watch()` 流（meal/exercise/goal 派生），写库后各段自动刷新。
class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byType = ref.watch(mealLogsByTypeProvider);
    final nutritionByType = ref.watch(nutritionByTypeProvider);

    // 奶油玻璃：L1 光晕铺底，内容浮于其上。
    return Scaffold(
      backgroundColor: CreamGlass.ground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFoodPicker(context, ref),
        backgroundColor: CreamGlass.peach,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add),
        label: const Text('记录饮食',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(),
                  const SizedBox(height: 12),
                  const EnergyLedgerCard(),
                  const SizedBox(height: 12),
                  const NutritionOverview(),
                  const SizedBox(height: 18),
                  for (final type in MealType.values) ...[
                    _MealSection(
                      type: type,
                      logs: byType[type]!,
                      sectionNutrition: nutritionByType[type]!,
                      onAdd: () =>
                          showFoodPicker(context, ref, initialMeal: type),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  const HealthExerciseSection(),
                ],
              ),
            ),
          ),
        ],
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
    // L2 内容层：餐次分组用奶油实体卡。
    return CreamCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
            child: Row(
              children: [
                Text(type.label,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: CreamGlass.ink)),
                const SizedBox(width: 8),
                Text(
                  '${sectionNutrition.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: CreamGlass.peach,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: CreamGlass.peach.withAlpha(26),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('＋ 记录',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: CreamGlass.peach,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 13),
              child: Text('暂无记录',
                  style: TextStyle(fontSize: 11.5, color: CreamGlass.inkSoft)),
            )
          else
            ...[
              const Divider(height: 1, color: Color(0xFFEFF4EF)),
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
