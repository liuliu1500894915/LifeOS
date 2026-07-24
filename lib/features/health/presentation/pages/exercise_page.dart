import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/met_table.dart';
import '../providers/exercise_providers.dart';
import '../widgets/exercise_log_drawer.dart';

const _exerciseColor = Color(0xFF66BB6A);

/// 运动记录页（P3-2）。读取走 Repository 的 `.watch()` 流（§1.4）：写库后 UI
/// 自动刷新，无 `_fetchAll`/`invalidate`。列表展示的是**冻结**的 `caloriesBurned`
/// ——不随后续档案/运动表变化（§1.2.4）。
class ExercisePage extends ConsumerWidget {
  const ExercisePage({super.key});

  void _openDrawer(BuildContext context) {
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
    final logsAsync = ref.watch(exerciseLogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('运动记录')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDrawer(context),
        backgroundColor: _exerciseColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSummary(context, ref)),
          logsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('加载失败: $e')),
            ),
            data: (all) {
              final today = ref.watch(todayExerciseLogsProvider);
              if (today.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmpty(context),
                );
              }
              return SliverList.separated(
                itemCount: today.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                itemBuilder: (context, i) => _buildLogTile(context, ref, today[i]),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, WidgetRef ref) {
    final todayCalories = ref.watch(todayCaloriesBurnedProvider);
    final todayMinutes = ref.watch(todayExerciseMinutesProvider);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_exerciseColor.withAlpha(28), _exerciseColor.withAlpha(6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: _exerciseColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('今日消耗',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                Text('${todayCalories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _exerciseColor,
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('运动时长',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
              Text('$todayMinutes min',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF616161),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_run, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('今日还没有运动记录',
              style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 4),
          const Text('点右下角 + 记一笔',
              style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
        ],
      ),
    );
  }

  Widget _buildLogTile(
    BuildContext context,
    WidgetRef ref,
    ExerciseLogData log,
  ) {
    final intensity = ExerciseIntensityX.fromCode(log.intensity);
    final time = TimeOfDay.fromDateTime(log.loggedAt);
    return Dismissible(
      key: ValueKey(log.logId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除记录'),
                content: const Text('确定删除这条运动记录吗？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('删除')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        ref.read(exerciseLogProvider.notifier).deleteExerciseLog(log.logId);
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _exerciseColor.withAlpha(20),
          foregroundColor: _exerciseColor,
          child: const Icon(Icons.fitness_center, size: 20),
        ),
        title: Text(log.exerciseName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${intensity.label}强度 · ${log.durationMinutes}min · '
          '${time.format(context)}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
        ),
        trailing: Text(
          '${log.caloriesBurned.toStringAsFixed(0)} kcal',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _exerciseColor,
          ),
        ),
      ),
    );
  }
}
