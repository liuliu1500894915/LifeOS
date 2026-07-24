import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/system_bootstrap.dart';
import 'goal_repository.dart';

/// [NutritionGoalRepository] 的 Drift 实现：目标行 SQL 集中于此（P2-4）。
///
/// 读用 `.watch()` / `.get()`（按系统用户过滤，`watchSingleOrNull` 保证未设目标
/// 时发射 null 而非报错）；写用 `insertOnConflictUpdate`（PK=userId → 同一用户
/// 行幂等覆盖，无需先判存）。系统用户 `user-001` 由 [SystemBootstrap] 启动时
/// 一次性确保。
class NutritionGoalRepositoryDrift implements NutritionGoalRepository {
  NutritionGoalRepositoryDrift(this._db);

  final AppDatabase _db;

  @override
  Stream<NutritionGoalData?> watchGoal() =>
      (_db.select(_db.nutritionGoal)
            ..where((t) => t.userId.equals(systemUserId)))
          .watchSingleOrNull();

  @override
  Future<NutritionGoalData?> getGoal() =>
      (_db.select(_db.nutritionGoal)
            ..where((t) => t.userId.equals(systemUserId)))
          .getSingleOrNull();

  @override
  Future<void> upsertGoal({
    required String activityLevel,
    required String goalType,
    required double calorieTarget,
    required double proteinTarget,
    required double fatTarget,
    required double carbTarget,
    required bool isAutoCalculated,
  }) async {
    await _db.into(_db.nutritionGoal).insertOnConflictUpdate(
          NutritionGoalCompanion.insert(
            userId: systemUserId,
            activityLevel: activityLevel,
            goalType: goalType,
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            fatTarget: fatTarget,
            carbTarget: carbTarget,
            isAutoCalculated: Value(isAutoCalculated),
          ),
        );
  }

  @override
  Future<void> deleteGoal() async {
    await (_db.delete(_db.nutritionGoal)
          ..where((t) => t.userId.equals(systemUserId)))
        .go();
  }
}

/// Repository 的 Riverpod 入口；presentation 的 Provider 依赖此
/// [NutritionGoalRepository] 接口。
final nutritionGoalRepositoryProvider = Provider<NutritionGoalRepository>((ref) {
  return NutritionGoalRepositoryDrift(ref.read(databaseProvider));
});
