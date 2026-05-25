import 'package:drift/drift.dart';

import '../crypto/encryption_config.dart';
import 'database_connection.dart';
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
  AppDatabase({EncryptionConfig? encryptionConfig})
      : super(_openConnection(encryptionConfig));

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
      );
}

QueryExecutor _openConnection(EncryptionConfig? encryptionConfig) {
  final config = encryptionConfig ?? EncryptionConfig.withDefaultKey();
  return createDatabaseConnection(config);
}
