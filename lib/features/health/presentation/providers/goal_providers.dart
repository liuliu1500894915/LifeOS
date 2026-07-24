import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../data/repositories/goal_repository_drift.dart';
import '../../domain/nutrition_goal.dart';
import 'meal_providers.dart' show todayNutritionProvider;

// ── Stream-backed notifier ──
//
// presentation 层状态编排 —— 只调 [NutritionGoalRepository] 接口，无 `db.`/
// `Companion`/裸查询（§1.4）。读取走 Repository 的 `.watch()` 流：改目标后流自动
// 重发新值，UI 自动刷新。因此 upsert/delete 只转发给 Repository，**不**触碰
// state、**不**手动 `_fetchAll`、**不**靠 `ref.invalidate` 跨 Provider 同步
// （同 meal/exercise 范例）。
//
// 系统用户前置：build 与每个写方法首行 `await ref.read(systemBootstrapProvider.future)`
// （StreamNotifier 的 `async*` build 惰性执行，这层 await 把 ensureSystemUser
// 排进队列，避免随后的写撞 FK —— 详见 finance_providers.dart 顶部说明）。

class NutritionGoalNotifier extends StreamNotifier<NutritionGoalData?> {
  @override
  Stream<NutritionGoalData?> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(nutritionGoalRepositoryProvider).watchGoal();
  }

  Future<void> upsertGoal({
    required String activityLevel,
    required String goalType,
    required double calorieTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbTarget,
    required bool isAutoCalculated,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(nutritionGoalRepositoryProvider).upsertGoal(
          activityLevel: activityLevel,
          goalType: goalType,
          calorieTarget: calorieTarget,
          proteinTarget: proteinTarget,
          fatTarget: fatTarget,
          carbTarget: carbTarget,
          isAutoCalculated: isAutoCalculated,
        );
  }

  Future<void> deleteGoal() async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(nutritionGoalRepositoryProvider).deleteGoal();
  }
}

// ── Providers ──

/// 当前系统用户的每日目标（流）；未设目标时发射 null。
final nutritionGoalProvider =
    StreamNotifierProvider<NutritionGoalNotifier, NutritionGoalData?>(
  NutritionGoalNotifier.new,
);

/// 当前目标的 domain 镜像（行 → [NutritionTargets]）；未设目标或加载中为 null。
/// 映射留在 presentation 层：domain 不依赖 Drift 类型（§1.1）。
final nutritionTargetsProvider = Provider<NutritionTargets?>((ref) {
  final row = ref.watch(nutritionGoalProvider).valueOrNull;
  if (row == null) return null;
  return NutritionTargets(
    calorieTarget: row.calorieTarget,
    proteinTarget: row.proteinTarget,
    fatTarget: row.fatTarget,
    carbTarget: row.carbTarget,
  );
});

/// 当日营养进度（摄入 vs 目标）。目标未设时为 null —— UI 据此引导设置目标。
///
/// 派生自两个流式源：[nutritionTargetsProvider]（目标行流）+
/// [todayNutritionProvider]（当日 MealLog 合计流）。任一变化自动重算，无需手动
/// 刷新（执行计划铁律 §1.3：派生数据用 Provider 组合流式源数据）。
final nutritionProgressProvider = Provider<NutritionProgress?>((ref) {
  final target = ref.watch(nutritionTargetsProvider);
  if (target == null) return null;
  final intake = ref.watch(todayNutritionProvider);
  return computeNutritionProgress(target, intake);
});
