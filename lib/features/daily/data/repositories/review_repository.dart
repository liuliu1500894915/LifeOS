import '../../../../core/database/app_database.dart';

/// 复盘日志数据访问抽象层 —— presentation 只依赖此接口，不碰 `AppDatabase`。
///
/// 读暴露 `watchXxx()`（Drift `.watch()` 流）；写一律 `Future`。
/// 复盘按「日」唯一：复合主键 `(reviewDate, userId)`，同一日只有一条；写入用
/// upsert（insertOnConflictUpdate），再次保存即更新当日复盘。
///
/// 当日全景快照以 JSON 字符串存入 `summarySnapshotJson`（由调用方用
/// [DailyReviewSnapshot.encode] 生成），Repository 只管行、不解析快照语义。
///
/// 见 docs/LifeOS-开发执行计划.md P4-2 与 §3.1。
abstract interface class ReviewRepository {
  /// 按日（本地日 dateOnly）watch 当日复盘；无则流内为 null。
  /// 写库（upsert）后流自动重发新行，复盘页 UI 自动刷新。
  Stream<DailyReviewLogData?> watchReviewByDate(DateTime date);

  /// 写入或更新某日复盘（upsert，按 reviewDate+userId）。[date] 会被规范化为
  /// 本地日 dateOnly 作主键。`moodTag` 与 `summarySnapshotJson` 为 NOT NULL
  /// 必填；结构化三列与 `insightsContent` 可空。
  Future<void> upsertReview({
    required DateTime date,
    required String moodTag,
    String? highlightText,
    String? improveText,
    String? tomorrowPlanText,
    String? insightsContent,
    required String summarySnapshotJson,
  });
}
