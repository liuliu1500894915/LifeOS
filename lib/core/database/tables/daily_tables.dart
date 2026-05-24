import 'package:drift/drift.dart';

/// 待办清单执行表
class TodoExecutionList extends Table {
  TextColumn get todoId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get title => text().withLength(max: 150)();
  TextColumn get priorityQuadrant => text().check(
        priorityQuadrant.equals('A') |
        priorityQuadrant.equals('B') |
        priorityQuadrant.equals('C') |
        priorityQuadrant.equals('D'),
      )();
  DateTimeColumn get targetDate => dateTime()();
  DateTimeColumn get reminderClock => dateTime().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get delayCount => integer().withDefault(const Constant(0))();
  TextColumn get associatedFlagId => text().withLength(min: 1, max: 36).nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {todoId};
}

/// 习惯定义表
class HabitDefinitions extends Table {
  TextColumn get habitId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get habitName => text().withLength(max: 100)();
  TextColumn get habitIcon => text().withLength(max: 10).nullable()();
  TextColumn get targetType => text().check(
        targetType.equals('BOOLEAN') | targetType.equals('NUMERIC'),
      )();
  RealColumn get targetValue => real().nullable()();
  TextColumn get targetUnit => text().withLength(max: 20).nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {habitId};
}

/// 习惯打卡记录表
class HabitCheckLog extends Table {
  TextColumn get logId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get habitId => text().withLength(min: 1, max: 36)();
  DateTimeColumn get checkDate => dateTime()();
  RealColumn get achievedValue => real().nullable()();
  BoolColumn get isFrozen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {logId};

  @override
  List<String> get customConstraints => ['UNIQUE(habit_id, check_date)'];
}

/// 长期 Flag 目标表
class FlagGoals extends Table {
  TextColumn get flagId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get title => text().withLength(max: 150)();
  TextColumn get description => text().nullable()();
  RealColumn get targetValue => real().nullable()();
  RealColumn get currentValue => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text().withLength(max: 20).nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {flagId};
}

/// Flag 里程碑表
class FlagMilestones extends Table {
  TextColumn get milestoneId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get flagId => text().withLength(min: 1, max: 36)();
  TextColumn get title => text().withLength(max: 150)();
  RealColumn get targetValue => real().nullable()();
  BoolColumn get isReached => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reachedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {milestoneId};
}

/// 每日复盘日志表
class DailyReviewLog extends Table {
  DateTimeColumn get reviewDate => dateTime()();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get moodTag => text()();
  TextColumn get insightsContent => text().nullable()();
  TextColumn get summarySnapshotJson => text()();

  @override
  Set<Column> get primaryKey => {reviewDate, userId};
}
