import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../domain/nutrition.dart';
import 'meal_repository.dart';

const _uuid = Uuid();

/// [MealRepository] 的 Drift 实现：所有 SQL 集中于此。
///
/// 读用 `.watch()`/`.get()`，写用 `Future`。记录饮食（[addMealLog]）在事务内
/// 读食物 per100 → 调纯函数 [nutritionForGrams] 算冻结快照 → 写 `MealLog.snap*`，
/// 保证历史不随后续食物库变动（§1.2.4）。系统用户由 [SystemBootstrap] 启动时
/// 一次性确保，此处不自调 ensureSystemUser。
class MealRepositoryDrift implements MealRepository {
  MealRepositoryDrift(this._db);

  final AppDatabase _db;

  // ── 食物库 ──

  @override
  Stream<List<FoodLibraryData>> watchFoods() =>
      (_db.select(_db.foodLibrary)
            ..orderBy([(t) => OrderingTerm.asc(t.foodName)]))
          .watch();

  @override
  Future<List<FoodLibraryData>> getFoods() =>
      (_db.select(_db.foodLibrary)
            ..orderBy([(t) => OrderingTerm.asc(t.foodName)]))
          .get();

  // ── 食物品类 ──

  @override
  Stream<List<FoodCategoryData>> watchCategories() =>
      (_db.select(_db.foodCategory)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  @override
  Future<List<FoodCategoryData>> getCategories() =>
      (_db.select(_db.foodCategory)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  // ── 饮食记录 ──

  @override
  Stream<List<MealLogData>> watchMealLogs() =>
      (_db.select(_db.mealLog)
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .watch();

  @override
  Future<void> addMealLog({
    required String foodId,
    required MealType mealType,
    required double grams,
    DateTime? loggedAt,
  }) async {
    // 事务内读 per100 + 算快照 + 写表，冻结一个一致快照（不被并发改库打断）。
    await _db.transaction(() async {
      final food = await (_db.select(_db.foodLibrary)
            ..where((t) => t.foodId.equals(foodId)))
          .getSingleOrNull();
      if (food == null) {
        throw StateError('addMealLog: 食物 $foodId 不存在');
      }
      final snap = nutritionForGrams(
        per100: NutritionPer100g(
          calories: food.caloriesPer100g,
          protein: food.proteinPer100g,
          fat: food.fatPer100g,
          carbs: food.carbsPer100g,
        ),
        grams: grams,
      );
      await _db.into(_db.mealLog).insert(
            MealLogCompanion.insert(
              logId: _uuid.v4(),
              userId: systemUserId,
              foodId: foodId,
              mealType: mealType.dbValue,
              grams: grams,
              snapCalories: snap.calories,
              snapProtein: snap.protein,
              snapFat: snap.fat,
              snapCarbs: snap.carbs,
              loggedAt: loggedAt ?? DateTime.now(),
            ),
          );
    });
  }

  @override
  Future<void> deleteMealLog(String logId) async {
    await (_db.delete(_db.mealLog)..where((t) => t.logId.equals(logId))).go();
  }

  // ── 自定义食物 / 品类 ──

  @override
  Future<void> addCustomFood({
    required String foodName,
    required String categoryId,
    required double caloriesPer100g,
    double proteinPer100g = 0,
    double fatPer100g = 0,
    double carbsPer100g = 0,
    double defaultServingGrams = 100,
  }) async {
    await _db.into(_db.foodLibrary).insert(
          FoodLibraryCompanion.insert(
            foodId: _uuid.v4(),
            userId: systemUserId,
            foodName: foodName,
            categoryId: categoryId,
            isCustom: const Value(true),
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: Value(proteinPer100g),
            fatPer100g: Value(fatPer100g),
            carbsPer100g: Value(carbsPer100g),
            defaultServingGrams: Value(defaultServingGrams),
          ),
        );
  }

  @override
  Future<String> addFoodCategory({
    required String categoryName,
    required String categoryIcon,
  }) async {
    final maxSort = await (_db.select(_db.foodCategory)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    final id = _uuid.v4();
    await _db.into(_db.foodCategory).insert(
          FoodCategoryCompanion.insert(
            categoryId: id,
            userId: systemUserId,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            // 自建品类追加到排序末尾，排在预置品类之后。
            sortOrder: Value((maxSort?.sortOrder ?? 0) + 1),
            isBuiltIn: const Value(false),
          ),
        );
    return id;
  }
}

/// Repository 的 Riverpod 入口；Provider 依赖此 [MealRepository] 接口。
final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepositoryDrift(ref.read(databaseProvider));
});
