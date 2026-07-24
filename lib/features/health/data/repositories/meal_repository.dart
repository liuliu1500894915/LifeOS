import '../../../../core/database/app_database.dart';
import '../../domain/nutrition.dart';

/// 饮食记录数据访问抽象层 —— presentation 只依赖此接口，不碰 `AppDatabase`。
///
/// 读暴露 `watchXxx()`(Drift `.watch()` 流)与一次性 `getXxx()`；写一律 `Future`。
/// 见 docs/LifeOS-开发执行计划.md §3.6 与 §1.4。
///
/// 命名前缀 `meal_*`：与 P3-2 的运动侧(`exercise_*` 文件)在 health 模块并行、
/// 互不触碰。运动记录的 Repository 由 P3-2 另建。
abstract interface class MealRepository {
  // ── 食物库 ──
  Stream<List<FoodLibraryData>> watchFoods();
  Future<List<FoodLibraryData>> getFoods();

  // ── 食物品类 ──
  Stream<List<FoodCategoryData>> watchCategories();
  Future<List<FoodCategoryData>> getCategories();

  // ── 饮食记录 ──
  Stream<List<MealLogData>> watchMealLogs();

  /// 记录一笔饮食：事务内读食物 per100 → 按 [grams] 换算 → 冻结写 `MealLog.snap*`。
  ///
  /// 快照在记录时冻结（§1.2.4），后续改食物库不影响历史。
  Future<void> addMealLog({
    required String foodId,
    required MealType mealType,
    required double grams,
    DateTime? loggedAt,
  });

  Future<void> deleteMealLog(String logId);

  // ── 自定义食物 / 品类 ──

  /// 新增自定义食物 → `FoodLibrary(isCustom=true)`，userId=系统用户。
  Future<void> addCustomFood({
    required String foodName,
    required String categoryId,
    required double caloriesPer100g,
    double proteinPer100g,
    double fatPer100g,
    double carbsPer100g,
    double defaultServingGrams,
  });

  /// 新增用户自建品类 → `FoodCategory(isBuiltIn=false)`，追加到排序末尾。
  /// 返回新品类 id（自定义食物表单可直接选中）。
  Future<String> addFoodCategory({
    required String categoryName,
    required String categoryIcon,
  });
}
