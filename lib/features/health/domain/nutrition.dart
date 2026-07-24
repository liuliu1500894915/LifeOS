/// 饮食营养换算（纯 Dart，无 Flutter / Drift 依赖，可独立单测）。
///
/// 见开发执行计划 §1.1、§2 P2-3：记录饮食时按克数换算并**冻结**到 `MealLog`
/// 的 `snap*` 列（历史数据冻结快照，§1.2.4）。换算公式单一真相定义于此 ——
/// Repository 写入时调 [nutritionForGrams] 冻结，UI 实时预览也调同一函数，
/// 两边绝不各写一套。
///
/// 公式：`snap = per100 × grams ÷ 100`。
library;

/// 餐次。对应 `MealLog.mealType` 字符串（CHECK 约束）：
/// `BREAKFAST` / `LUNCH` / `DINNER` / `SNACK`。
enum MealType {
  breakfast('BREAKFAST', '早餐'),
  lunch('LUNCH', '午餐'),
  dinner('DINNER', '晚餐'),
  snack('SNACK', '加餐');

  const MealType(this.dbValue, this.label);

  /// 写入 `MealLog.mealType` 的字符串值。
  final String dbValue;

  /// UI 展示名。
  final String label;

  /// 由 `MealLog.mealType` 字符串还原枚举；未知值降级为 [snack]。
  static MealType fromDbValue(String value) => values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => MealType.snack,
      );
}

/// 每 100g 营养基准（来自 `FoodLibrary` 行）。
class NutritionPer100g {
  const NutritionPer100g({
    required this.calories,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
  });

  final double calories;
  final double protein;
  final double fat;
  final double carbs;
}

/// 冻结的营养快照（写入 `MealLog.snap*`）。
///
/// 不可变；提供 [operator +] 便于把多条记录汇总成当日合计。
class NutritionSnapshot {
  const NutritionSnapshot({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  static const zero =
      NutritionSnapshot(calories: 0, protein: 0, fat: 0, carbs: 0);

  NutritionSnapshot operator +(NutritionSnapshot other) => NutritionSnapshot(
        calories: calories + other.calories,
        protein: protein + other.protein,
        fat: fat + other.fat,
        carbs: carbs + other.carbs,
      );

  @override
  String toString() => 'NutritionSnapshot(${calories.toStringAsFixed(1)}kcal, '
      'P${protein.toStringAsFixed(1)}/F${fat.toStringAsFixed(1)}/'
      'C${carbs.toStringAsFixed(1)})';
}

/// 按克数换算并冻结营养快照：`snap = per100 × grams ÷ 100`。
///
/// [grams] 应为非负值（UI 会钳制 ≥ 0；此处不做守卫，保持纯函数语义）。
NutritionSnapshot nutritionForGrams({
  required NutritionPer100g per100,
  required double grams,
}) {
  final factor = grams / 100;
  return NutritionSnapshot(
    calories: per100.calories * factor,
    protein: per100.protein * factor,
    fat: per100.fat * factor,
    carbs: per100.carbs * factor,
  );
}
