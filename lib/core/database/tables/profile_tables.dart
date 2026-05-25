import 'package:drift/drift.dart';

import 'app_defaults.dart';
import 'system_tables.dart';

class UserProfile extends Table {
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get motto => text().withLength(max: 200).nullable()();
  TextColumn get gender => text().check(
        gender.equals('MALE') |
        gender.equals('FEMALE') |
        gender.equals('OTHER'),
      ).nullable()();
  RealColumn get heightCm => real().nullable()();
  RealColumn get weightKg => real().nullable()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get bloodType => text().withLength(max: 5).nullable()();
  TextColumn get emergencyContact => text().withLength(max: 50).nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId};
}

class WeightHistory extends Table {
  TextColumn get recordId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  RealColumn get weightKg => real()();
  DateTimeColumn get recordedDate => dateTime()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get note => text().withLength(max: 200).nullable()();

  @override
  Set<Column> get primaryKey => {recordId};

  @override
  List<String> get customConstraints => ['UNIQUE(user_id, recorded_date)'];
}

class SecureDocumentsVault extends Table {
  TextColumn get docId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get docType => text().check(
        docType.equals('PASSPORT') |
        docType.equals('ID_CARD') |
        docType.equals('DRIVER_LICENSE') |
        docType.equals('OTHER'),
      )();
  BlobColumn get encryptedNumberBlob => blob()();
  DateTimeColumn get expiryDate => dateTime()();
  IntColumn get alertOffsetDays =>
      integer().withDefault(const Constant(AppDefaults.defaultAlertOffsetDays))();
  BoolColumn get requiresFaceIdSecondary =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get localOnlyIslandFlag =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {docId};
}

class MemorialDays extends Table {
  TextColumn get memorialId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get calendarType => text().check(
        calendarType.equals('SOLAR') | calendarType.equals('LUNAR'),
      )();
  IntColumn get monthValue => integer()();
  IntColumn get dayValue => integer()();
  IntColumn get advanceDaysTodo =>
      integer().withDefault(const Constant(AppDefaults.defaultAdvanceDaysTodo))();
  RealColumn get giftBudgetAmount => real().nullable()();
  IntColumn get giftBudgetLockDays =>
      integer()
          .withDefault(const Constant(AppDefaults.defaultGiftBudgetLockDays))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {memorialId};
}

class RelationshipNetwork extends Table {
  TextColumn get contactId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get name => text().withLength(max: 50)();
  TextColumn get relationType => text().withLength(max: 30).nullable()();
  DateTimeColumn get lastInteractionDate => dateTime().nullable()();
  IntColumn get crisisThresholdDays =>
      integer()
          .withDefault(const Constant(AppDefaults.defaultCrisisThresholdDays))();
  IntColumn get warmthScore =>
      integer().withDefault(const Constant(AppDefaults.defaultWarmthScore))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {contactId};
}

class RelationshipInteractionLog extends Table {
  TextColumn get interactionId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get contactId =>
      text()
          .withLength(min: 1, max: 36)
          .references(RelationshipNetwork, #contactId)();
  DateTimeColumn get interactionDate => dateTime()();
  TextColumn get content => text().nullable()();
  IntColumn get warmthResetValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => {interactionId};
}
