import '../../../../core/database/app_database.dart';

/// 运动（消耗）数据访问抽象层 —— presentation 只依赖此接口，不碰 `AppDatabase`
/// （执行计划 §1.4、§3.6，P3-2）。
///
/// 读取暴露 `watchXxx()`（Drift `.watch()` 流）与一次性 `getXxx()`；写一律
/// `Future`。历史消耗为**冻结快照**：`caloriesBurned` 由调用方按
/// `domain/met_table.dart` 算好后传入，入库后不再随体重/运动表当前值变化
/// （执行计划铁律 §1.2.4：历史不可变数据冻结计算结果）。
///
/// 体重（`UserProfile.weightKg`）是消耗计算的输入，故经此 Repository 暴露
/// 流式读取；本仓库**只读**档案、不写档案。
///
/// 注：命名为 [ExerciseRepository] 而非 `HealthRepository`，是为与同模块并行的
/// 摄入侧（P2-3 meal）**竖切**、避免共用一个仓库文件冲突（执行计划「分工竖切」）。
abstract interface class ExerciseRepository {
  // ── 运动（消耗）记录 ──
  Stream<List<ExerciseLogData>> watchExerciseLogs();
  Future<List<ExerciseLogData>> getExerciseLogs();

  /// 新增一条运动记录。[caloriesBurned] 为调用方算好的冻结快照。
  Future<void> addExerciseLog({
    required String exerciseName,
    required int durationMinutes,
    String? intensity, // LOW / MEDIUM / HIGH，可空
    required double caloriesBurned,
    DateTime? loggedAt,
  });

  Future<void> deleteExerciseLog(String logId);

  // ── 体重档案（消耗计算输入，只读）──
  Stream<UserProfileData?> watchUserProfile();
  Future<UserProfileData?> getUserProfile();
}
