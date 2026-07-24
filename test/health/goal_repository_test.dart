import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/features/health/data/repositories/goal_repository_drift.dart';

/// NutritionGoalRepository (Drift 实现) 集成测 —— P2-4。
///
/// 验证：目标行（PK=userId）的 watch / 幂等 upsert（insertOnConflictUpdate 覆盖
/// 同一用户行）/ delete / userId 外键依赖。不改 schema：表自 v3 已建。
void main() {
  late AppDatabase db;
  late NutritionGoalRepositoryDrift repo;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SystemBootstrap(db).ensureSystemUser();
    repo = NutritionGoalRepositoryDrift(db);
  });

  tearDown(() async => db.close());

  group('读（未设目标）', () {
    test('watchGoal 首次发射 null', () async {
      expect(await repo.watchGoal().first, isNull);
    });

    test('getGoal 未设时为 null', () async {
      expect(await repo.getGoal(), isNull);
    });
  });

  group('upsertGoal 幂等覆盖', () {
    test('自动模式：写入四项目标 + isAutoCalculated=true', () async {
      await repo.upsertGoal(
        activityLevel: 'MODERATE',
        goalType: 'CUT',
        calorieTarget: 1800,
        proteinTarget: 120,
        fatTarget: 60,
        carbTarget: 180,
        isAutoCalculated: true,
      );

      final row = (await db.select(db.nutritionGoal).get()).single;
      expect(row.userId, systemUserId);
      expect(row.activityLevel, 'MODERATE');
      expect(row.goalType, 'CUT');
      expect(row.calorieTarget, 1800);
      expect(row.proteinTarget, 120);
      expect(row.fatTarget, 60);
      expect(row.carbTarget, 180);
      expect(row.isAutoCalculated, true);
    });

    test('同一用户二次 upsert 为覆盖、不新增行', () async {
      await repo.upsertGoal(
        activityLevel: 'LIGHT',
        goalType: 'MAINTAIN',
        calorieTarget: 2000,
        proteinTarget: 100,
        fatTarget: 60,
        carbTarget: 250,
        isAutoCalculated: true,
      );
      await repo.upsertGoal(
        activityLevel: 'ACTIVE',
        goalType: 'BULK',
        calorieTarget: 2600,
        proteinTarget: 160,
        fatTarget: 70,
        carbTarget: 300,
        isAutoCalculated: false,
      );

      final rows = await db.select(db.nutritionGoal).get();
      expect(rows, hasLength(1)); // PK=userId → 覆盖而非新增
      final row = rows.single;
      expect(row.activityLevel, 'ACTIVE'); // 后写覆盖
      expect(row.goalType, 'BULK');
      expect(row.calorieTarget, 2600);
      expect(row.isAutoCalculated, false);
    });

    test('watchGoal 在 upsert 后发射新行', () async {
      await repo.upsertGoal(
        activityLevel: 'MODERATE',
        goalType: 'MAINTAIN',
        calorieTarget: 2000,
        proteinTarget: 112,
        fatTarget: 56,
        carbTarget: 250,
        isAutoCalculated: true,
      );
      final row = await repo.watchGoal().first;
      expect(row, isNotNull);
      expect(row!.calorieTarget, 2000);
    });
  });

  group('deleteGoal', () {
    test('清除后表为空、getGoal 为 null', () async {
      await repo.upsertGoal(
        activityLevel: 'MODERATE',
        goalType: 'MAINTAIN',
        calorieTarget: 2000,
        proteinTarget: 112,
        fatTarget: 56,
        carbTarget: 250,
        isAutoCalculated: true,
      );
      expect(await db.select(db.nutritionGoal).get(), hasLength(1));

      await repo.deleteGoal();
      expect(await db.select(db.nutritionGoal).get(), isEmpty);
      expect(await repo.getGoal(), isNull);
    });

    test('未设目标时 delete 无副作用', () async {
      await repo.deleteGoal();
      expect(await repo.getGoal(), isNull);
    });
  });

  group('系统用户前置 (FK)', () {
    test('无系统用户时 upsertGoal 因 userId FK 失败', () async {
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      final freshRepo = NutritionGoalRepositoryDrift(fresh);
      // NutritionGoal.userId FK -> UserAccounts；无系统用户 → 违反约束。
      await expectLater(
        freshRepo.upsertGoal(
          activityLevel: 'MODERATE',
          goalType: 'MAINTAIN',
          calorieTarget: 2000,
          proteinTarget: 112,
          fatTarget: 56,
          carbTarget: 250,
          isAutoCalculated: true,
        ),
        throwsA(anything),
      );
    });
  });
}
