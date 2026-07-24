import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/features/health/data/repositories/meal_repository_drift.dart';
import 'package:life_os/features/health/domain/nutrition.dart';

/// MealRepository (Drift 实现) 集成测 —— P2-3。
///
/// 重点验证：记录时冻结 `snap*`（= per100 × grams ÷ 100）且不随后续食物库
/// 变化；自定义食物 isCustom、自建品类 isBuiltIn=false；FK 依赖；删除。
void main() {
  late AppDatabase db;
  late MealRepositoryDrift repo;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SystemBootstrap(db).ensureSystemUser();
    repo = MealRepositoryDrift(db);
  });

  tearDown(() async => db.close());

  /// 插入一条已知 per100 的食物（测试夹具，绕过 Repository）。
  Future<void> seedFood({
    String foodId = 'food-rice',
    String name = '米饭',
    double cal = 116,
    double protein = 2.6,
    double fat = 0.3,
    double carbs = 25.9,
    double serving = 150,
  }) async {
    await db.into(db.foodCategory).insert(
          FoodCategoryCompanion.insert(
            categoryId: 'cat-staple',
            userId: systemUserId,
            categoryName: '主食',
            categoryIcon: '🍚',
          ),
        );
    await db.into(db.foodLibrary).insert(
          FoodLibraryCompanion.insert(
            foodId: foodId,
            userId: systemUserId,
            foodName: name,
            categoryId: 'cat-staple',
            caloriesPer100g: cal,
            proteinPer100g: Value(protein),
            fatPer100g: Value(fat),
            carbsPer100g: Value(carbs),
            defaultServingGrams: Value(serving),
          ),
        );
  }

  group('addMealLog 冻结快照', () {
    test('snap* = per100 × grams ÷ 100', () async {
      await seedFood();
      await repo.addMealLog(
        foodId: 'food-rice',
        mealType: MealType.lunch,
        grams: 150,
      );

      final logs = await db.select(db.mealLog).get();
      expect(logs, hasLength(1));
      final log = logs.single;
      expect(log.mealType, 'LUNCH');
      expect(log.grams, 150);
      expect(log.snapCalories, closeTo(174, 1e-9)); // 116 × 1.5
      expect(log.snapProtein, closeTo(3.9, 1e-9)); // 2.6 × 1.5
      expect(log.snapFat, closeTo(0.45, 1e-9)); // 0.3 × 1.5
      expect(log.snapCarbs, closeTo(38.85, 1e-9)); // 25.9 × 1.5
    });

    test('默认份量(100g)时 snap 等于 per100', () async {
      await seedFood();
      await repo.addMealLog(
        foodId: 'food-rice',
        mealType: MealType.breakfast,
        grams: 100,
      );
      final log = (await db.select(db.mealLog).get()).single;
      expect(log.snapCalories, closeTo(116, 1e-9));
      expect(log.snapProtein, closeTo(2.6, 1e-9));
    });

    test('冻结后改食物库不影响已存历史', () async {
      await seedFood();
      await repo.addMealLog(foodId: 'food-rice', mealType: MealType.dinner, grams: 200);
      final frozenCal = (await db.select(db.mealLog).get()).single.snapCalories;
      expect(frozenCal, closeTo(232, 1e-9)); // 116 × 2

      // 之后改食物库的热量基准。
      await (db.update(db.foodLibrary)
            ..where((t) => t.foodId.equals('food-rice')))
          .write(const FoodLibraryCompanion(caloriesPer100g: Value(999)));

      // 历史 snap 不变（冻结）。
      final stillFrozen = (await db.select(db.mealLog).get()).single.snapCalories;
      expect(stillFrozen, closeTo(232, 1e-9));
    });

    test('不存在的食物抛错', () async {
      await expectLater(
        repo.addMealLog(foodId: 'nope', mealType: MealType.snack, grams: 50),
        throwsA(anything),
      );
    });
  });

  group('分餐次', () {
    test('不同餐次各写一行，mealType 枚举映射正确', () async {
      await seedFood();
      for (final t in MealType.values) {
        await repo.addMealLog(foodId: 'food-rice', mealType: t, grams: 100);
      }
      final logs = await db.select(db.mealLog).get();
      expect(logs.map((l) => l.mealType).toSet(), {
        'BREAKFAST',
        'LUNCH',
        'DINNER',
        'SNACK',
      });
    });
  });

  group('自定义食物 / 品类', () {
    test('addCustomFood 写入 isCustom=true 与各营养值', () async {
      final catId = await repo.addFoodCategory(categoryName: '轻食', categoryIcon: '🥗');
      await repo.addCustomFood(
        foodName: '自制沙拉',
        categoryId: catId,
        caloriesPer100g: 80,
        proteinPer100g: 3,
        fatPer100g: 4,
        carbsPer100g: 6,
        defaultServingGrams: 120,
      );
      final foods = await repo.getFoods();
      final salad = foods.firstWhere((f) => f.foodName == '自制沙拉');
      expect(salad.isCustom, true);
      expect(salad.categoryId, catId);
      expect(salad.caloriesPer100g, 80);
      expect(salad.proteinPer100g, 3);
      expect(salad.defaultServingGrams, 120);
    });

    test('addFoodCategory 写入 isBuiltIn=false 且追加到末尾', () async {
      final id1 = await repo.addFoodCategory(categoryName: '饮品', categoryIcon: '🥤');
      final id2 = await repo.addFoodCategory(categoryName: '坚果', categoryIcon: '🥜');
      final cats = await repo.getCategories(); // 按 sortOrder 升序
      final c1 = cats.firstWhere((c) => c.categoryId == id1);
      final c2 = cats.firstWhere((c) => c.categoryId == id2);
      expect(c1.isBuiltIn, false);
      expect(c2.isBuiltIn, false);
      expect(c2.sortOrder, greaterThan(c1.sortOrder)); // 追加在后面
    });
  });

  group('删除 & 流读', () {
    test('deleteMealLog 移除该行', () async {
      await seedFood();
      await repo.addMealLog(foodId: 'food-rice', mealType: MealType.lunch, grams: 100);
      final logId = (await db.select(db.mealLog).get()).single.logId;
      await repo.deleteMealLog(logId);
      expect(await db.select(db.mealLog).get(), isEmpty);
    });

    test('watchMealLogs 反映当前状态', () async {
      expect(await repo.watchMealLogs().first, isEmpty);
      await seedFood();
      await repo.addMealLog(foodId: 'food-rice', mealType: MealType.breakfast, grams: 100);
      expect(await repo.watchMealLogs().first, hasLength(1));
    });
  });

  group('系统用户前置 (FK)', () {
    test('无系统用户时 addCustomFood 因 userId FK 失败', () async {
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      final freshRepo = MealRepositoryDrift(fresh);
      // FoodLibrary.userId FK -> UserAccounts；无系统用户 → 违反约束。
      await expectLater(
        freshRepo.addCustomFood(
          foodName: '孤儿',
          categoryId: 'cat-x',
          caloriesPer100g: 10,
        ),
        throwsA(anything),
      );
    });
  });
}
