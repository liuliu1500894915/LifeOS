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
    // P0-5:删账户前校验关联交易/订阅 —— 有引用则抛 EntityInUseException,
    // 既给 UI 友好提示,也避免 FK RESTRICT 抛底层错。
    final blocking = await _blockingReasonForAccount(accountId);
    if (blocking != null) {
      throw EntityInUseException(blocking);
    }
    await (_db.delete(_db.paymentAccounts)
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }

  /// 返回阻止删除该账户的原因(关联交易/订阅数),无引用则返回 null。
  /// 用 COUNT 聚合而非"先全表 get 再 Dart 过滤"(执行计划铁律)。
  Future<String?> _blockingReasonForAccount(String accountId) async {
    final txCount = (await _db.customSelect(
      'SELECT COUNT(*) AS c FROM financial_transaction WHERE account_id = ?',
      variables: [Variable.withString(accountId)],
    ).getSingle()).read<int>('c');
    if (txCount > 0) {
      return '该账户有 $txCount 笔关联交易，请先删除或迁移这些交易后再删账户';
    }
    final subCount = (await _db.customSelect(
      'SELECT COUNT(*) AS c FROM subscription_services WHERE account_id = ?',
      variables: [Variable.withString(accountId)],
    ).getSingle()).read<int>('c');
    if (subCount > 0) {
      return '该账户关联了 $subCount 个订阅，请先处理后再删账户';
    }
    return null;
  }

  // ── 交易 ──

  @override
  Stream<List<FinancialTransactionData>> watchTransactions() =>
      (_db.select(_db.financialTransaction)
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .watch();

  @override
  Stream<List<TransactionWithCategory>> watchTransactionsWithCategory() {
    // P0-5:交易列表分类名/账户名来自 DB join(expense_categories +
    // payment_accounts),而非硬编码 categoryForId。innerJoin 安全 —— 加 FK 后
    // 交易必然有有效分类/账户(RESTRICT 拦截删除),不会漏行。
    final tx = _db.financialTransaction;
    final cat = _db.expenseCategories;
    final acc = _db.paymentAccounts;
    final query = _db.select(tx).join([
          innerJoin(cat, cat.categoryId.equalsExp(tx.categoryId)),
          innerJoin(acc, acc.accountId.equalsExp(tx.accountId)),
        ])
          ..orderBy([OrderingTerm.desc(tx.loggedAt)]);
    return query
        .map(
          (row) => TransactionWithCategory(
            transactionId: row.read(tx.transactionId)!,
            flowType: row.read(tx.flowType)!,
            amount: row.read(tx.amount)!,
            categoryId: row.read(tx.categoryId)!,
            categoryName: row.read(cat.categoryName)!,
            categoryIcon: row.read(cat.categoryIcon)!,
            accountId: row.read(tx.accountId)!,
            accountName: row.read(acc.accountName)!,
            remark: row.read(tx.remark),
            loggedAt: row.read(tx.loggedAt)!,
          ),
        )
        .watch();
  }

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
    String expenseNature = 'SPOT',
    DateTime? amortizeStart,
    DateTime? amortizeEnd,
    String? sourceSubscriptionId,
  }) async {
    // P1-2:AMORTIZED 必须带合法覆盖区间(含头含尾,end >= start),
    // 否则摊销算法(§3.3)无区间可摊。SPOT 则区间应为空。校验放 data 层做
    // 防御性兜底(调用方/UI 也会前置校验,但这里保证不写脏数据入库)。
    if (expenseNature == 'AMORTIZED') {
      if (amortizeStart == null || amortizeEnd == null) {
        throw ArgumentError('AMORTIZED 交易必须填写覆盖起止日期');
      }
      final start = _dateOnly(amortizeStart);
      final end = _dateOnly(amortizeEnd);
      if (end.isBefore(start)) {
        throw ArgumentError('AMORTIZED 交易覆盖结束日期不能早于开始日期');
      }
    }

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
              // 摊销区间截断到本地日零点(与 domain §3.3 同口径),避免时分秒导致
              // 边界错位。SPOT 时两值均 null。
              expenseNature: Value(expenseNature),
              amortizeStartDate: amortizeStart == null
                  ? const Value.absent()
                  : Value(_dateOnly(amortizeStart)),
              amortizeEndDate: amortizeEnd == null
                  ? const Value.absent()
                  : Value(_dateOnly(amortizeEnd)),
              sourceSubscriptionId: Value(sourceSubscriptionId),
            ),
          );
      // 余额增量用 SQL 表达式,原子且避免"先读再写回"的竞态。
      // 用 customUpdate(非 customStatement)声明受影响表 —— Drift 的 .watch() 流
      // (watchAccounts)才会在事务 commit 后重发,余额 UI 无需手动 invalidate。
      // 注意:无论 SPOT 还是 AMORTIZED,余额都按**全额**扣减(现金流不变),
      // 摊销只影响分析口径(P1-5)。
      await _db.customUpdate(
        'UPDATE payment_accounts SET balance = balance + ? WHERE account_id = ?',
        variables: [Variable.withReal(delta), Variable.withString(accountId)],
        updates: {_db.paymentAccounts},
      );
    });
  }

  /// 把 [DateTime] 截断到本地日零点(仅保留年月日)。
  ///
  /// 与 domain/amortization.dart 的 `_dateOnly`、midnight_settlement 同口径(风险 §5.6)。
  /// 摊销区间按「日」存储,统一截断避免时分秒边界错位。
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

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
    // P0-5:删分类前校验关联交易 —— 有引用则抛 EntityInUseException,
    // 与 FK RESTRICT 一致(被引用的分类不可删)。
    final txCount = (await _db.customSelect(
      'SELECT COUNT(*) AS c FROM financial_transaction WHERE category_id = ?',
      variables: [Variable.withString(categoryId)],
    ).getSingle()).read<int>('c');
    if (txCount > 0) {
      throw EntityInUseException('该分类有 $txCount 笔关联交易，请先删除或迁移这些交易后再删分类');
    }
    await (_db.delete(_db.expenseCategories)
          ..where((t) => t.categoryId.equals(categoryId)))
        .go();
  }
}

/// Repository 的 Riverpod 入口;Provider 依赖此 [FinanceRepository] 接口。
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepositoryDrift(ref.read(databaseProvider));
});
