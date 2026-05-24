import 'package:drift/drift.dart';

/// 安全证件资产表
class SecureDocumentsVault extends Table {
  TextColumn get docId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get docType => text().check(
        docType.equals('PASSPORT') |
        docType.equals('ID_CARD') |
        docType.equals('DRIVER_LICENSE') |
        docType.equals('OTHER'),
      )();
  BlobColumn get encryptedNumberBlob => blob()();
  DateTimeColumn get expiryDate => dateTime()();
  IntColumn get alertOffsetDays => integer().withDefault(const Constant(30))();
  BoolColumn get requiresFaceIdSecondary => boolean().withDefault(const Constant(true))();
  BoolColumn get localOnlyIslandFlag => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {docId};
}

/// 纪念日表
class MemorialDays extends Table {
  TextColumn get memorialId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get calendarType => text().check(
        calendarType.equals('SOLAR') | calendarType.equals('LUNAR'),
      )();
  IntColumn get monthValue => integer()();
  IntColumn get dayValue => integer()();
  IntColumn get advanceDaysTodo => integer().withDefault(const Constant(7))();
  RealColumn get giftBudgetAmount => real().nullable()();
  IntColumn get giftBudgetLockDays => integer().withDefault(const Constant(15))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {memorialId};
}

/// 人际关系网络表
class RelationshipNetwork extends Table {
  TextColumn get contactId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get name => text().withLength(max: 50)();
  TextColumn get relationType => text().withLength(max: 30).nullable()();
  DateTimeColumn get lastInteractionDate => dateTime().nullable()();
  IntColumn get crisisThresholdDays => integer().withDefault(const Constant(14))();
  IntColumn get warmthScore => integer().withDefault(const Constant(100))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {contactId};
}

/// 人际交往日志表
class RelationshipInteractionLog extends Table {
  TextColumn get interactionId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get contactId => text().withLength(min: 1, max: 36)();
  DateTimeColumn get interactionDate => dateTime()();
  TextColumn get content => text().nullable()();
  IntColumn get warmthResetValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => {interactionId};
}
