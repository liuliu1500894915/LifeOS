import 'dart:convert';

/// 当日全景快照（P4-2）—— 复盘保存时**冻结**的当日各模块聚合值。
///
/// 纯 Dart 模型，无 Flutter/Drift 依赖，可独立单测。序列化为 JSON 存入
/// `DailyReviewLog.summarySnapshotJson`。冻结语义：存库后即脱离各模块 provider
/// 当前值，历史复盘不再随后续数据变化（蓝图 §1.2 快照冻结 / 执行计划 P4-2）。
///
/// P5-3 将在此基础上扩展聚合字段（摊销、能量净值细分、完成率细分等）；当前
/// P4-2 聚合支出/摄入/消耗/待办四项，值来自 finance/health/daily provider 的
/// 当日口径（本地日 dateOnly，统一避免跨日比较出错）。
class DailyReviewSnapshot {
  const DailyReviewSnapshot({
    required this.expense,
    required this.intakeCalories,
    required this.burnedCalories,
    required this.todoTotal,
    required this.todoCompleted,
  });

  /// 当日支出（元，EXPENSE 金额合计）。
  final double expense;

  /// 当日摄入热量（kcal，MealLog.snapCalories 合计）。
  final double intakeCalories;

  /// 当日运动消耗（kcal，ExerciseLog.caloriesBurned 合计）。
  final double burnedCalories;

  /// 当日待办总数（含未完成）。
  final int todoTotal;

  /// 当日已完成待办数。
  final int todoCompleted;

  /// 净热量 = 摄入 − 消耗（派生展示用，不计入 JSON）。
  double get netCalories => intakeCalories - burnedCalories;

  /// 待办完成率（0..1，todoTotal 为 0 时为 0，避免除零）。
  double get todoCompletionRate =>
      todoTotal == 0 ? 0 : todoCompleted / todoTotal;

  Map<String, dynamic> toJson() => {
        'expense': expense,
        'intakeCalories': intakeCalories,
        'burnedCalories': burnedCalories,
        'todoTotal': todoTotal,
        'todoCompleted': todoCompleted,
      };

  factory DailyReviewSnapshot.fromJson(Map<String, dynamic> json) {
    // 数值字段容错：存的是 number，但旧库/手改可能落成字符串，统一转 double/int。
    double toDouble(dynamic v) => (v is num ? v : num.parse('$v')).toDouble();
    int toInt(dynamic v) => (v is num ? v : num.parse('$v')).toInt();
    return DailyReviewSnapshot(
      expense: toDouble(json['expense']),
      intakeCalories: toDouble(json['intakeCalories']),
      burnedCalories: toDouble(json['burnedCalories']),
      todoTotal: toInt(json['todoTotal']),
      todoCompleted: toInt(json['todoCompleted']),
    );
  }

  /// 编码为 JSON 字符串，供写入 `summarySnapshotJson` 列。
  static String encode(DailyReviewSnapshot snapshot) =>
      jsonEncode(snapshot.toJson());

  /// 解码 `summarySnapshotJson` 列。空串或损坏 JSON 返回 null（防御：历史行可能
  /// 无快照、或被外部手改坏），保证复盘页读取永不抛异常。
  static DailyReviewSnapshot? decode(String? json) {
    if (json == null || json.trim().isEmpty) return null;
    try {
      return DailyReviewSnapshot.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    }
  }
}
