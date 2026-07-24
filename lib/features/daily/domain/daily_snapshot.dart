import 'dart:convert';

/// 当日全景快照（P4-2 / P5-3）—— 复盘保存时**冻结**的当日各模块聚合值。
///
/// 纯 Dart 模型，无 Flutter/Drift 依赖，可独立单测。序列化为 JSON 存入
/// `DailyReviewLog.summarySnapshotJson`。冻结语义：存库后即脱离各模块 provider
/// 当前值，历史复盘不再随后续数据变化（蓝图 §1.2 快照冻结 / 执行计划 P4-2）。
///
/// 聚合范围（P5-3 复盘聚合各模块，调各模块当日 provider 口径）：
/// - **财务**：日常 SPOT（[spotExpense]）+ 长期摊销（[amortizedExpense]），
///   派生真实日成本（[trueExpense]）。拆分口径与 finance 模块 P1-5 一致
///   （`todaySpotExpenseProvider` / `todayAmortizedExpenseProvider`），摊销按
///   覆盖区间平摊到当日，不含「一次性全额尖峰」。
/// - **健康**：摄入（[intakeCalories]，`MealLog.snapCalories` 合计）/ 消耗
///   （[burnedCalories]，`ExerciseLog.caloriesBurned` 合计）/ 派生净值
///   （[netCalories] = 摄入 − 消耗）。
/// - **待办**：当日总数（[todoTotal]）/ 已完成（[todoCompleted]）/ 派生完成率
///   （[todoCompletionRate]）。
///
/// 各值口径统一为「本地日 dateOnly」（蓝图风险 §5.6），避免跨日比较出错。
class DailyReviewSnapshot {
  const DailyReviewSnapshot({
    required this.spotExpense,
    required this.amortizedExpense,
    required this.intakeCalories,
    required this.burnedCalories,
    required this.todoTotal,
    required this.todoCompleted,
  });

  /// 当日「日常」支出（元，当日发生的 SPOT 支出全额）。
  final double spotExpense;

  /// 当日「摊销」支出（元，覆盖当日的 AMORTIZED 交易按金额÷覆盖天数平摊之和）。
  final double amortizedExpense;

  /// 当日摄入热量（kcal，MealLog.snapCalories 合计）。
  final double intakeCalories;

  /// 当日运动消耗（kcal，ExerciseLog.caloriesBurned 合计）。
  final double burnedCalories;

  /// 当日待办总数（含未完成）。
  final int todoTotal;

  /// 当日已完成待办数。
  final int todoCompleted;

  /// 真实日成本 = 日常 + 摊销（三层自洽，与 finance P1-5 口径一致；派生展示用，
  /// 不计入 JSON）。
  double get trueExpense => spotExpense + amortizedExpense;

  /// 净热量 = 摄入 − 消耗（派生展示用，不计入 JSON）。
  double get netCalories => intakeCalories - burnedCalories;

  /// 待办完成率（0..1，todoTotal 为 0 时为 0，避免除零）。
  double get todoCompletionRate =>
      todoTotal == 0 ? 0 : todoCompleted / todoTotal;

  Map<String, dynamic> toJson() => {
        'spotExpense': spotExpense,
        'amortizedExpense': amortizedExpense,
        'intakeCalories': intakeCalories,
        'burnedCalories': burnedCalories,
        'todoTotal': todoTotal,
        'todoCompleted': todoCompleted,
      };

  factory DailyReviewSnapshot.fromJson(Map<String, dynamic> json) {
    // 数值字段容错：存的是 number，但旧库/手改可能落成字符串，统一转 double/int。
    double toDouble(dynamic v) => (v is num ? v : num.parse('$v')).toDouble();
    int toInt(dynamic v) => (v is num ? v : num.parse('$v')).toInt();
    // 向后兼容（P4-2 → P5-3）：旧快照只存合并的 `expense`（= 当时的真实成本 =
    // 日常 + 摊销），拆分信息已不可恢复。读旧行时视为「全计日常、摊销 0」，
    // 保证 [trueExpense] 仍等于历史总额（冻结语义不丢总额），仅日常/摊销的
    // 细分无法精确还原（这些行本就早于拆分功能）。新行存 spotExpense/
    // amortizedExpense 两键，按新键解析。
    final hasSplit = json['spotExpense'] != null;
    final legacyExpense = toDouble(json['expense'] ?? 0);
    return DailyReviewSnapshot(
      spotExpense: hasSplit ? toDouble(json['spotExpense']) : legacyExpense,
      amortizedExpense:
          hasSplit ? toDouble(json['amortizedExpense'] ?? 0) : 0,
      intakeCalories: toDouble(json['intakeCalories'] ?? 0),
      burnedCalories: toDouble(json['burnedCalories'] ?? 0),
      todoTotal: toInt(json['todoTotal'] ?? 0),
      todoCompleted: toInt(json['todoCompleted'] ?? 0),
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
