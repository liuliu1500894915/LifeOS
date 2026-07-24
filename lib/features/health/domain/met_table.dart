/// MET（代谢当量）常量表 + 运动消耗计算（P3-1 / P3-2）。
///
/// 纯 Dart 实现，无 Flutter / Drift 依赖，可独立单测（见开发执行计划 §1.1、§3.1）。
/// MET 值取自《身体活动纲要（Compendium of Physical Activities）》成人均值，
/// 按「运动名 × 主观强度」查表；同一运动低/中/高强度对应不同 MET。
///
/// 消耗公式（执行计划 P3-2）：
///   kcal = MET × 体重kg × 时长h = MET × 体重kg × (时长min ÷ 60)
/// 体重取 `UserProfile.weightKg`（真实档案值）。档案缺体重时用
/// [MetTable.fallbackWeightKg] 降级估算，并由 UI 提示用户补全 ——
/// **不写死 65 当主路径**（执行计划 P3-2 规格）。
library;

/// 主观强度。对应 `ExerciseLog.intensity` 字符串：`LOW` / `MEDIUM` / `HIGH`
/// （与表 CHECK 约束一致）。
enum ExerciseIntensity { low, medium, high }

extension ExerciseIntensityX on ExerciseIntensity {
  /// 对应 DB 列存的字符串（与 `ExerciseLog.intensity` CHECK 约束一致）。
  String get code => switch (this) {
        ExerciseIntensity.low => 'LOW',
        ExerciseIntensity.medium => 'MEDIUM',
        ExerciseIntensity.high => 'HIGH',
      };

  /// 中文展示。
  String get label => switch (this) {
        ExerciseIntensity.low => '低',
        ExerciseIntensity.medium => '中',
        ExerciseIntensity.high => '高',
      };

  /// 由 DB 字符串还原；非法值回退到 [ExerciseIntensity.medium]。
  static ExerciseIntensity fromCode(String? code) => switch (code) {
        'LOW' => ExerciseIntensity.low,
        'HIGH' => ExerciseIntensity.high,
        _ => ExerciseIntensity.medium,
      };
}

/// MET 表中的一条运动：运动名 + 三档强度下的 MET 值。不可变。
class MetEntry {
  const MetEntry(this.name, this.low, this.medium, this.high);

  final String name;
  final double low;
  final double medium;
  final double high;

  /// 该运动在指定强度下的 MET。
  double metFor(ExerciseIntensity intensity) => switch (intensity) {
        ExerciseIntensity.low => low,
        ExerciseIntensity.medium => medium,
        ExerciseIntensity.high => high,
      };
}

/// MET 常量表 + 消耗计算。
class MetTable {
  MetTable._();

  /// 档案缺体重时的降级估算基准（kg）。仅为「能算出一个数」的兜底，
  /// UI 会提示用户补全体重；**不**作为主路径的固定体重（执行计划 P3-2）。
  static const double fallbackWeightKg = 65.0;

  /// 未匹配运动名时回退到的保守 MET（约一般轻度活动）。
  static const double fallbackMet = 4.0;

  /// 预置运动 MET 表（《身体活动纲要》成人均值，粗分三档强度）。
  static const List<MetEntry> entries = [
    MetEntry('跑步', 7.0, 9.8, 11.5),
    MetEntry('走路', 2.8, 3.5, 5.0),
    MetEntry('骑行', 4.0, 8.0, 10.0),
    MetEntry('游泳', 5.8, 8.3, 10.0),
    MetEntry('力量', 3.5, 6.0, 8.0),
    MetEntry('瑜伽', 2.5, 4.0, 6.0),
    MetEntry('跳绳', 8.8, 11.0, 12.5),
    MetEntry('HIIT', 6.0, 8.0, 10.0),
    MetEntry('篮球', 4.5, 6.5, 8.0),
    MetEntry('舞蹈', 3.5, 5.0, 7.3),
  ];

  /// 按运动名查 [MetEntry]；未匹配返回 null。
  static MetEntry? entryFor(String name) {
    for (final e in entries) {
      if (e.name == name) return e;
    }
    return null;
  }

  /// 指定运动名 + 强度的 MET；未匹配运动名回退到 [fallbackMet]。
  static double metFor(String name, ExerciseIntensity intensity) {
    final e = entryFor(name);
    if (e == null) return fallbackMet;
    return e.metFor(intensity);
  }

  /// 运动消耗（kcal） = MET × 体重kg × 时长h。
  ///
  /// - [durationMinutes] ≤ 0 或 [met] ≤ 0 → 返回 0；
  /// - [weightKg] ≤ 0（档案缺体重）→ 用 [fallbackWeightKg] 降级估算，
  ///   调用方应同步提示用户补全体重（见 [usingFallbackWeight]）。
  static double caloriesBurned({
    required double met,
    required double weightKg,
    required int durationMinutes,
  }) {
    if (durationMinutes <= 0 || met <= 0) return 0;
    final weight = weightKg > 0 ? weightKg : fallbackWeightKg;
    final hours = durationMinutes / 60.0;
    return met * weight * hours;
  }

  /// 本次计算是否走了缺体重降级（UI 据此提示「请补全体重」）。
  static bool usingFallbackWeight(double weightKg) => weightKg <= 0;
}
