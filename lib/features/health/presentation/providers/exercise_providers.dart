import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../data/repositories/exercise_repository_drift.dart';

// ── Stream-backed notifiers ──
//
// presentation 层状态编排 —— 只调 [ExerciseRepository] 接口，无 `db.`/`Companion`/
// 裸查询（§1.4）。读取走 Repository 的 `.watch()` 流（Drift StreamQueries）：写库后
// 流自动重发新值，UI 自动刷新。因此命令（add/delete）只转发给 Repository，
// **不**触碰 state、**不**手动 `_fetchAll`、**不**靠 `ref.invalidate` 维持同步。
//
// 系统用户前置：`build()` 与每个写方法首行 `await ref.read(systemBootstrapProvider.future)`
// （与 finance_providers.dart 同范式：StreamNotifier 的 `async*` build 惰性执行，
// 这层 await 把 systemBootstrap 排进队列，避免随后的写撞 FK）。
class ExerciseLogNotifier extends StreamNotifier<List<ExerciseLogData>> {
  @override
  Stream<List<ExerciseLogData>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(exerciseRepositoryProvider).watchExerciseLogs();
  }

  /// 新增运动记录。[caloriesBurned] 为调用方按 `domain/met_table.dart` 算好（或
  /// 手动覆盖）的冻结快照，原样入库、不再随档案变化。
  Future<void> addExerciseLog({
    required String exerciseName,
    required int durationMinutes,
    String? intensity,
    required double caloriesBurned,
    DateTime? loggedAt,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(exerciseRepositoryProvider).addExerciseLog(
          exerciseName: exerciseName,
          durationMinutes: durationMinutes,
          intensity: intensity,
          caloriesBurned: caloriesBurned,
          loggedAt: loggedAt,
        );
  }

  Future<void> deleteExerciseLog(String logId) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(exerciseRepositoryProvider).deleteExerciseLog(logId);
  }
}

class UserProfileNotifier extends StreamNotifier<UserProfileData?> {
  @override
  Stream<UserProfileData?> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(exerciseRepositoryProvider).watchUserProfile();
  }
}

// ── Providers ──

final exerciseLogProvider =
    StreamNotifierProvider<ExerciseLogNotifier, List<ExerciseLogData>>(
  ExerciseLogNotifier.new,
);

final userProfileProvider =
    StreamNotifierProvider<UserProfileNotifier, UserProfileData?>(
  UserProfileNotifier.new,
);

/// 当前用户体重（kg）；档案缺体重时为 null（消耗计算据此降级并提示补全）。
final currentWeightKgProvider = Provider<double?>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  final w = profile?.weightKg;
  return (w != null && w > 0) ? w : null;
});

// ── Derived providers（当日聚合）──

DateTime _todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 当日运动记录（按时间倒序）。
final todayExerciseLogsProvider = Provider<List<ExerciseLogData>>((ref) {
  final asyncLogs = ref.watch(exerciseLogProvider);
  final start = _todayStart();
  final end = start.add(const Duration(days: 1));
  return asyncLogs.whenOrNull(data: (logs) {
        return logs
            .where((l) =>
                !l.loggedAt.isBefore(start) && l.loggedAt.isBefore(end))
            .toList();
      }) ??
      <ExerciseLogData>[];
});

/// 当日累计消耗 kcal（冻结值之和）。
final todayCaloriesBurnedProvider = Provider<double>((ref) {
  final logs = ref.watch(todayExerciseLogsProvider);
  return logs.fold<double>(0, (s, l) => s + l.caloriesBurned);
});

/// 当日累计运动时长（分钟）。
final todayExerciseMinutesProvider = Provider<int>((ref) {
  final logs = ref.watch(todayExerciseLogsProvider);
  return logs.fold<int>(0, (s, l) => s + l.durationMinutes);
});
