/// 每日营养目标与当日进度对比（domain 侧，纯 Dart，无 Flutter / Drift 依赖）。
///
/// 见开发执行计划 P2-4：当日摄入（[NutritionSnapshot]，来自 `MealLog` 的冻结
/// 快照合计）对比每日目标（[NutritionTargets]，来自 `NutritionGoal` 表行），
/// 派生「热量环 + 三宏量条」的 当前 / 目标 / 剩余 / 超标 视图。计算逻辑集中在
/// 纯函数 [computeNutritionProgress]，UI 与测试共用同一套（§1.1 计算放 domain）。
library;

import 'nutrition.dart';

/// 每日营养目标（domain 镜像，对应 `NutritionGoal` 表行的四项目标）。
///
/// 不可变；可由 `tdee_calculator.dart` 的 `TdeeResult` 派生，也可来自用户手填。
class NutritionTargets {
  const NutritionTargets({
    required this.calorieTarget,
    required this.proteinTarget,
    required this.fatTarget,
    required this.carbTarget,
  });

  final double calorieTarget;
  final double proteinTarget;
  final double fatTarget;
  final double carbTarget;

  static const zero = NutritionTargets(
    calorieTarget: 0,
    proteinTarget: 0,
    fatTarget: 0,
    carbTarget: 0,
  );
}

/// 单项进度（热量环或某条宏量）。[current]=当日已摄入，[target]=目标值。
///
/// 派生量均为纯计算，UI 与测试据此渲染 / 断言，不再各写一套。
class MacroProgress {
  const MacroProgress({required this.current, required this.target});

  final double current;
  final double target;

  /// 剩余 = 目标 − 已摄入；负值表示超标。
  double get remaining => target - current;

  /// 是否已超标（严格大于；正好相等不算超标）。
  bool get exceeded => current > target;

  /// 进度比例（可 > 1，用于显示「超标 N%」）。目标 ≤ 0 时记为 0，不产生 ∞/NaN。
  double get ratio => target <= 0 ? 0 : current / target;

  /// 进度条填充比例，钳到 [0, 1]（超标时仍画满条，超标量用文字另标）。
  double get barFill => ratio.clamp(0.0, 1.0);
}

/// 当日营养进度：热量（环）+ 三宏量（条）。
class NutritionProgress {
  const NutritionProgress({
    required this.calorie,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final MacroProgress calorie;
  final MacroProgress protein;
  final MacroProgress fat;
  final MacroProgress carbs;
}

/// 由「目标 + 当日摄入」派生当日进度（纯函数）。
///
/// 目标 [target] 应来自 `NutritionGoal` 表行；[intake] 来自当日 `MealLog.snap*`
/// 合计。二者任一变化重算即可，UI 无需手动刷新（读取走 `.watch()` 流）。
NutritionProgress computeNutritionProgress(
  NutritionTargets target,
  NutritionSnapshot intake,
) {
  return NutritionProgress(
    calorie: MacroProgress(current: intake.calories, target: target.calorieTarget),
    protein: MacroProgress(current: intake.protein, target: target.proteinTarget),
    fat: MacroProgress(current: intake.fat, target: target.fatTarget),
    carbs: MacroProgress(current: intake.carbs, target: target.carbTarget),
  );
}
