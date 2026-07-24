/// 能量账本（domain，纯 Dart，无 Flutter / Drift 依赖，可独立单测）。
///
/// 见开发执行计划 P3-3：合并当日「摄入」（`MealLog.snapCalories` 合计，吃）与
/// 「消耗」（`ExerciseLog.caloriesBurned` 合计，动），派生「吃 − 动 = 净」的能量
/// 平衡，并对比**固定**的每日热量目标。计算逻辑集中在纯函数
/// [computeEnergyLedger]，UI 与测试共用同一套（§1.1 计算放 domain）。
///
/// ⚠️ 关键决策（蓝图 P3-3「消耗不加回额度」）：运动消耗会降低 [netEnergy]（能量
/// 平衡向赤字移动），但**绝不抬高饮食目标**。饮食额度 [budget] 仅由
/// 「目标 − 摄入」决定（复用 [MacroProgress]，`current`=摄入、`target`=目标），
/// 与 [burnedCalories] 完全无关 —— 避免「运动换食量」的误导（与多数健身 App 的
/// 「消耗回填额度」做法刻意相反）。
library;

import 'nutrition_goal.dart';

/// 当日能量账本快照（不可变）。
class EnergyLedger {
  const EnergyLedger({
    required this.intakeCalories,
    required this.burnedCalories,
    required this.budget,
  });

  /// 吃：当日摄入 kcal（`MealLog.snapCalories` 冻结合计）。
  final double intakeCalories;

  /// 动：当日消耗 kcal（`ExerciseLog.caloriesBurned` 冻结合计）。
  final double burnedCalories;

  /// 饮食额度（摄入 vs **固定**目标）。未设目标时为 null —— UI 据此引导设置目标。
  ///
  /// ⚠️ 仅由「摄入 + 目标」派生，**不**含 [burnedCalories]：消耗不加回额度。
  final MacroProgress? budget;

  /// 净能量 = 吃 − 动。可正（净盈余）可负（净赤字）。
  double get netEnergy => intakeCalories - burnedCalories;

  /// 是否已设每日热量目标。
  bool get hasTarget => budget != null;
}

/// 由「摄入 + 消耗 + 目标」派生能量账本（纯函数）。
///
/// [intakeCalories] 来自当日 `MealLog` 合计；[burnedCalories] 来自当日
/// `ExerciseLog` 合计；[calorieTarget] 来自 `NutritionGoal` 表行（未设传 null）。
/// 三者任一变化重算即可，UI 无需手动刷新（读取走 `.watch()` 流）。
EnergyLedger computeEnergyLedger({
  required double intakeCalories,
  required double burnedCalories,
  double? calorieTarget,
}) {
  final MacroProgress? budget =
      (calorieTarget != null && calorieTarget > 0)
          ? MacroProgress(current: intakeCalories, target: calorieTarget)
          : null;
  return EnergyLedger(
    intakeCalories: intakeCalories,
    burnedCalories: burnedCalories,
    budget: budget,
  );
}
