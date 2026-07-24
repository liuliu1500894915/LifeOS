import 'package:drift/drift.dart';

import 'database_connection.dart';
import 'schema_versions.dart';
import 'tables/app_defaults.dart';
import 'tables/pet_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/daily_tables.dart';
import 'tables/profile_tables.dart';
import 'tables/system_tables.dart';
import 'tables/health_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    PetStatusCore,
    PetActionQuickLog,
    RoomFurniturePlacement,
    UserProfile,
    WeightHistory,
    FinancialTransaction,
    AssetInventory,
    PaymentAccounts,
    SubscriptionServices,
    BudgetSettings,
    AssetValueSnapshots,
    ExpenseCategories,
    TodoExecutionList,
    HabitDefinitions,
    HabitCheckLog,
    FlagGoals,
    FlagMilestones,
    DailyReviewLog,
    SecureDocumentsVault,
    MemorialDays,
    RelationshipNetwork,
    RelationshipInteractionLog,
    UserAccounts,
    AnalyticalInsights,
    DailyAggregationCache,
    BackgroundWorkerLog,
    FoodCategory,
    FoodLibrary,
    MealLog,
    NutritionGoal,
    ExerciseLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // 索引不随 createAll 生成，需在 fresh install 时一并补（与 from2To3
          // 对称，保证新旧安装 schema 一致）。
          await _createHealthIndexes(m);
        },
        onUpgrade: stepByStep(
          from1To2: (m, schema) async {
            // v1→v2: only ExpenseCategories is new. The previous onUpgrade
            // re-created 8 finance tables, 7 of which already existed in v1
            // and would have raised "table already exists" on a real upgrade.
            await m.createTable(schema.expenseCategories);
          },
          from2To3: (m, schema) async {
            // v2→v3: 健康·摄入/消耗五张表（P2-1/P3-1）。只 createTable，不触碰
            // 既有表；旧库升级零数据风险。
            await m.createTable(schema.foodCategory);
            await m.createTable(schema.foodLibrary);
            await m.createTable(schema.mealLog);
            await m.createTable(schema.nutritionGoal);
            await m.createTable(schema.exerciseLog);
            await _createHealthIndexes(m);
          },
        ),
        beforeOpen: (details) async {
          // foreign_keys must be (re)enabled on every open — keeping it only
          // in the native connection's `setup` is unreliable across migrations
          // (blueprint §1.4 / 执行计划 §1.2).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// 健康·摄入/消耗两张日志表（meal_log / exercise_log）的「用户 + 时间」
  /// 复合索引。日志查询一律按 user_id 过滤、logged_at 排序，建此索引避免全表
  /// 扫（执行计划铁律：禁止全表 get 后 Dart 过滤）。
  ///
  /// onCreate（fresh install）与 from2To3（旧库升级）都调一次，保证两条安装
  /// 路径 schema 一致；IF NOT EXISTS 使其本身幂等。
  Future<void> _createHealthIndexes(Migrator m) async {
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_user_date '
      'ON meal_log(user_id, logged_at)',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_exercise_user_date '
      'ON exercise_log(user_id, logged_at)',
    );
  }
}

QueryExecutor _openConnection() {
  return createDatabaseConnection();
}
