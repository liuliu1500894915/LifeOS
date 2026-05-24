import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/pet_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/daily_tables.dart';
import 'tables/profile_tables.dart';
import 'tables/system_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Pet & Home
    PetStatusCore,
    PetActionQuickLog,
    RoomFurniturePlacement,
    UserProfile,
    WeightHistory,
    // Finance
    FinancialTransaction,
    AssetInventory,
    PaymentAccounts,
    SubscriptionServices,
    BudgetSettings,
    AssetValueSnapshots,
    // Daily
    TodoExecutionList,
    HabitDefinitions,
    HabitCheckLog,
    FlagGoals,
    FlagMilestones,
    DailyReviewLog,
    // Profile
    SecureDocumentsVault,
    MemorialDays,
    RelationshipNetwork,
    RelationshipInteractionLog,
    // System
    UserAccounts,
    AnalyticalInsights,
    DailyAggregationCache,
    BackgroundWorkerLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = p.join(dbFolder.path, 'life_os.db');

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // Enable SQLCipher encryption with a default key
        // Key will be derived from biometric auth + device ID in production
        rawDb.execute("PRAGMA key = 'life_os_v1_encryption_key'");
        rawDb.execute("PRAGMA cipher_page_size = 4096");
        rawDb.execute("PRAGMA kdf_iter = 256000");
        rawDb.execute("PRAGMA cipher_hmac_algorithm = HMAC_SHA512");
        rawDb.execute("PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512");
      },
    );
  });
}
