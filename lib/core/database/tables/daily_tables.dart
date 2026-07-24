import 'package:drift/drift.dart';

import 'system_tables.dart';

class TodoExecutionList extends Table {
  TextColumn get todoId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
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
  TextColumn get associatedFlagId =>
      text()
          .withLength(min: 1, max: 36)
          .references(FlagGoals, #flagId)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {todoId};
}

class HabitDefinitions extends Table {
  TextColumn get habitId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
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

class HabitCheckLog extends Table {
  TextColumn get logId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get habitId =>
      text()
          .withLength(min: 1, max: 36)
          .references(HabitDefinitions, #habitId)();
  DateTimeColumn get checkDate => dateTime()();
  RealColumn get achievedValue => real().nullable()();
  BoolColumn get isFrozen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {logId};

  @override
  List<String> get customConstraints => ['UNIQUE(habit_id, check_date)'];
}

class FlagGoals extends Table {
  TextColumn get flagId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
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

class FlagMilestones extends Table {
  TextColumn get milestoneId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get flagId =>
      text()
          .withLength(min: 1, max: 36)
          .references(FlagGoals, #flagId)();
  TextColumn get title => text().withLength(max: 150)();
  RealColumn get targetValue => real().nullable()();
  BoolColumn get isReached => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reachedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {milestoneId};
}

class DailyReviewLog extends Table {
  DateTimeColumn get reviewDate => dateTime()();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get moodTag => text()();
  TextColumn get insightsContent => text().nullable()();
  TextColumn get summarySnapshotJson => text()();

  @override
  Set<Column> get primaryKey => {reviewDate, userId};
}

/// 生活瞬间（P4-1）—— 白天随手记录的微日记：一段文字 + 心情 + 多张照片。
/// 一对多照片走子表 [MomentPhoto]（单一真相、可排序），不把路径塞 JSON。
/// 与 [DailyReviewLog] 同属「每日」模块但数据分离：瞬间是随手记，复盘是结构化总结。
class LifeMoment extends Table {
  TextColumn get momentId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  // 内容可空：允许「纯照片」瞬间。
  TextColumn get content => text().withLength(max: 2000).nullable()();
  // 心情存 emoji/短文本（如 '😌'），与 DailyReviewLog.moodTag 同为自由文本。
  TextColumn get moodTag => text().withLength(max: 20).nullable()();
  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {momentId};
}

/// 瞬间照片（P4-1）—— 一对多子表。photoPath 存 App 文档目录绝对路径，DB 不存二进制
/// （SQLCipher 只加密库本身，照片文件本身不加密；见蓝图 §D/§3 照片一致性）。
/// momentId 用 ON DELETE CASCADE：删瞬间自动级联删其照片记录；磁盘文件由
/// Repository 删行后 best-effort 清理（见 moment_photo_store.dart）。
/// sortOrder 维持用户选择的展示顺序。
class MomentPhoto extends Table {
  TextColumn get photoId => text().withLength(min: 1, max: 36)();
  TextColumn get momentId =>
      text()
          .withLength(min: 1, max: 36)
          .references(LifeMoment, #momentId,
              onDelete: KeyAction.cascade)();
  TextColumn get photoPath => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {photoId};
}
