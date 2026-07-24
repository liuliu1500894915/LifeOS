import 'package:drift/drift.dart';

import 'system_tables.dart';

/// 食物品类（扁平、可自定义）。预置品类 isBuiltIn=true 不可删；
/// 用户自建 isBuiltIn=false。单一真相：品类只存 DB（执行计划 §1.2）。
class FoodCategory extends Table {
  TextColumn get categoryId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get categoryName => text().withLength(max: 30)();
  TextColumn get categoryIcon => text().withLength(max: 10)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {categoryId};
}

/// 食物库。营养值按「每 100g」存；记录时按克数换算并冻结到 MealLog 的
/// snap* 列，后续改食物库不影响历史（历史数据冻结快照，§1.2）。
class FoodLibrary extends Table {
  TextColumn get foodId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get foodName => text().withLength(max: 100)();
  TextColumn get categoryId =>
      text().withLength(min: 1, max: 36).references(FoodCategory, #categoryId)();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  RealColumn get caloriesPer100g => real()();
  RealColumn get proteinPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get fatPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get carbsPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get defaultServingGrams =>
      real().withDefault(const Constant(100.0))();

  @override
  Set<Column> get primaryKey => {foodId};
}

/// 饮食记录（分餐次）。snap* 为记录时冻结的营养快照
/// （= grams × per100 / 100），不随后续食物库变动。
class MealLog extends Table {
  TextColumn get logId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get foodId =>
      text().withLength(min: 1, max: 36).references(FoodLibrary, #foodId)();
  TextColumn get mealType => text().check(
        mealType.equals('BREAKFAST') |
            mealType.equals('LUNCH') |
            mealType.equals('DINNER') |
            mealType.equals('SNACK'),
      )();
  RealColumn get grams => real()();
  RealColumn get snapCalories => real()();
  RealColumn get snapProtein => real()();
  RealColumn get snapFat => real()();
  RealColumn get snapCarbs => real()();
  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {logId};
}

/// 每日营养目标（每人一条，PK=userId）。可由 TDEE（见
/// tdee_calculator.dart）自动算出，也可手动覆盖（isAutoCalculated=false）。
class NutritionGoal extends Table {
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get activityLevel => text().check(
        activityLevel.equals('SEDENTARY') |
            activityLevel.equals('LIGHT') |
            activityLevel.equals('MODERATE') |
            activityLevel.equals('ACTIVE') |
            activityLevel.equals('VERY_ACTIVE'),
      )();
  TextColumn get goalType => text().check(
        goalType.equals('CUT') |
            goalType.equals('MAINTAIN') |
            goalType.equals('BULK'),
      )();
  RealColumn get calorieTarget => real()();
  RealColumn get proteinTarget => real()();
  RealColumn get fatTarget => real()();
  RealColumn get carbTarget => real()();
  BoolColumn get isAutoCalculated =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId};
}

/// 运动/健身记录（P3-1）。
///
/// 与饮食摄入侧（MealLog，P2-1）对称：分钟数 → 冻结消耗快照。
/// [caloriesBurned] 在记录时由 `MET × 体重kg × 时长h` 算出（MET 值见
/// `domain/met_table.dart`，体重取 UserProfile.weightKg），冻结进表后不再随
/// 体重档案变化（执行计划铁律 §1.2.4：历史不可变数据冻结计算结果）。
class ExerciseLog extends Table {
  TextColumn get logId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get exerciseName => text().withLength(max: 50)();
  IntColumn get durationMinutes => integer()();

  /// 主观强度，可空。对应 `domain/met_table.dart` 的 Intensity 字符串。
  TextColumn get intensity => text()
      .check(
        intensity.equals('LOW') |
            intensity.equals('MEDIUM') |
            intensity.equals('HIGH'),
      )
      .nullable()();

  /// 冻结快照：记录时计算出的消耗 kcal，不依赖引用表当前值。
  RealColumn get caloriesBurned => real()();
  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {logId};
}
