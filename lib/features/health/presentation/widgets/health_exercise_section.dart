import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_router.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/met_table.dart';
import '../../presentation/providers/exercise_providers.dart';
import 'exercise_log_drawer.dart';

const _exerciseColor = Color(0xFF66BB6A);

/// 健康页的「运动消耗」区（P3-3）：把摄入与消耗整合进同一健康视图。
///
/// 三件事：① 展示当日消耗与时长；② 复用 [ExerciseLogDrawer] 记录运动（写
/// `ExerciseLog`，冻结消耗）；③ 提供「全部运动记录」入口跳转 [ExercisePage]
/// —— 修复 P3-2 落地后 `/home/exercise` 成为孤儿路由、用户点不进去的集成缺口。
///
/// 读取全走 `.watch()` 流（[todayExerciseLogsProvider] 等派生流）：记一笔运动后
/// 本区与上方能量账本自动刷新，无手动 invalidate。
class HealthExerciseSection extends ConsumerWidget {
  const HealthExerciseSection({super.key});

  void _openRecorder(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ExerciseLogDrawer(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(todayExerciseLogsProvider);
    final burned = ref.watch(todayCaloriesBurnedProvider);
    final minutes = ref.watch(todayExerciseMinutesProvider);

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
                const Icon(Icons.fitness_center, size: 18, color: _exerciseColor),
                const SizedBox(width: 6),
                const Text('运动消耗', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${burned.toStringAsFixed(0)} kcal · $minutes min',
                  style: const TextStyle(fontSize: 13, color: _exerciseColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('今日还没有运动记录',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            )
          else ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            for (final log in logs) _ExerciseTile(log: log),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openRecorder(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _exerciseColor.withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 16, color: _exerciseColor),
                          SizedBox(width: 4),
                          Text('记录运动', style: TextStyle(fontSize: 13, color: _exerciseColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 通往运动记录页（修复孤儿路由 /home/exercise）。
                GestureDetector(
                  onTap: () => context.push(AppRoutes.exercise),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Text('全部记录', style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
                        Icon(Icons.chevron_right, size: 16, color: Color(0xFF9E9E9E)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.log});
  final ExerciseLogData log;

  @override
  Widget build(BuildContext context) {
    final intensity = ExerciseIntensityX.fromCode(log.intensity);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.exerciseName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${intensity.label}强度 · ${log.durationMinutes}min',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          Text(
            '${log.caloriesBurned.toStringAsFixed(0)} kcal',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _exerciseColor),
          ),
        ],
      ),
    );
  }
}
