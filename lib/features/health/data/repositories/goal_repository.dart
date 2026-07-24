import '../../../../core/database/app_database.dart';

/// 每日营养目标数据访问抽象层（P2-4）—— presentation 只依赖此接口，不碰
/// `AppDatabase`（执行计划 §1.4、§3.6）。
///
/// 目标每人一条（PK=userId，系统用户 `user-001`）。读暴露 `watchGoal()`（Drift
/// `.watch()` 流，未设目标时发射 null）与一次性 `getGoal()`；写用 [upsertGoal]
/// （`insertOnConflictUpdate`，按 userId 幂等覆盖同一用户行）。
///
/// **不改 schema**：`NutritionGoal` 表自 v3（P2-1）已建，本任务只读写它。
abstract interface class NutritionGoalRepository {
  /// 当前系统用户的每日目标；未设置时流发射 null。写库后流自动重发新值。
  Stream<NutritionGoalData?> watchGoal();

  Future<NutritionGoalData?> getGoal();

  /// 写入或覆盖每日目标（按 userId 幂等 upsert）。
  ///
  /// [activityLevel]/[goalType] 为 `NutritionGoal` 表的字符串枚举值（见
  /// `domain/tdee_calculator.dart` 的 `ActivityLevel.code` / `GoalType.code`）。
  /// [isAutoCalculated]：true=由 TDEE 自动算出；false=用户手填 —— UI 据此区分
  /// 「重新按 TDEE 计算」与「手动修改」入口。
  Future<void> upsertGoal({
    required String activityLevel,
    required String goalType,
    required double calorieTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbTarget,
    required bool isAutoCalculated,
  });

  /// 清除当前用户的目标（未设时无副作用）。
  Future<void> deleteGoal();
}
