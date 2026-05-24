import 'package:drift/drift.dart';

/// 多用户账户表
class UserAccounts extends Table {
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get displayName => text().withLength(max: 50)();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get pinCodeHash => text().withLength(max: 128).nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId};
}

/// 跨模块分析洞察表
class AnalyticalInsights extends Table {
  TextColumn get insightId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get insightType => text()();
  RealColumn get correlationCoefficient => real()();
  TextColumn get insightTitle => text()();
  TextColumn get summaryMarkdown => text()();
  TextColumn get jsonChartData => text()();
  DateTimeColumn get calculatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {insightId};
}

/// 每日聚合缓存表
class DailyAggregationCache extends Table {
  DateTimeColumn get cacheDate => dateTime()();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  RealColumn get totalExpense => real().withDefault(const Constant(0.0))();
  RealColumn get totalIncome => real().withDefault(const Constant(0.0))();
  IntColumn get transactionCount => integer().withDefault(const Constant(0))();
  IntColumn get todoCompletedCount => integer().withDefault(const Constant(0))();
  IntColumn get todoDelayedCount => integer().withDefault(const Constant(0))();
  RealColumn get totalCalorieIntake => real().withDefault(const Constant(0.0))();
  RealColumn get totalCalorieConsumed => real().withDefault(const Constant(0.0))();
  RealColumn get sleepHours => real().nullable()();
  TextColumn get moodLabel => text().withLength(max: 10).nullable()();
  DateTimeColumn get generatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {cacheDate, userId};
}

/// 后台 Worker 执行记录表
class BackgroundWorkerLog extends Table {
  TextColumn get workerId => text().withLength(min: 1, max: 36)();
  TextColumn get userId => text().withLength(min: 1, max: 36)();
  TextColumn get workerType => text().check(
        workerType.equals('MIDNIGHT_ROLLOVER') |
        workerType.equals('ADC_UPDATE') |
        workerType.equals('CORRELATION_ENGINE') |
        workerType.equals('SUBSCRIPTION_CHECK') |
        workerType.equals('NET_WORTH_SNAPSHOT') |
        workerType.equals('MEMORIAL_BUS') |
        workerType.equals('RELATIONSHIP_DECAY'),
      )();
  DateTimeColumn get executedAt => dateTime()();
  DateTimeColumn get targetDate => dateTime()();
  TextColumn get status => text().check(
        status.equals('SUCCESS') | status.equals('FAILED'),
      )();

  @override
  Set<Column> get primaryKey => {workerId};

  @override
  List<String> get customConstraints => ['UNIQUE(worker_type, target_date)'];
}
