import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/system_bootstrap.dart';
import 'exercise_repository.dart';

const _uuid = Uuid();

/// [ExerciseRepository] 的 Drift 实现：运动记录相关 SQL 集中于此。
///
/// 读用 `.watch()`/`.get()`，写用 `Future`。系统用户 `user-001` 由
/// [SystemBootstrap] 启动时一次性确保；此处写直接用 [systemUserId]。
class ExerciseRepositoryDrift implements ExerciseRepository {
  ExerciseRepositoryDrift(this._db);

  final AppDatabase _db;

  // ── 运动（消耗）记录 ──

  @override
  Stream<List<ExerciseLogData>> watchExerciseLogs() =>
      (_db.select(_db.exerciseLog)
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .watch();

  @override
  Future<List<ExerciseLogData>> getExerciseLogs() =>
      (_db.select(_db.exerciseLog)
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .get();

  @override
  Future<void> addExerciseLog({
    required String exerciseName,
    required int durationMinutes,
    String? intensity,
    required double caloriesBurned,
    DateTime? loggedAt,
  }) async {
    await _db.into(_db.exerciseLog).insert(
          ExerciseLogCompanion.insert(
            logId: _uuid.v4(),
            userId: systemUserId,
            exerciseName: exerciseName,
            durationMinutes: durationMinutes,
            intensity: Value(intensity),
            caloriesBurned: caloriesBurned,
            loggedAt: loggedAt ?? DateTime.now(),
          ),
        );
  }

  @override
  Future<void> deleteExerciseLog(String logId) async {
    await (_db.delete(_db.exerciseLog)..where((t) => t.logId.equals(logId)))
        .go();
  }

  // ── 体重档案（消耗计算输入，只读）──

  @override
  Stream<UserProfileData?> watchUserProfile() =>
      (_db.select(_db.userProfile)
            ..where((t) => t.userId.equals(systemUserId)))
          .watchSingleOrNull();

  @override
  Future<UserProfileData?> getUserProfile() =>
      (_db.select(_db.userProfile)
            ..where((t) => t.userId.equals(systemUserId)))
          .getSingleOrNull();
}

/// Repository 的 Riverpod 入口；presentation 的 Provider 依赖此接口。
final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepositoryDrift(ref.read(databaseProvider));
});
