import 'package:drift/drift.dart';

/// 宠物状态核心表
class PetStatusCore extends Table {
  TextColumn get petId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get petName => text().withLength(max: 50).withDefault(const Constant('小生活'))();
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
  IntColumn get hydrationPoints => integer().withDefault(const Constant(100))();
  IntColumn get bodyShapePoints => integer().withDefault(const Constant(0))();
  IntColumn get energyPoints => integer().withDefault(const Constant(100))();
  IntColumn get moodPoints => integer().withDefault(const Constant(100))();
  TextColumn get overallStatusLevel => text().withDefault(const Constant('NORMAL'))();
  IntColumn get accumulatedDays => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {petId};
}

/// 宠物快捷操作流水表
class PetActionQuickLog extends Table {
  TextColumn get logId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
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

/// 房间家具布置表
class RoomFurniturePlacement extends Table {
  TextColumn get placementId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get assetId => text().withLength(min: 1, max: 36).nullable()();
  RealColumn get posX => real().withDefault(const Constant(0.0))();
  RealColumn get posY => real().withDefault(const Constant(0.0))();
  RealColumn get scale => real().withDefault(const Constant(1.0))();
  IntColumn get zIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {placementId};
}

/// 用户基础档案表
class UserProfile extends Table {
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get displayName => text().withLength(max: 50).nullable()();
  TextColumn get motto => text().withLength(max: 200).nullable()();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get gender => text().check(
        gender.equals('MALE') | gender.equals('FEMALE') | gender.equals('OTHER'),
      ).nullable()();
  RealColumn get heightCm => real().nullable()();
  RealColumn get weightKg => real().nullable()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get bloodType => text().withLength(max: 5).nullable()();
  TextColumn get emergencyContact => text().withLength(max: 50).nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId};
}

/// 体重变化历史表
class WeightHistory extends Table {
  TextColumn get recordId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  RealColumn get weightKg => real()();
  DateTimeColumn get recordedDate => dateTime()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get note => text().withLength(max: 200).nullable()();

  @override
  Set<Column> get primaryKey => {recordId};

  @override
  List<String> get customConstraints => ['UNIQUE(user_id, recorded_date)'];
}
