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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // 索引不随 createAll 生成，需在 fresh install 时一并补（与升级路径
          // 对称，保证新旧安装 schema 一致）。
          await _createHealthIndexes(m);
          await _createFinanceIndexes(m);
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
          from3To4: (m, schema) async {
            // v3→v4: FinancialTransaction.categoryId/accountId 补外键（P0-5）。
            // SQLite 无法直接 ALTER ADD FOREIGN KEY，需重建表。重建前先清洗孤儿
            // 交易（categoryId/accountId 悬空）以免数据与新约束冲突——实际用户库
            // 几乎无孤儿，此为防御性清洗（决策：删除孤儿交易）。
            await m.database.customStatement(
              'DELETE FROM financial_transaction WHERE category_id NOT IN '
              '(SELECT category_id FROM expense_categories)',
            );
            await m.database.customStatement(
              'DELETE FROM financial_transaction WHERE account_id NOT IN '
              '(SELECT account_id FROM payment_accounts)',
            );
            // 重建表以附加新 FK 约束（列集不变，TableMigration 按 1:1 列名复制）。
            await m.alterTable(
              // ignore: experimental_member_use, 给既有表加 FK 必须重建表,drift 的 TableMigration 是标准写法(无稳定替代)
              TableMigration(schema.financialTransaction),
            );
            // finance 交易索引（fresh install 走 onCreate，旧库走这里补）。
            await _createFinanceIndexes(m);
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

  /// FinancialTransaction 索引（P0-5）：loggedAt 支撑今日/本月明细按时间过滤与
  /// 排序；accountId 支撑按账户过滤的交易列表（及删账户前的引用计数查询）。
  /// 与健康索引对称：onCreate（fresh）与 from3To4（升级）都调一次，IF NOT EXISTS
  /// 幂等。
  Future<void> _createFinanceIndexes(Migrator m) async {
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ftx_logged_at '
      'ON financial_transaction(logged_at)',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ftx_account '
      'ON financial_transaction(account_id)',
    );
  }
}

QueryExecutor _openConnection() {
  return createDatabaseConnection();
}
