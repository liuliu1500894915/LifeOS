import 'package:drift/drift.dart';

import 'app_defaults.dart';
import 'system_tables.dart';

class FinancialTransaction extends Table {
  TextColumn get transactionId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get flowType => text().check(
        flowType.equals('INCOME') |
        flowType.equals('EXPENSE') |
        flowType.equals('TRANSFER'),
      )();
  RealColumn get amount => real()();
  TextColumn get categoryId => text().withLength(max: 50)();
  TextColumn get accountId => text().withLength(max: 50)();
  TextColumn get remark => text().withLength(max: 150).nullable()();
  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {transactionId};
}

class AssetInventory extends Table {
  TextColumn get assetId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get assetName => text().withLength(max: 100)();
  RealColumn get purchasePrice => real()();
  DateTimeColumn get purchaseDate => dateTime()();
  TextColumn get iconId => text().withLength(max: 50)();
  BoolColumn get projectToRoom => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {assetId};
}

class PaymentAccounts extends Table {
  TextColumn get accountId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get accountName => text().withLength(max: 50)();
  TextColumn get accountType => text().check(
        accountType.equals('CASH') |
        accountType.equals('DEBIT') |
        accountType.equals('CREDIT') |
        accountType.equals('INVESTMENT'),
      )();
  BoolColumn get isLiability => boolean().withDefault(const Constant(false))();
  RealColumn get balance =>
      real().withDefault(const Constant(AppDefaults.defaultBalance))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {accountId};
}

class SubscriptionServices extends Table {
  TextColumn get subscriptionId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get serviceName => text().withLength(max: 100)();
  RealColumn get amount => real()();
  TextColumn get billingCycle => text().check(
        billingCycle.equals('MONTHLY') |
        billingCycle.equals('QUARTERLY') |
        billingCycle.equals('YEARLY'),
      )();
  DateTimeColumn get nextBillingDate => dateTime()();
  TextColumn get accountId =>
      text()
          .withLength(min: 1, max: 36)
          .references(PaymentAccounts, #accountId)();
  BoolColumn get alertEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {subscriptionId};
}

class BudgetSettings extends Table {
  TextColumn get budgetId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get categoryId => text().withLength(max: 50)();
  TextColumn get monthKey => text().withLength(min: 1, max: 7)();
  RealColumn get budgetAmount => real()();
  RealColumn get reservedAmount =>
      real().withDefault(const Constant(AppDefaults.defaultReservedAmount))();

  @override
  Set<Column> get primaryKey => {budgetId};

  @override
  List<String> get customConstraints =>
      ['UNIQUE(user_id, category_id, month_key)'];
}

class ExpenseCategories extends Table {
  TextColumn get categoryId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  TextColumn get categoryName => text().withLength(max: 50)();
  TextColumn get categoryIcon => text().withLength(max: 10)();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {categoryId};
}

class AssetValueSnapshots extends Table {
  TextColumn get snapshotId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text()
          .withLength(min: 1, max: 36)
          .references(UserAccounts, #userId)();
  DateTimeColumn get snapshotDate => dateTime()();
  RealColumn get totalAssetValue => real().withDefault(const Constant(0.0))();
  RealColumn get totalLiabilityValue =>
      real().withDefault(const Constant(0.0))();
  RealColumn get netWorth => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {snapshotId};

  @override
  List<String> get customConstraints => ['UNIQUE(user_id, snapshot_date)'];
}
