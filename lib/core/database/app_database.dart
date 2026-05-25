import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../crypto/encryption_config.dart';
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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
      );
}

LazyDatabase _openConnection(EncryptionConfig? encryptionConfig) {
  final config = encryptionConfig ?? EncryptionConfig.withDefaultKey();

  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = p.join(dbFolder.path, 'life_os.db');

    return NativeDatabase.createInBackground(
      File(file),
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '${config.key}'");
        rawDb.execute('PRAGMA cipher_page_size = ${EncryptionConfig.pageSize}');
        rawDb.execute('PRAGMA kdf_iter = ${EncryptionConfig.kdfIter}');
        rawDb.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
        rawDb.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
        rawDb.execute('PRAGMA foreign_keys = ON');
        rawDb.execute('PRAGMA journal_mode = WAL');
        rawDb.execute('PRAGMA busy_timeout = 5000');
      },
    );
  });
}
