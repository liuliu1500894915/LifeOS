// ignore_for_file: discarded_futures
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/features/health/data/health_bootstrap.dart';

import 'generated_migrations/schema.dart';

/// 健康摄入/消耗 schema 测试（P2-1 / P3-1）。
///
/// 覆盖：
/// 1. 迁移正确性——v2→v3（及 v1→v3 链式）产出的 schema 与 v3 定义一致；
///    fresh install 全表 + 索引齐备。
/// 2. 五张表 CRUD（含外键链 FoodCategory→FoodLibrary→MealLog）。
/// 3. 首启幂等导入打包食物库（二次调用不重复写）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final verifier = SchemaVerifier(GeneratedHelper());

  group('health schema migration (v3)', () {
    test('v2 -> v3 yields a schema matching the v3 definition', () async {
      final connection = await verifier.startAt(2);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      // migrateAndValidate throws if the post-migration schema doesn't match
      // the generated v3 definition — i.e. fresh install == upgrade install.
      await verifier.migrateAndValidate(db, 3);
    });

    test('v1 -> v3 chains through every step correctly', () async {
      final connection = await verifier.startAt(1);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);
    });

    test('v2 -> v3 creates the health log indexes', () async {
      // 索引不属于 migrateAndValidate 的列校验范围，需显式查 sqlite_master。
      final schema = await verifier.schemaAt(2);
      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);

      final idx = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_%'",
          )
          .get();
      final names = idx.map((r) => r.read<String>('name')).toSet();
      expect(names, {'idx_meal_user_date', 'idx_exercise_user_date'});
    });

    test('fresh install creates all health tables and the two indexes',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      // Force open so onCreate + beforeOpen run.
      await db.customSelect('SELECT 1').get();

      // 五张健康表都可达（否则 select 抛）。
      expect((await db.select(db.foodCategory).get()), isEmpty);
      expect((await db.select(db.foodLibrary).get()), isEmpty);
      expect((await db.select(db.mealLog).get()), isEmpty);
      expect((await db.select(db.nutritionGoal).get()), isEmpty);
      expect((await db.select(db.exerciseLog).get()), isEmpty);

      // fresh install 走 onCreate 也建了索引（与升级路径一致）。
      final idx = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name LIKE 'idx_%'",
      ).get();
      final names = idx.map((r) => r.read<String>('name')).toSet();
      expect(names, {'idx_meal_user_date', 'idx_exercise_user_date'});

      // fresh schema matches the generated definition.
      await db.validateDatabaseSchema();
    });
  });

  group('health tables CRUD', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get(); // force open
      await db.into(db.userAccounts).insertOnConflictUpdate(
            UserAccountsCompanion.insert(
              userId: 'user-001',
              displayName: '默认用户',
            ),
          );
    });

    tearDown(() => db.close());

    test('FoodCategory -> FoodLibrary -> MealLog 链写入并冻结快照', () async {
      await db.into(db.foodCategory).insert(
            FoodCategoryCompanion.insert(
              categoryId: 'cat-staple',
              userId: 'user-001',
              categoryName: '主食',
              categoryIcon: '🍚',
            ),
          );
      await db.into(db.foodLibrary).insert(
            FoodLibraryCompanion.insert(
              foodId: 'food-rice',
              userId: 'user-001',
              foodName: '米饭',
              categoryId: 'cat-staple',
              caloriesPer100g: 116,
            ),
          );
      // 记录时按克数换算并冻结 snap*（此处 150g → 174 kcal）。
      await db.into(db.mealLog).insert(
            MealLogCompanion.insert(
              logId: 'meal-001',
              userId: 'user-001',
              foodId: 'food-rice',
              mealType: 'BREAKFAST',
              grams: 150,
              snapCalories: 174,
              snapProtein: 3.9,
              snapFat: 0.45,
              snapCarbs: 38.85,
              loggedAt: DateTime(2026, 7, 24, 8),
            ),
          );

      final meal = (await db.select(db.mealLog).get()).single;
      expect(meal.snapCalories, 174); // 冻结值，不随后续食物库变动
      expect(meal.mealType, 'BREAKFAST');

      // 外键：删被 meal_log 引用的食物库行应被 FK RESTRICT 阻止
      // （历史快照依赖引用完整性）。
      await expectLater(
        (db.delete(db.foodLibrary)
              ..where((f) => f.foodId.equals('food-rice')))
            .go(),
        throwsA(isA<Exception>()),
      );
      // 被引用行仍在。
      final stillThere = await (db.select(db.foodLibrary)
            ..where((f) => f.foodId.equals('food-rice')))
          .getSingle();
      expect(stillThere.foodName, '米饭');
    });

    test('NutritionGoal 一人一条 (PK=userId) 覆盖写入', () async {
      await db.into(db.nutritionGoal).insert(
            NutritionGoalCompanion.insert(
              userId: 'user-001',
              activityLevel: 'MODERATE',
              goalType: 'CUT',
              calorieTarget: 1800,
              proteinTarget: 135,
              fatTarget: 60,
              carbTarget: 180,
            ),
          );
      // 同一 userId 再 insert 应冲突 → 用 insertOnConflictUpdate 覆盖。
      await db.into(db.nutritionGoal).insertOnConflictUpdate(
            NutritionGoalCompanion.insert(
              userId: 'user-001',
              activityLevel: 'MODERATE',
              goalType: 'MAINTAIN',
              calorieTarget: 2200,
              proteinTarget: 130,
              fatTarget: 70,
              carbTarget: 240,
            ),
          );
      final goals = await db.select(db.nutritionGoal).get();
      expect(goals, hasLength(1));
      expect(goals.single.goalType, 'MAINTAIN');
      expect(goals.single.calorieTarget, 2200);
    });

    test('ExerciseLog 写入冻结消耗', () async {
      await db.into(db.exerciseLog).insert(
            ExerciseLogCompanion.insert(
              logId: 'ex-001',
              userId: 'user-001',
              exerciseName: '慢跑',
              durationMinutes: 30,
              intensity: const Value('MEDIUM'),
              caloriesBurned: 280,
              loggedAt: DateTime(2026, 7, 24, 19),
            ),
          );
      final ex = (await db.select(db.exerciseLog).get()).single;
      expect(ex.caloriesBurned, 280);
      expect(ex.intensity, 'MEDIUM');
    });
  });

  group('food library bootstrap (幂等导入)', () {
    test('首启导入 9 品类 + 47 食物，二次调用不重复写', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await seedFoodLibraryIfNeeded(db);

      final cats1 = await db.select(db.foodCategory).get();
      final foods1 = await db.select(db.foodLibrary).get();
      expect(cats1, hasLength(9));
      expect(foods1, hasLength(47));
      // 预置品类不可删（isBuiltIn=true）。
      expect(cats1.every((c) => c.isBuiltIn), isTrue);
      // 抽查已知食物：米饭 116 kcal/100g。
      final rice = foods1.firstWhere((f) => f.foodId == 'food-rice');
      expect(rice.caloriesPer100g, 116);
      // 所有食物挂在系统用户下。
      expect(foods1.every((f) => f.userId == 'user-001'), isTrue);

      // 二次调用：已有品类 → 整体跳过，行数不变。
      await seedFoodLibraryIfNeeded(db);
      final cats2 = await db.select(db.foodCategory).get();
      final foods2 = await db.select(db.foodLibrary).get();
      expect(cats2, hasLength(9));
      expect(foods2, hasLength(47));
    });
  });
}
