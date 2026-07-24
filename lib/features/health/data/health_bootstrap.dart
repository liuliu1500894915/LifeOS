import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/database_provider.dart';
import 'package:life_os/core/database/system_bootstrap.dart'
    show SystemBootstrap, systemUserId;

/// 打包食物库的 asset 路径（在 pubspec.yaml 注册）。
const String kFoodLibraryAsset = 'assets/food_library.json';

/// 首启幂等导入打包食物库（[kFoodLibraryAsset]）+ 预置品类。
///
/// 执行计划 P2-1：首启把 JSON 导入 [FoodLibrary] + seed 预置 [FoodCategory]
/// （isBuiltIn=true）。导入幂等——若 [FoodCategory] 已有记录则整体跳过，
/// 二次启动不重复写。
///
/// user-001 由 [SystemBootstrap.ensureSystemUser] 先 ensure（食物库的
/// userId FK 依赖它）。本函数在 `main.dart` 启动时调用一次；失败仅记日志、
/// 不阻断启动（用户可后续手动触发或重装）。
Future<void> seedFoodLibraryIfNeeded(AppDatabase db) async {
  // 幂等：已有品类则视为已导入，整体跳过。
  final existing = await db.foodCategory.count().getSingle();
  if (existing > 0) {
    debugPrint('[foodLibrary] already seeded ($existing categories), skip.');
    return;
  }

  await SystemBootstrap(db).ensureSystemUser();

  final raw = await rootBundle.loadString(kFoodLibraryAsset);
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final categories =
      (data['categories'] as List).cast<Map<String, dynamic>>();
  final foods = (data['foods'] as List).cast<Map<String, dynamic>>();

  await db.batch((b) {
    b.insertAll(
      db.foodCategory,
      categories.map(
        (c) => FoodCategoryCompanion.insert(
          categoryId: c['categoryId'] as String,
          userId: systemUserId,
          categoryName: c['categoryName'] as String,
          categoryIcon: c['categoryIcon'] as String,
          sortOrder: Value((c['sortOrder'] as num?)?.toInt() ?? 0),
          isBuiltIn: const Value(true),
        ),
      ),
    );
    b.insertAll(
      db.foodLibrary,
      foods.map(
        (f) => FoodLibraryCompanion.insert(
          foodId: f['foodId'] as String,
          userId: systemUserId,
          foodName: f['foodName'] as String,
          categoryId: f['categoryId'] as String,
          caloriesPer100g: (f['caloriesPer100g'] as num).toDouble(),
          proteinPer100g:
              Value((f['proteinPer100g'] as num?)?.toDouble() ?? 0),
          fatPer100g: Value((f['fatPer100g'] as num?)?.toDouble() ?? 0),
          carbsPer100g: Value((f['carbsPer100g'] as num?)?.toDouble() ?? 0),
          defaultServingGrams:
              Value((f['defaultServingGrams'] as num?)?.toDouble() ?? 100),
        ),
      ),
    );
  });

  debugPrint(
    '[foodLibrary] seeded ${categories.length} categories, '
    '${foods.length} foods.',
  );
}

/// 首启幂等导入打包食物库。在 app 启动时 watch 一次（与
/// [systemBootstrapProvider] 同一 DB 实例，经由 [databaseProvider]）。
///
/// 失败仅记日志、不阻断启动——[seedFoodLibraryIfNeeded] 内部已捕获不了
/// rootBundle/JSON 解析异常，这里包一层兜底（首启 asset 缺失等不应崩 app）。
final foodLibraryBootstrapProvider = FutureProvider<void>((ref) async {
  try {
    await seedFoodLibraryIfNeeded(ref.read(databaseProvider));
  } catch (e, s) {
    debugPrint('[foodLibrary] bootstrap failed (non-fatal): $e\n$s');
  }
});
