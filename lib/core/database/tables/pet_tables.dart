import 'package:drift/drift.dart';

import 'app_defaults.dart';
import 'system_tables.dart';
import 'finance_tables.dart';

class PetStatusCore extends Table {
  TextColumn get petId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get petName =>
      text().withLength(max: 50).withDefault(const Constant('小生活'))();
  TextColumn get speciesType => text().check(
        speciesType.equals('CAT') |
        speciesType.equals('DOG') |
        speciesType.equals('RABBIT') |
        speciesType.equals('DRAGON'),
      )();
  TextColumn get growthStage => text().check(
        growthStage.equals('EGG') |
        growthStage.equals('BABY') |
        growthStage.equals('TEEN') |
        growthStage.equals('ADULT') |
        growthStage.equals('LEGEND'),
      )();
  IntColumn get hydrationPoints =>
      integer().withDefault(const Constant(AppDefaults.maxHydrationPoints))();
  IntColumn get bodyShapePoints =>
      integer()
          .withDefault(const Constant(AppDefaults.defaultBodyShapePoints))();
  IntColumn get energyPoints =>
      integer().withDefault(const Constant(AppDefaults.maxEnergyPoints))();
  IntColumn get moodPoints =>
      integer().withDefault(const Constant(AppDefaults.maxMoodPoints))();
  TextColumn get overallStatusLevel =>
      text().withDefault(const Constant('NORMAL'))();
  IntColumn get accumulatedDays => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {petId};
}

class PetActionQuickLog extends Table {
  TextColumn get logId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get actionType => text().check(
        actionType.equals('FEED') |
        actionType.equals('DRINK') |
        actionType.equals('SPORT') |
        actionType.equals('REST'),
      )();
  RealColumn get valueNumeric => real()();
  TextColumn get subCategory => text().withLength(max: 100).nullable()();
  IntColumn get subjectiveScore => integer().withDefault(const Constant(0))();
  RealColumn get associatedCost => real().withDefault(const Constant(0.0))();
  TextColumn get remark => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {logId};
}

class RoomFurniturePlacement extends Table {
  TextColumn get placementId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get assetId =>
      text()
          .withLength(min: 1, max: 36)
          .references(AssetInventory, #assetId)();
  RealColumn get posX => real().withDefault(const Constant(0.0))();
  RealColumn get posY => real().withDefault(const Constant(0.0))();
  RealColumn get scale => real().withDefault(const Constant(1.0))();
  IntColumn get zIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {placementId};
}
