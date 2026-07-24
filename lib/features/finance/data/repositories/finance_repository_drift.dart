import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../category_seeds.dart';
import 'finance_repository.dart';

const _uuid = Uuid();

/// [FinanceRepository] 的 Drift 实现:所有 SQL 集中于此。
///
/// 读用 `.watch()`/`.get()`,写用 `Future`,事务性写包 `db.transaction`,
/// 余额累加用 SQL 表达式(`balance = balance + ?`)而非"先读再写回"。
/// 不再调用 `_ensureSystemUser` —— 系统用户由 [SystemBootstrap] 在启动时
/// 一次性确保(见 system_bootstrap.dart)。
class FinanceRepositoryDrift implements FinanceRepository {
  FinanceRepositoryDrift(this._db);

  final AppDatabase _db;

  // ── 账户 ──

  @override
  Stream<List<PaymentAccount>> watchAccounts() =>
      (_db.select(_db.paymentAccounts)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  @override
  Future<List<PaymentAccount>> getAccounts() =>
      (_db.select(_db.paymentAccounts)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  @override
  Future<void> ensureAccountsSeeded() async {
    const defaults = [
      ('微信支付', 'CASH', false, 0.0),
      ('支付宝', 'CASH', false, 0.0),
      ('银行卡', 'DEBIT', false, 0.0),
      ('花呗', 'CREDIT', true, 0.0),
    ];
    for (var i = 0; i < defaults.length; i++) {
      final d = defaults[i];
      await _db.into(_db.paymentAccounts).insert(
            PaymentAccountsCompanion.insert(
              accountId: _uuid.v4(),
              userId: systemUserId,
              accountName: d.$1,
              accountType: d.$2,
              isLiability: Value(d.$3),
              balance: Value(d.$4),
              sortOrder: Value(i),
            ),
          );
    }
  }

  @override
  Future<void> addAccount(String name, String type, bool isLiability, double balance) async {
    final maxSort = await (_db.select(_db.paymentAccounts)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    await _db.into(_db.paymentAccounts).insert(
          PaymentAccountsCompanion.insert(
            accountId: _uuid.v4(),
            userId: systemUserId,
            accountName: name,
            accountType: type,
            isLiability: Value(isLiability),
            balance: Value(balance),
            sortOrder: Value((maxSort?.sortOrder ?? -1) + 1),
          ),
        );
  }

  @override
  Future<void> updateAccount(String accountId, {String? name, double? balance}) async {
    await (_db.update(_db.paymentAccounts)
          ..where((t) => t.accountId.equals(accountId)))
        .write(
      PaymentAccountsCompanion(
        accountName: name != null ? Value(name) : const Value.absent(),
        balance: balance != null ? Value(balance) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    await (_db.delete(_db.paymentAccounts)
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }

  // ── 交易 ──

  @override
  Stream<List<FinancialTransactionData>> watchTransactions() =>
      (_db.select(_db.financialTransaction)
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .watch();

  @override
  Future<List<FinancialTransactionData>> getTransactions() =>
      (_db.select(_db.financialTransaction)
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .get();

  @override
  Future<void> addTransaction({
    required String flowType,
    required double amount,
    required String categoryId,
    required String accountId,
    String? remark,
    DateTime? loggedAt,
  }) async {
    final dt = loggedAt ?? DateTime.now();
    final delta = flowType == 'EXPENSE' ? -amount : amount;
    await _db.transaction(() async {
      await _db.into(_db.financialTransaction).insert(
            FinancialTransactionCompanion.insert(
              transactionId: _uuid.v4(),
              userId: systemUserId,
              flowType: flowType,
              amount: amount,
              categoryId: categoryId,
              accountId: accountId,
              remark: Value(remark),
              loggedAt: dt,
            ),
          );
      // 余额增量用 SQL 表达式,原子且避免"先读再写回"的竞态。
      // 用 customUpdate(非 customStatement)声明受影响表 —— Drift 的 .watch() 流
      // (watchAccounts)才会在事务 commit 后重发,余额 UI 无需手动 invalidate。
      await _db.customUpdate(
        'UPDATE payment_accounts SET balance = balance + ? WHERE account_id = ?',
        variables: [Variable.withReal(delta), Variable.withString(accountId)],
        updates: {_db.paymentAccounts},
      );
    });
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final tx = await (_db.select(_db.financialTransaction)
          ..where((t) => t.transactionId.equals(transactionId)))
        .getSingleOrNull();
    if (tx == null) return;
    final delta = tx.flowType == 'EXPENSE' ? tx.amount : -tx.amount;
    await _db.transaction(() async {
      await (_db.delete(_db.financialTransaction)
            ..where((t) => t.transactionId.equals(transactionId)))
          .go();
      // customUpdate 声明受影响表,使 watchAccounts 流在 commit 后重发(见上)。
      await _db.customUpdate(
        'UPDATE payment_accounts SET balance = balance + ? WHERE account_id = ?',
        variables: [Variable.withReal(delta), Variable.withString(tx.accountId)],
        updates: {_db.paymentAccounts},
      );
    });
  }

  // ── 资产 ──

  @override
  Stream<List<AssetInventoryData>> watchAssets() => _db.select(_db.assetInventory).watch();

  @override
  Future<List<AssetInventoryData>> getAssets() => _db.select(_db.assetInventory).get();

  @override
  Future<void> addAsset({
    required String name,
    required double price,
    required DateTime purchaseDate,
    required String iconId,
    bool projectToRoom = true,
  }) async {
    await _db.into(_db.assetInventory).insert(
          AssetInventoryCompanion.insert(
            assetId: _uuid.v4(),
            userId: systemUserId,
            assetName: name,
            purchasePrice: price,
            purchaseDate: purchaseDate,
            iconId: iconId,
            projectToRoom: Value(projectToRoom),
          ),
        );
  }

  @override
  Future<void> updateAsset(
    String assetId, {
    String? name,
    double? price,
    DateTime? purchaseDate,
    String? iconId,
    bool? projectToRoom,
  }) async {
    await (_db.update(_db.assetInventory)
          ..where((t) => t.assetId.equals(assetId)))
        .write(
      AssetInventoryCompanion(
        assetName: name != null ? Value(name) : const Value.absent(),
        purchasePrice: price != null ? Value(price) : const Value.absent(),
        purchaseDate: purchaseDate != null ? Value(purchaseDate) : const Value.absent(),
        iconId: iconId != null ? Value(iconId) : const Value.absent(),
        projectToRoom: projectToRoom != null ? Value(projectToRoom) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    await (_db.delete(_db.assetInventory)..where((t) => t.assetId.equals(assetId))).go();
  }

  // ── 订阅 ──

  @override
  Stream<List<SubscriptionService>> watchSubscriptions() =>
      _db.select(_db.subscriptionServices).watch();

  @override
  Future<List<SubscriptionService>> getSubscriptions() =>
      _db.select(_db.subscriptionServices).get();

  @override
  Future<void> addSubscription({
    required String serviceName,
    required double amount,
    required String billingCycle,
    required DateTime nextBillingDate,
    required String accountId,
    bool alertEnabled = true,
  }) async {
    await _db.into(_db.subscriptionServices).insert(
          SubscriptionServicesCompanion.insert(
            subscriptionId: _uuid.v4(),
            userId: systemUserId,
            serviceName: serviceName,
            amount: amount,
            billingCycle: billingCycle,
            nextBillingDate: nextBillingDate,
            accountId: accountId,
            alertEnabled: Value(alertEnabled),
          ),
        );
  }

  @override
  Future<void> updateSubscription(
    String subscriptionId, {
    String? serviceName,
    double? amount,
    String? billingCycle,
    DateTime? nextBillingDate,
    String? accountId,
    bool? alertEnabled,
    bool? isActive,
  }) async {
    await (_db.update(_db.subscriptionServices)
          ..where((t) => t.subscriptionId.equals(subscriptionId)))
        .write(
      SubscriptionServicesCompanion(
        serviceName: serviceName != null ? Value(serviceName) : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        billingCycle: billingCycle != null ? Value(billingCycle) : const Value.absent(),
        nextBillingDate: nextBillingDate != null ? Value(nextBillingDate) : const Value.absent(),
        accountId: accountId != null ? Value(accountId) : const Value.absent(),
        alertEnabled: alertEnabled != null ? Value(alertEnabled) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> deleteSubscription(String subscriptionId) async {
    await (_db.delete(_db.subscriptionServices)
          ..where((t) => t.subscriptionId.equals(subscriptionId)))
        .go();
  }

  // ── 预算 ──

  @override
  Stream<List<BudgetSetting>> watchBudgets() => _db.select(_db.budgetSettings).watch();

  @override
  Future<List<BudgetSetting>> getBudgets() => _db.select(_db.budgetSettings).get();

  @override
  Future<void> setBudget(String monthKey, double amount) async {
    final existing = await (_db.select(_db.budgetSettings)
          ..where((t) => t.monthKey.equals(monthKey)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.budgetSettings)
            ..where((t) => t.budgetId.equals(existing.budgetId)))
          .write(BudgetSettingsCompanion(budgetAmount: Value(amount)));
    } else {
      await _db.into(_db.budgetSettings).insert(
            BudgetSettingsCompanion.insert(
              budgetId: _uuid.v4(),
              userId: systemUserId,
              categoryId: 'total',
              monthKey: monthKey,
              budgetAmount: amount,
            ),
          );
    }
  }

  // ── 分类 ──

  @override
  Stream<List<ExpenseCategory>> watchCategories() =>
      (_db.select(_db.expenseCategories)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  @override
  Future<List<ExpenseCategory>> getCategories() =>
      (_db.select(_db.expenseCategories)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  @override
  Future<void> ensureCategoriesSeeded() async {
    for (var i = 0; i < defaultCategorySeeds.length; i++) {
      final c = defaultCategorySeeds[i];
      await _db.into(_db.expenseCategories).insert(
            ExpenseCategoriesCompanion.insert(
              categoryId: c.id,
              userId: systemUserId,
              categoryName: c.name,
              categoryIcon: c.icon,
              isIncome: Value(c.isIncome),
              sortOrder: Value(i),
            ),
          );
    }
  }

  @override
  Future<void> addCategory(String name, String icon, {bool isIncome = false}) async {
    final maxSort = await (_db.select(_db.expenseCategories)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    await _db.into(_db.expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(
            categoryId: _uuid.v4(),
            userId: systemUserId,
            categoryName: name,
            categoryIcon: icon,
            isIncome: Value(isIncome),
            sortOrder: Value((maxSort?.sortOrder ?? -1) + 1),
          ),
        );
  }

  @override
  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? icon,
    bool? isIncome,
  }) async {
    await (_db.update(_db.expenseCategories)
          ..where((t) => t.categoryId.equals(categoryId)))
        .write(
      ExpenseCategoriesCompanion(
        categoryName: name != null ? Value(name) : const Value.absent(),
        categoryIcon: icon != null ? Value(icon) : const Value.absent(),
        isIncome: isIncome != null ? Value(isIncome) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    await (_db.delete(_db.expenseCategories)
          ..where((t) => t.categoryId.equals(categoryId)))
        .go();
  }
}

/// Repository 的 Riverpod 入口;Provider 依赖此 [FinanceRepository] 接口。
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepositoryDrift(ref.read(databaseProvider));
});
