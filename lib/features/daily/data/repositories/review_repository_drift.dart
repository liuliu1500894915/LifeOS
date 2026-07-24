import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/system_bootstrap.dart';
import 'review_repository.dart';

/// [ReviewRepository] 的 Drift 实现：所有 SQL 集中于此。
///
/// 读用 `.watch()`，写用 `insertOnConflictUpdate`（复合主键 reviewDate+userId，
/// 同一日唯一，再次保存即更新）。系统用户由 [SystemBootstrap] 启动时一次性
/// 确保，此处不自调 ensureSystemUser（同 finance/moment/health 范式）。
///
/// `summarySnapshotJson` 由调用方用 [DailyReviewSnapshot.encode] 生成后原样入
/// 库，本类不解析快照语义——存进去即脱离各模块当前值（冻结）。
class ReviewRepositoryDrift implements ReviewRepository {
  ReviewRepositoryDrift(this._db);

  final AppDatabase _db;

  /// 把任意 [DateTime] 规范化为本地日 0 点，作 reviewDate 主键的稳定口径
  /// （执行计划 §5 时区/日期边界：日聚合一律本地日 dateOnly）。先 toLocal 再
  /// 取年月日，避免 UTC/本地时区错位导致跨日比较不一致。
  DateTime _dateOnly(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  Stream<DailyReviewLogData?> watchReviewByDate(DateTime date) {
    final day = _dateOnly(date);
    // 复合主键 (reviewDate, userId)，按这两列过滤保证至多一行 → watchSingleOrNull。
    return (_db.select(_db.dailyReviewLog)
          ..where(
            (t) => t.reviewDate.equals(day) & t.userId.equals(systemUserId),
          ))
        .watchSingleOrNull();
  }

  @override
  Future<void> upsertReview({
    required DateTime date,
    required String moodTag,
    String? highlightText,
    String? improveText,
    String? tomorrowPlanText,
    String? insightsContent,
    required String summarySnapshotJson,
  }) async {
    final day = _dateOnly(date);
    // insertOnConflictUpdate：主键冲突时更新非主键列（mood/结构化三列/快照），
    // 等价于「同一日复盘存在则覆盖」。与 SystemBootstrap 的系统用户 upsert 同范式。
    await _db.into(_db.dailyReviewLog).insertOnConflictUpdate(
          DailyReviewLogCompanion.insert(
            reviewDate: day,
            userId: systemUserId,
            moodTag: moodTag,
            insightsContent: Value(insightsContent),
            summarySnapshotJson: summarySnapshotJson,
            highlightText: Value(highlightText),
            improveText: Value(improveText),
            tomorrowPlanText: Value(tomorrowPlanText),
          ),
        );
  }
}

/// Repository 的 Riverpod 入口；Provider 依赖此 [ReviewRepository] 接口。
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepositoryDrift(ref.read(databaseProvider));
});
