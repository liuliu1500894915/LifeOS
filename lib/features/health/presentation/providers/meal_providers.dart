import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../data/health_bootstrap.dart';
import '../../data/repositories/meal_repository_drift.dart';
import '../../domain/nutrition.dart';

// ── Stream-backed notifiers ──
//
// presentation 层状态编排 —— 只调 [MealRepository] 接口，无任何 `db.`/
// `Companion`/裸查询。读取走 Repository 的 `.watch()` 流(Drift StreamQueries)：
// 写库后流自动重发新值，UI 自动刷新。因此命令只转发给 Repository、不触碰 state、
// 不手动 _fetchAll、不靠 ref.invalidate 跨 Provider 同步(同 finance 范例)。
//
// 系统用户前置：每个写方法首行 `await ref.read(systemBootstrapProvider.future)`
// ——StreamNotifier 的 `async*` build 体是惰性的(被 listen 才跑)，旧 AsyncNotifier
// 那层「build 同步执行顺带排 systemBootstrap 进队列」的隐式保证在此失效，故写
// 方法显式自保护(详见 finance_providers.dart 顶部说明)。食物库/品类读 Notifier
// 额外 await foodLibraryBootstrap，保证首启打包导入已完成(P2-1)。

class FoodLibraryNotifier extends StreamNotifier<List<FoodLibraryData>> {
  @override
  Stream<List<FoodLibraryData>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    // 等打包食物库首启导入完成(P2-1)后再发流，避免首帧空列表闪烁。
    await ref.read(foodLibraryBootstrapProvider.future);
    yield* ref.watch(mealRepositoryProvider).watchFoods();
  }

  Future<void> addCustomFood({
    required String foodName,
    required String categoryId,
    required double caloriesPer100g,
    double proteinPer100g = 0,
    double fatPer100g = 0,
    double carbsPer100g = 0,
    double defaultServingGrams = 100,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(mealRepositoryProvider).addCustomFood(
          foodName: foodName,
          categoryId: categoryId,
          caloriesPer100g: caloriesPer100g,
          proteinPer100g: proteinPer100g,
          fatPer100g: fatPer100g,
          carbsPer100g: carbsPer100g,
          defaultServingGrams: defaultServingGrams,
        );
  }
}

class FoodCategoryNotifier extends StreamNotifier<List<FoodCategoryData>> {
  @override
  Stream<List<FoodCategoryData>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(foodLibraryBootstrapProvider.future);
    yield* ref.watch(mealRepositoryProvider).watchCategories();
  }

  /// 新建品类，返回新品类 id（自定义食物表单可直接选中）。
  Future<String> addFoodCategory({
    required String categoryName,
    required String categoryIcon,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    return ref.read(mealRepositoryProvider).addFoodCategory(
          categoryName: categoryName,
          categoryIcon: categoryIcon,
        );
  }
}

class MealLogNotifier extends StreamNotifier<List<MealLogData>> {
  @override
  Stream<List<MealLogData>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(mealRepositoryProvider).watchMealLogs();
  }

  Future<void> addMealLog({
    required String foodId,
    required MealType mealType,
    required double grams,
    DateTime? loggedAt,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(mealRepositoryProvider).addMealLog(
          foodId: foodId,
          mealType: mealType,
          grams: grams,
          loggedAt: loggedAt,
        );
  }

  Future<void> deleteMealLog(String logId) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(mealRepositoryProvider).deleteMealLog(logId);
  }
}

// ── Providers ──

final foodLibraryProvider =
    StreamNotifierProvider<FoodLibraryNotifier, List<FoodLibraryData>>(
  FoodLibraryNotifier.new,
);

final foodCategoryProvider =
    StreamNotifierProvider<FoodCategoryNotifier, List<FoodCategoryData>>(
  FoodCategoryNotifier.new,
);

final mealLogProvider =
    StreamNotifierProvider<MealLogNotifier, List<MealLogData>>(
  MealLogNotifier.new,
);

/// 食物 id → 行 的映射（基于已 watch 的食物流派生），供记录列表同步取食物名，
/// 避免为每条记录单独查库。
final foodByIdProvider = Provider<Map<String, FoodLibraryData>>((ref) {
  final foods = ref.watch(foodLibraryProvider).valueOrNull ??
      const <FoodLibraryData>[];
  return {for (final f in foods) f.foodId: f};
});

// ── 搜索 / 品类筛选（基于已 watch 的食物流派生，UI 临时过滤）──

final foodSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedFoodCategoryProvider = StateProvider<String?>((ref) => null);

final filteredFoodsProvider = Provider<List<FoodLibraryData>>((ref) {
  final foods = ref.watch(foodLibraryProvider).valueOrNull ??
      const <FoodLibraryData>[];
  final query = ref.watch(foodSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(selectedFoodCategoryProvider);
  return foods.where((f) {
    if (category != null && f.categoryId != category) return false;
    if (query.isNotEmpty && !f.foodName.toLowerCase().contains(query)) {
      return false;
    }
    return true;
  }).toList();
});

// ── 当日聚合（本地日 dateOnly 口径，避免跨日比较出错）──

DateTime _todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final todayMealLogsProvider = Provider<List<MealLogData>>((ref) {
  final logs = ref.watch(mealLogProvider).valueOrNull ?? const <MealLogData>[];
  final start = _todayStart();
  final end = start.add(const Duration(days: 1));
  return logs
      .where((l) => !l.loggedAt.isBefore(start) && l.loggedAt.isBefore(end))
      .toList();
});

/// 当日记录按餐次分组（保持 [MealType] 枚举顺序：早/午/晚/加餐）。
final mealLogsByTypeProvider =
    Provider<Map<MealType, List<MealLogData>>>((ref) {
  final logs = ref.watch(todayMealLogsProvider);
  final map = {for (final t in MealType.values) t: <MealLogData>[]};
  for (final log in logs) {
    map[MealType.fromDbValue(log.mealType)]!.add(log);
  }
  return map;
});

/// 当日营养合计（冻结快照累加）。
final todayNutritionProvider = Provider<NutritionSnapshot>((ref) {
  final logs = ref.watch(todayMealLogsProvider);
  return logs.fold<NutritionSnapshot>(
    NutritionSnapshot.zero,
    (acc, l) => NutritionSnapshot(
      calories: acc.calories + l.snapCalories,
      protein: acc.protein + l.snapProtein,
      fat: acc.fat + l.snapFat,
      carbs: acc.carbs + l.snapCarbs,
    ),
  );
});

/// 各餐次营养合计。
final nutritionByTypeProvider =
    Provider<Map<MealType, NutritionSnapshot>>((ref) {
  final byType = ref.watch(mealLogsByTypeProvider);
  return {
    for (final t in MealType.values)
      t: byType[t]!.fold<NutritionSnapshot>(
        NutritionSnapshot.zero,
        (acc, l) => NutritionSnapshot(
          calories: acc.calories + l.snapCalories,
          protein: acc.protein + l.snapProtein,
          fat: acc.fat + l.snapFat,
          carbs: acc.carbs + l.snapCarbs,
        ),
      ),
  };
});
