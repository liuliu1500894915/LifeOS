import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../health/presentation/providers/exercise_providers.dart';
import '../../../health/presentation/providers/meal_providers.dart';
import '../../data/repositories/review_repository_drift.dart';
import '../../domain/daily_snapshot.dart';
import 'daily_providers.dart';
import 'moment_providers.dart';

// 导出接口/DTO 供复盘页引用，避免页直接 import data 层细节。
export '../../data/repositories/review_repository.dart';
export '../../domain/daily_snapshot.dart';

// ── 日期辅助（本地日 dateOnly 口径，与 meal/exercise/finance 派生 provider 一致）──

DateTime _todayStart() {
  final now = DateTime.now().toLocal();
  return DateTime(now.year, now.month, now.day);
}

DateTime _dateOnly(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

// ── 当日全景快照聚合（P4-2）──
//
// 派生 Provider：watch 各模块当日 provider → 组装 [DailyReviewSnapshot]。它本身
// 是「活的」（随各模块写库自动变）；保存复盘时由 [ReviewNotifier.saveReview]
// 读出当前值并 [DailyReviewSnapshot.encode] 冻结进 `summarySnapshotJson`，从此
// 脱离这些 provider、不再随后续数据变化（蓝图 §1.2 快照冻结）。
//
// P5-3（复盘聚合各模块）将在此扩展：拆 SPOT/摊销、能量净值细分、完成率细分等。
// 当前 P4-2 聚合支出/摄入/消耗/待办四项。
final todayReviewSnapshotProvider = Provider<DailyReviewSnapshot>((ref) {
  final expense = ref.watch(todayExpenseProvider);
  final nutrition = ref.watch(todayNutritionProvider);
  final burned = ref.watch(todayCaloriesBurnedProvider);
  // 待办取当日（targetDate == 今天）那批；完成率 = 已完成 / 当日总数。
  final today = _todayStart();
  final todaysTodos = ref
      .watch(quadrantTodoProvider)
      .where((t) => _dateOnly(t.targetDate) == today)
      .toList();

  return DailyReviewSnapshot(
    expense: expense,
    intakeCalories: nutrition.calories,
    burnedCalories: burned,
    todoTotal: todaysTodos.length,
    todoCompleted: todaysTodos.where((t) => t.isCompleted).length,
  );
});

/// 当日生活瞬间（含照片），供复盘页关联展示当日 moments。
final todayMomentsProvider = Provider<List<MomentWithPhotos>>((ref) {
  final all = ref.watch(momentsWithPhotosProvider);
  final start = _todayStart();
  final end = start.add(const Duration(days: 1));
  return all
      .where((m) {
        final t = m.moment.loggedAt;
        return !t.isBefore(start) && t.isBefore(end);
      })
      .toList();
});

// ── Stream-backed notifier ──
//
// presentation 层状态编排 —— 只调 [ReviewRepository] 接口，无 `db.`/`Companion`/
// 裸查询。读取走 Repository 的 `.watch()` 流：upsert 写库后流自动重发新行，复盘
// 页 UI 自动刷新。命令（save）只转发给 Repository、不触碰 state、不手动 _fetchAll、
// 不靠 ref.invalidate 跨 Provider 同步（同 finance/health/moment 范例）。
//
// 系统用户前置：build 与写方法首行 `await ref.read(systemBootstrapProvider.future)`
// （StreamNotifier 的 `async*` build 惰性执行，这层 await 把 systemBootstrap 排进
// 队列，避免随后的写撞 FK）。
class ReviewNotifier extends StreamNotifier<DailyReviewLogData?> {
  @override
  Stream<DailyReviewLogData?> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(reviewRepositoryProvider).watchReviewByDate(DateTime.now());
  }

  /// 保存（upsert）今日复盘。结构化三列 + mood 来自编辑页表单；当日全景快照
  /// 在此刻**冻结**进 `summarySnapshotJson`（读 [todayReviewSnapshotProvider]
  /// 当前值 encode）。再次保存即覆盖当日复盘并重冻结。
  Future<void> saveReview({
    required String moodTag,
    String? highlightText,
    String? improveText,
    String? tomorrowPlanText,
    String? insightsContent,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    final snapshot = ref.read(todayReviewSnapshotProvider);
    await ref.read(reviewRepositoryProvider).upsertReview(
          date: DateTime.now(),
          moodTag: moodTag,
          highlightText: highlightText,
          improveText: improveText,
          tomorrowPlanText: tomorrowPlanText,
          insightsContent: insightsContent,
          summarySnapshotJson: DailyReviewSnapshot.encode(snapshot),
        );
  }
}

/// 当日复盘行流（无则为 null）。写库后自动重发。
final reviewProvider =
    StreamNotifierProvider<ReviewNotifier, DailyReviewLogData?>(
  ReviewNotifier.new,
);
