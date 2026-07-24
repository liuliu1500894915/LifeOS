/// TDEE（每日总能量消耗）与每日营养目标计算。
///
/// 纯 Dart 实现，无 Flutter / Drift 依赖，可独立单测（见开发执行计划 §1.1、§3.4）。
///
/// 算法依据 Mifflin-St Jeor 公式：
/// - BMR 男：  10×kg + 6.25×cm − 5×age + 5
/// - BMR 女：  10×kg + 6.25×cm − 5×age − 161
/// - BMR OTHER：取男女均值（即常数项 −78）
/// - TDEE = BMR × 活动系数
/// - 热量目标 = TDEE × 目标系数（减脂 0.8 / 维持 1.0 / 增肌 1.1）
/// - 蛋白质 = 体重kg × 1.6
/// - 脂肪   = 热量目标 × 25% ÷ 9
/// - 碳水   = (热量目标 − 蛋白×4 − 脂肪×9) ÷ 4（钳制 ≥ 0）
///
/// 任一生理必需字段（[gender]/[heightCm]/[weightKg]/[birthDate]）缺失时
/// [calculate] 返回 null，调用方应引导用户补全档案（可用 [missingFields]
/// 取提示文案）。性别 / 活动量 / 目标枚举与 DB 字符串的映射见各枚举注释。
library;

/// 性别。对应 `UserProfile.gender` 字符串：`MALE` / `FEMALE` / `OTHER`。
enum Gender { male, female, other }

/// 活动量等级。对应 `NutritionGoal.activityLevel` 字符串：
/// `SEDENTARY` / `LIGHT` / `MODERATE` / `ACTIVE` / `VERY_ACTIVE`。
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  /// 对应的 TDEE 活动系数。
  double get factor => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };
}

/// 健身目标。对应 `NutritionGoal.goalType` 字符串：
/// `CUT`（减脂）/ `MAINTAIN`（维持）/ `BULK`（增肌）。
enum GoalType {
  cut,
  maintain,
  bulk;

  /// 对应的热量目标系数（作用于 TDEE）。
  double get factor => switch (this) {
        GoalType.cut => 0.8,
        GoalType.maintain => 1.0,
        GoalType.bulk => 1.1,
      };
}

/// TDEE 计算结果（每日目标）。不可变。
class TdeeResult {
  const TdeeResult({
    required this.bmr,
    required this.tdee,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.fatTarget,
    required this.carbTarget,
  });

  /// 基础代谢率（kcal/天）。
  final double bmr;

  /// 每日总能量消耗（kcal/天）= BMR × 活动系数。
  final double tdee;

  /// 热量目标（kcal/天）= TDEE × 目标系数。
  final double calorieTarget;

  /// 蛋白质目标（克/天）。
  final double proteinTarget;

  /// 脂肪目标（克/天）。
  final double fatTarget;

  /// 碳水目标（克/天）。
  final double carbTarget;
}

class TdeeCalculator {
  TdeeCalculator._();

  /// 蛋白质系数（克 / 公斤体重）。
  static const double proteinPerKg = 1.6;

  /// 脂肪占热量目标的比例。
  static const double fatCalorieRatio = 0.25;

  /// 热量 / 蛋白 / 脂肪 / 碳水 每克对应的 kcal。
  static const double kcalPerGramProtein = 4;
  static const double kcalPerGramFat = 9;
  static const double kcalPerGramCarb = 4;

  /// 计算每日能量与三大营养素目标。
  ///
  /// [referenceDate] 为计算年龄的基准日，默认当前时间；测试时可注入固定值。
  /// 任一生理必需字段（[gender]/[heightCm]/[weightKg]/[birthDate]）为 null
  /// 时返回 null —— 调用方应引导补全档案。
  static TdeeResult? calculate({
    Gender? gender,
    double? heightCm,
    double? weightKg,
    DateTime? birthDate,
    required ActivityLevel activityLevel,
    required GoalType goalType,
    DateTime? referenceDate,
  }) {
    if (gender == null ||
        heightCm == null ||
        weightKg == null ||
        birthDate == null) {
      return null;
    }

    final age =
        ageInYears(birthDate, referenceDate ?? DateTime.now());

    // 公共项：10×kg + 6.25×cm − 5×age，性别差异只体现在常数项。
    final bmrBase = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final bmr = switch (gender) {
      Gender.male => bmrBase + 5,
      Gender.female => bmrBase - 161,
      Gender.other => bmrBase + (5 - 161) / 2, // 男女均值，常数项 −78
    };

    final tdee = bmr * activityLevel.factor;
    final calorieTarget = tdee * goalType.factor;

    final protein = weightKg * proteinPerKg;
    final fat = calorieTarget * fatCalorieRatio / kcalPerGramFat;
    // 碳水吃剩余热量；极端组合（极低热量目标 + 极高体重）下可能为负，钳制 ≥ 0。
    final carb = (calorieTarget -
            protein * kcalPerGramProtein -
            fat * kcalPerGramFat) /
        kcalPerGramCarb;

    return TdeeResult(
      bmr: bmr,
      tdee: tdee,
      calorieTarget: calorieTarget,
      proteinTarget: protein,
      fatTarget: fat,
      carbTarget: carb < 0 ? 0.0 : carb,
    );
  }

  /// 返回缺失的必需档案字段名（中文），供 UI 生成「请补全：…」提示。
  /// 无缺失返回空列表。
  static List<String> missingFields({
    Gender? gender,
    double? heightCm,
    double? weightKg,
    DateTime? birthDate,
  }) {
    return [
      if (gender == null) '性别',
      if (heightCm == null) '身高',
      if (weightKg == null) '体重',
      if (birthDate == null) '出生日期',
    ];
  }

  /// 整岁年龄：按本年生日是否已过折算。
  static int ageInYears(DateTime birth, DateTime today) {
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age -= 1;
    }
    return age;
  }
}
