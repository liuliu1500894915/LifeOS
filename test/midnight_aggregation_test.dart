// hide isNull/isNotNull：drift 与 flutter_test 都导出两者，本文件用 matcher 版本。
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/core/workers/midnight_settlement_service.dart';

/// P5-2 午夜结算汇总测 —— 在 NativeDatabase.memory() 上验证 DailyAggregationCache
/// 的 calorieIn/calorieOut 改从健康新表汇总：
///   ① calorieIn 来自当日 MealLog.snapCalories、calorieOut 来自当日 ExerciseLog.caloriesBurned；
///   ② 仅计入当日窗口（隔日记录不计入）；
///   ③ 旧宠物 FEED/SPORT 不再影响 calorie 汇总；
///   ④ 幂等：重复结算不重复累加（upsert，不翻倍）。
void main() {
  late AppDatabase db;
  late MidnightSettlementService service;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SystemBootstrap(db).ensureSystemUser();
    service = MidnightSettlementService(db);
  });

  tearDown(() async => db.close());

  /// 建一条食物品类 + 食物（MealLog.foodId → FoodLibrary FK 链），返回 foodId。
  Future<String> seedFood() async {
    await db.into(db.foodCategory).insert(
          FoodCategoryCompanion.insert(
            categoryId: 'cat-1',
            userId: 'user-001',
            categoryName: '主食',
            categoryIcon: '🍚',
          ),
        );
    await db.into(db.foodLibrary).insert(
          FoodLibraryCompanion.insert(
            foodId: 'food-1',
            userId: 'user-001',
            foodName: '米饭',
            categoryId: 'cat-1',
            caloriesPer100g: 130,
          ),
        );
    return 'food-1';
  }

  /// 直插一笔饮食记录（snapCalories 为冻结快照，绕过换算以隔离测试）。
  Future<void> addMeal({
    required String foodId,
    required double snapCalories,
    required DateTime loggedAt,
  }) async {
    await db.into(db.mealLog).insert(
          MealLogCompanion.insert(
            logId: 'meal-${loggedAt.millisecondsSinceEpoch}-$snapCalories',
            userId: 'user-001',
            foodId: foodId,
            mealType: 'LUNCH',
            grams: 100,
            snapCalories: snapCalories,
            snapProtein: 0,
            snapFat: 0,
            snapCarbs: 0,
            loggedAt: loggedAt,
          ),
        );
  }

  /// 直插一笔运动记录（caloriesBurned 为冻结快照）。
  Future<void> addExercise({
    required double caloriesBurned,
    required int durationMinutes,
    required DateTime loggedAt,
  }) async {
    await db.into(db.exerciseLog).insert(
          ExerciseLogCompanion.insert(
            logId: 'ex-${loggedAt.millisecondsSinceEpoch}-$durationMinutes',
            userId: 'user-001',
            exerciseName: '跑步',
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            loggedAt: loggedAt,
          ),
        );
  }

  Future<DailyAggregationCacheData?> cacheFor(DateTime date) async {
    return (db.select(db.dailyAggregationCache)
          ..where((t) => t.cacheDate.equals(date) & t.userId.equals('user-001')))
        .getSingleOrNull();
  }

  group('P5-2 结算汇总读新数据源', () {
    test('calorieIn 来自 MealLog、calorieOut 来自 ExerciseLog（仅当日窗口）', () async {
      final foodId = await seedFood();
      final day = DateTime(2026, 7, 24);
      // 当日：摄入 250 + 130 = 380；消耗 200 + 50 = 250。
      await addMeal(foodId: foodId, snapCalories: 250, loggedAt: DateTime(2026, 7, 24, 8));
      await addMeal(foodId: foodId, snapCalories: 130, loggedAt: DateTime(2026, 7, 24, 20));
      await addExercise(caloriesBurned: 200, durationMinutes: 30, loggedAt: DateTime(2026, 7, 24, 7));
      await addExercise(caloriesBurned: 50, durationMinutes: 10, loggedAt: DateTime(2026, 7, 24, 18));
      // 隔日：不计入当日汇总。
      await addMeal(foodId: foodId, snapCalories: 999, loggedAt: DateTime(2026, 7, 25, 8));
      await addExercise(caloriesBurned: 999, durationMinutes: 99, loggedAt: DateTime(2026, 7, 25, 8));

      await service.run(day);

      final cache = await cacheFor(day);
      expect(cache, isNotNull);
      expect(cache!.totalCalorieIntake, 380);
      expect(cache.totalCalorieConsumed, 250);
    });

    test('旧宠物 FEED/SPORT 不再计入 calorieIn/Out', () async {
      final foodId = await seedFood();
      final day = DateTime(2026, 7, 24);
      // 旧数据源（宠物侧投喂/运动）——不应再影响 calorie 汇总。
      await db.into(db.petActionQuickLog).insert(
            PetActionQuickLogCompanion.insert(
              logId: 'pet-feed',
              userId: 'user-001',
              actionType: 'FEED',
              valueNumeric: 999,
              createdAt: Value(DateTime(2026, 7, 24, 12)),
            ),
          );
      await db.into(db.petActionQuickLog).insert(
            PetActionQuickLogCompanion.insert(
              logId: 'pet-sport',
              userId: 'user-001',
              actionType: 'SPORT',
              valueNumeric: 888,
              createdAt: Value(DateTime(2026, 7, 24, 12)),
            ),
          );
      // 当日真实新表数据。
      await addMeal(foodId: foodId, snapCalories: 250, loggedAt: DateTime(2026, 7, 24, 8));
      await addExercise(caloriesBurned: 200, durationMinutes: 30, loggedAt: DateTime(2026, 7, 24, 7));

      await service.run(day);

      final cache = await cacheFor(day);
      expect(cache!.totalCalorieIntake, 250); // 不含宠物 FEED 999
      expect(cache.totalCalorieConsumed, 200); // 不含宠物 SPORT 888
    });

    test('幂等：重复结算不重复累加', () async {
      final foodId = await seedFood();
      final day = DateTime(2026, 7, 24);
      await addMeal(foodId: foodId, snapCalories: 250, loggedAt: DateTime(2026, 7, 24, 8));
      await addExercise(caloriesBurned: 200, durationMinutes: 30, loggedAt: DateTime(2026, 7, 24, 7));

      await service.run(day);
      final first = await cacheFor(day);
      await service.run(day); // 再结算一次
      final second = await cacheFor(day);

      expect(first!.totalCalorieIntake, 250);
      expect(first.totalCalorieConsumed, 200);
      expect(second!.totalCalorieIntake, 250); // 未翻倍
      expect(second.totalCalorieConsumed, 200);
    });

    // 顺手覆盖既有 bug 修复：markRunSuccess 写入 worker_type=MIDNIGHT_ROLLOVER
    // （非 MIDNIGHTROLLOVER）才不触 CHECK；hasRunForDate 据此判定当日已结算。
    test('结算后 hasRunForDate 为真（worker_log 幂等闸门可写可读）', () async {
      final day = DateTime(2026, 7, 24);
      expect(await service.hasRunForDate(day), isFalse);

      await service.run(day);

      expect(await service.hasRunForDate(day), isTrue);
      // 再跑一次仍为真（幂等闸门不因重跑丢失）。
      await service.run(day);
      expect(await service.hasRunForDate(day), isTrue);
    });
  });
}
