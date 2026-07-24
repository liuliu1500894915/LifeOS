import 'package:drift/drift.dart';

import 'database_connection.dart';
import 'schema_versions.dart';
import 'tables/app_defaults.dart';
import 'tables/pet_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/daily_tables.dart';
import 'tables/profile_tables.dart';
import 'tables/system_tables.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: stepByStep(
          from1To2: (m, schema) async {
            // v1→v2: only ExpenseCategories is new. The previous onUpgrade
            // re-created 8 finance tables, 7 of which already existed in v1
            // and would have raised "table already exists" on a real upgrade.
            await m.createTable(schema.expenseCategories);
          },
        ),
        beforeOpen: (details) async {
          // foreign_keys must be (re)enabled on every open — keeping it only
          // in the native connection's `setup` is unreliable across migrations
          // (blueprint §1.4 / 执行计划 §1.2).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

QueryExecutor _openConnection() {
  return createDatabaseConnection();
}
