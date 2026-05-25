import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

const _systemUserId = 'user-001';
const _uuid = Uuid();

// ── Category metadata ──

class CategoryMeta {
  final String id;
  final String icon;
  final String name;
  const CategoryMeta(this.id, this.icon, this.name);
}

const categoryMetaList = [
  CategoryMeta('food', '🍱', '三餐'),
  CategoryMeta('transport', '🚗', '交通'),
  CategoryMeta('entertainment', '🎉', '娱乐'),
  CategoryMeta('drink', '💧', '饮品'),
  CategoryMeta('shopping', '🛒', '购物'),
  CategoryMeta('housing', '🏠', '住房'),
  CategoryMeta('pet', '🐱', '宠物'),
  CategoryMeta('other', '⚙️', '自定义'),
  CategoryMeta('subscription', '🔄', '订阅'),
];

CategoryMeta categoryForId(String id) {
  return categoryMetaList.firstWhere((c) => c.id == id, orElse: () => const CategoryMeta('other', '⚙️', '自定义'));
}

// ── Notifiers ──

class AccountNotifier extends AsyncNotifier<List<PaymentAccount>> {
  @override
  Future<List<PaymentAccount>> build() async {
    final db = ref.read(databaseProvider);
    var accounts = await (db.select(db.paymentAccounts)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    if (accounts.isEmpty) {
      await _seedDefaults(db);
      accounts = await (db.select(db.paymentAccounts)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
    }
    return accounts;
  }

  Future<void> _seedDefaults(AppDatabase db) async {
    await _ensureSystemUser(db);
    const defaults = [
      ('微信支付', 'CASH', false, 0.0),
      ('支付宝', 'CASH', false, 0.0),
      ('银行卡', 'DEBIT', false, 0.0),
      ('花呗', 'CREDIT', true, 0.0),
    ];
    for (var i = 0; i < defaults.length; i++) {
      final d = defaults[i];
      await db.into(db.paymentAccounts).insert(
            PaymentAccountsCompanion.insert(
              accountId: _uuid.v4(),
              userId: _systemUserId,
              accountName: d.$1,
              accountType: d.$2,
              isLiability: Value(d.$3),
              balance: Value(d.$4),
              sortOrder: Value(i),
            ),
          );
    }
  }

  Future<void> _ensureSystemUser(AppDatabase db) async {
    await db.into(db.userAccounts).insert(
          UserAccountsCompanion.insert(
            userId: _systemUserId,
            displayName: '默认用户',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> addAccount(String name, String type, bool isLiability, double balance) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    final maxSort = await (db.select(db.paymentAccounts)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    await db.into(db.paymentAccounts).insert(
          PaymentAccountsCompanion.insert(
            accountId: _uuid.v4(),
            userId: _systemUserId,
            accountName: name,
            accountType: type,
            isLiability: Value(isLiability),
            balance: Value(balance),
            sortOrder: Value((maxSort?.sortOrder ?? -1) + 1),
          ),
        );
    state = AsyncData(await _fetchAll(db));
  }

  Future<void> updateAccount(String accountId, {String? name, double? balance}) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await (db.update(db.paymentAccounts)..where((t) => t.accountId.equals(accountId))).write(
      PaymentAccountsCompanion(
        accountName: name != null ? Value(name) : const Value.absent(),
        balance: balance != null ? Value(balance) : const Value.absent(),
      ),
    );
    state = AsyncData(await _fetchAll(db));
  }

  Future<void> deleteAccount(String accountId) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await (db.delete(db.paymentAccounts)..where((t) => t.accountId.equals(accountId))).go();
    state = AsyncData(await _fetchAll(db));
  }

  Future<List<PaymentAccount>> _fetchAll(AppDatabase db) async {
    return await (db.select(db.paymentAccounts)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
  }
}

class TransactionNotifier extends AsyncNotifier<List<FinancialTransactionData>> {
  @override
  Future<List<FinancialTransactionData>> build() async {
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    return await (db.select(db.financialTransaction)
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
        .get();
  }

  Future<void> addTransaction({
    required String flowType,
    required double amount,
    required String categoryId,
    required String accountId,
    String? remark,
    DateTime? loggedAt,
  }) async {
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    final dt = loggedAt ?? DateTime.now();

    await db.transaction(() async {
      await db.into(db.financialTransaction).insert(
            FinancialTransactionCompanion.insert(
              transactionId: _uuid.v4(),
              userId: _systemUserId,
              flowType: flowType,
              amount: amount,
              categoryId: categoryId,
              accountId: accountId,
              remark: Value(remark),
              loggedAt: dt,
            ),
          );

      final delta = flowType == 'EXPENSE' ? -amount : amount;
      final account = await (db.select(db.paymentAccounts)..where((t) => t.accountId.equals(accountId))).getSingleOrNull();
      if (account != null) {
        await (db.update(db.paymentAccounts)..where((t) => t.accountId.equals(accountId))).write(
          PaymentAccountsCompanion(balance: Value(account.balance + delta)),
        );
      }
    });

    ref.invalidate(accountProvider);
    state = AsyncData(await _fetchAll(db));
  }

  Future<void> deleteTransaction(String transactionId) async {
    final db = ref.read(databaseProvider);
    final tx = await (db.select(db.financialTransaction)..where((t) => t.transactionId.equals(transactionId))).getSingleOrNull();
    if (tx == null) return;

    await db.transaction(() async {
      await (db.delete(db.financialTransaction)..where((t) => t.transactionId.equals(transactionId))).go();

      final delta = tx.flowType == 'EXPENSE' ? tx.amount : -tx.amount;
      final account = await (db.select(db.paymentAccounts)..where((t) => t.accountId.equals(tx.accountId))).getSingleOrNull();
      if (account != null) {
        await (db.update(db.paymentAccounts)..where((t) => t.accountId.equals(tx.accountId))).write(
          PaymentAccountsCompanion(balance: Value(account.balance + delta)),
        );
      }
    });

    ref.invalidate(accountProvider);
    state = AsyncData(await _fetchAll(db));
  }

  Future<void> _ensureSystemUser(AppDatabase db) async {
    await db.into(db.userAccounts).insert(
          UserAccountsCompanion.insert(
            userId: _systemUserId,
            displayName: '默认用户',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<List<FinancialTransactionData>> _fetchAll(AppDatabase db) async {
    return await (db.select(db.financialTransaction)..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])).get();
  }
}

class AssetNotifier extends AsyncNotifier<List<AssetInventoryData>> {
  @override
  Future<List<AssetInventoryData>> build() async {
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    return await db.select(db.assetInventory).get();
  }

  Future<void> addAsset({required String name, required double price, required DateTime purchaseDate, required String iconId, bool projectToRoom = true}) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    await db.into(db.assetInventory).insert(
          AssetInventoryCompanion.insert(
            assetId: _uuid.v4(),
            userId: _systemUserId,
            assetName: name,
            purchasePrice: price,
            purchaseDate: purchaseDate,
            iconId: iconId,
            projectToRoom: Value(projectToRoom),
          ),
        );
    state = AsyncData(await db.select(db.assetInventory).get());
  }

  Future<void> updateAsset(String assetId, {String? name, double? price, DateTime? purchaseDate, String? iconId, bool? projectToRoom}) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await (db.update(db.assetInventory)..where((t) => t.assetId.equals(assetId))).write(
      AssetInventoryCompanion(
        assetName: name != null ? Value(name) : const Value.absent(),
        purchasePrice: price != null ? Value(price) : const Value.absent(),
        purchaseDate: purchaseDate != null ? Value(purchaseDate) : const Value.absent(),
        iconId: iconId != null ? Value(iconId) : const Value.absent(),
        projectToRoom: projectToRoom != null ? Value(projectToRoom) : const Value.absent(),
      ),
    );
    state = AsyncData(await db.select(db.assetInventory).get());
  }

  Future<void> deleteAsset(String assetId) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await (db.delete(db.assetInventory)..where((t) => t.assetId.equals(assetId))).go();
    state = AsyncData(await db.select(db.assetInventory).get());
  }

  Future<void> _ensureSystemUser(AppDatabase db) async {
    await db.into(db.userAccounts).insert(
          UserAccountsCompanion.insert(
            userId: _systemUserId,
            displayName: '默认用户',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

class SubscriptionNotifier extends AsyncNotifier<List<SubscriptionService>> {
  @override
  Future<List<SubscriptionService>> build() async {
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    return await db.select(db.subscriptionServices).get();
  }

  Future<void> addSubscription({
    required String serviceName,
    required double amount,
    required String billingCycle,
    required DateTime nextBillingDate,
    required String accountId,
    bool alertEnabled = true,
  }) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    await db.into(db.subscriptionServices).insert(
          SubscriptionServicesCompanion.insert(
            subscriptionId: _uuid.v4(),
            userId: _systemUserId,
            serviceName: serviceName,
            amount: amount,
            billingCycle: billingCycle,
            nextBillingDate: nextBillingDate,
            accountId: accountId,
            alertEnabled: Value(alertEnabled),
          ),
        );
    state = AsyncData(await db.select(db.subscriptionServices).get());
  }

  Future<void> updateSubscription(String subscriptionId, {String? serviceName, double? amount, String? billingCycle, DateTime? nextBillingDate, String? accountId, bool? alertEnabled, bool? isActive}) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await (db.update(db.subscriptionServices)..where((t) => t.subscriptionId.equals(subscriptionId))).write(
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
    state = AsyncData(await db.select(db.subscriptionServices).get());
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await (db.delete(db.subscriptionServices)..where((t) => t.subscriptionId.equals(subscriptionId))).go();
    state = AsyncData(await db.select(db.subscriptionServices).get());
  }

  Future<void> _ensureSystemUser(AppDatabase db) async {
    await db.into(db.userAccounts).insert(
          UserAccountsCompanion.insert(
            userId: _systemUserId,
            displayName: '默认用户',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

class BudgetNotifier extends AsyncNotifier<List<BudgetSetting>> {
  @override
  Future<List<BudgetSetting>> build() async {
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    return await db.select(db.budgetSettings).get();
  }

  Future<void> setBudget(String monthKey, double amount) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    await _ensureSystemUser(db);
    final existing = await (db.select(db.budgetSettings)..where((t) => t.monthKey.equals(monthKey))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.budgetSettings)..where((t) => t.budgetId.equals(existing.budgetId))).write(
        BudgetSettingsCompanion(budgetAmount: Value(amount)),
      );
    } else {
      await db.into(db.budgetSettings).insert(
            BudgetSettingsCompanion.insert(
              budgetId: _uuid.v4(),
              userId: _systemUserId,
              categoryId: 'total',
              monthKey: monthKey,
              budgetAmount: amount,
            ),
          );
    }
    state = AsyncData(await db.select(db.budgetSettings).get());
  }

  Future<void> _ensureSystemUser(AppDatabase db) async {
    await db.into(db.userAccounts).insert(
          UserAccountsCompanion.insert(
            userId: _systemUserId,
            displayName: '默认用户',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

// ── Providers ──

final accountProvider = AsyncNotifierProvider<AccountNotifier, List<PaymentAccount>>(
  AccountNotifier.new,
);

final transactionProvider = AsyncNotifierProvider<TransactionNotifier, List<FinancialTransactionData>>(
  TransactionNotifier.new,
);

final assetProvider = AsyncNotifierProvider<AssetNotifier, List<AssetInventoryData>>(
  AssetNotifier.new,
);

final subscriptionProvider = AsyncNotifierProvider<SubscriptionNotifier, List<SubscriptionService>>(
  SubscriptionNotifier.new,
);

final budgetProvider = AsyncNotifierProvider<BudgetNotifier, List<BudgetSetting>>(
  BudgetNotifier.new,
);

// ── Derived providers ──

DateTime _todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _monthStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
}

final todayTransactionsProvider = Provider<List<FinancialTransactionData>>((ref) {
  final asyncTxs = ref.watch(transactionProvider);
  final start = _todayStart();
  final end = start.add(const Duration(days: 1));
  return asyncTxs.whenOrNull(data: (txs) => txs.where((t) => !t.loggedAt.isBefore(start) && t.loggedAt.isBefore(end)).toList()) ?? [];
});

final monthTransactionsProvider = Provider<List<FinancialTransactionData>>((ref) {
  final asyncTxs = ref.watch(transactionProvider);
  final start = _monthStart();
  final end = DateTime(start.year, start.month + 1, 1);
  return asyncTxs.whenOrNull(data: (txs) => txs.where((t) => !t.loggedAt.isBefore(start) && t.loggedAt.isBefore(end)).toList()) ?? [];
});

final todayExpenseProvider = Provider<double>((ref) {
  final txs = ref.watch(todayTransactionsProvider);
  return txs.where((t) => t.flowType == 'EXPENSE').fold<double>(0, (s, t) => s + t.amount);
});

final monthExpenseProvider = Provider<double>((ref) {
  final txs = ref.watch(monthTransactionsProvider);
  return txs.where((t) => t.flowType == 'EXPENSE').fold<double>(0, (s, t) => s + t.amount);
});

final netWorthProvider = Provider<double>((ref) {
  final asyncAccounts = ref.watch(accountProvider);
  final asyncAssets = ref.watch(assetProvider);

  final accountBalance = asyncAccounts.whenOrNull(data: (accounts) => accounts.fold<double>(0, (s, a) => s + (a.isLiability ? -a.balance : a.balance))) ?? 0;
  final assetValue = asyncAssets.whenOrNull(data: (assets) => assets.fold<double>(0, (s, a) => s + a.purchasePrice)) ?? 0;

  return accountBalance + assetValue;
});

final totalLiabilityProvider = Provider<double>((ref) {
  final asyncAccounts = ref.watch(accountProvider);
  return asyncAccounts.whenOrNull(data: (accounts) => accounts.where((a) => a.isLiability).fold<double>(0, (s, a) => s + a.balance.abs())) ?? 0;
});

final monthBudgetProvider = Provider<double>((ref) {
  final asyncBudgets = ref.watch(budgetProvider);
  final now = DateTime.now();
  final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final budget = asyncBudgets.whenOrNull(data: (budgets) => budgets.where((b) => b.monthKey == monthKey).firstOrNull);
  return budget?.budgetAmount ?? 0;
});

/// Per-day expense amounts for the current month, keyed by day-of-month.
final monthDailyExpenseProvider = Provider<Map<int, double>>((ref) {
  final txs = ref.watch(monthTransactionsProvider);
  final result = <int, double>{};
  for (final tx in txs.where((t) => t.flowType == 'EXPENSE')) {
    final day = tx.loggedAt.day;
    result.update(day, (v) => v + tx.amount, ifAbsent: () => tx.amount);
  }
  return result;
});

// ── Backward-compatible providers for existing consumers ──

// These are used by analytics, drink_drawer, cross-module tests, etc.
// They wrap the new Drift-backed providers so existing code doesn't break.

class TransactionItem {
  final String id;
  final String flowType;
  final double amount;
  final String categoryId;
  final String categoryName;
  final String accountName;
  final String? remark;
  final DateTime loggedAt;

  TransactionItem({
    required this.id,
    required this.flowType,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.accountName,
    this.remark,
    required this.loggedAt,
  });
}

class AssetItem {
  final String id;
  final String name;
  final double purchasePrice;
  final DateTime purchaseDate;
  final String iconId;
  final bool projectToRoom;

  const AssetItem({
    required this.id,
    required this.name,
    required this.purchasePrice,
    required this.purchaseDate,
    required this.iconId,
    required this.projectToRoom,
  });
}

class SubscriptionItem {
  final String id;
  final String serviceName;
  final double amount;
  final String billingCycle;
  final DateTime nextBillingDate;
  final String? accountId;
  final String accountName;
  final bool alertEnabled;
  final bool isActive;

  SubscriptionItem({
    required this.id,
    required this.serviceName,
    required this.amount,
    required this.billingCycle,
    required this.nextBillingDate,
    this.accountId,
    this.accountName = '',
    required this.alertEnabled,
    required this.isActive,
  });

  int daysUntilBilling(DateTime today) => nextBillingDate.difference(today).inDays;
}

/// Legacy-compatible provider that returns List<TransactionItem> so
/// existing consumers (drink_drawer, analytics, cross-module tests)
/// keep working without rewrite.
///
/// Usage:
///   ref.watch(transactionNotifierProvider) → List<TransactionItem>
///   ref.read(transactionNotifierProvider.notifier).addTransaction(...)
///
/// The notifier delegates to TransactionNotifier (Drift-backed).
class _TransactionItemNotifier extends StateNotifier<List<TransactionItem>> {
  _TransactionItemNotifier(this._ref) : super([]);

  final Ref _ref;

  void addTransaction(TransactionItem item) {
    // Find the account ID from the accountName
    final accounts = _ref.read(accountProvider).valueOrNull ?? [];
    String accountId = item.accountName;
    for (final a in accounts) {
      if (a.accountName == item.accountName) {
        accountId = a.accountId;
        break;
      }
    }

    _ref.read(transactionProvider.notifier).addTransaction(
      flowType: item.flowType,
      amount: item.amount,
      categoryId: item.categoryId,
      accountId: accountId,
      remark: item.remark,
      loggedAt: item.loggedAt,
    );
  }
}

final transactionNotifierProvider =
    StateNotifierProvider<_TransactionItemNotifier, List<TransactionItem>>((ref) {
  final notifier = _TransactionItemNotifier(ref);

  // Mirror the Drift-backed list into the legacy shape.
  ref.listen(transactionProvider, (_, next) {
    final accounts = ref.read(accountProvider).valueOrNull ?? [];
    final accountMap = {for (final a in accounts) a.accountId: a.accountName};

    final items = next.whenOrNull(data: (txs) => txs.map((t) {
          final cat = categoryForId(t.categoryId);
          return TransactionItem(
            id: t.transactionId,
            flowType: t.flowType,
            amount: t.amount,
            categoryId: t.categoryId,
            categoryName: cat.name,
            accountName: accountMap[t.accountId] ?? t.accountId,
            remark: t.remark,
            loggedAt: t.loggedAt,
          );
        }).toList()) ?? [];
    // ignore: invalid_use_of_protected_member
    notifier.state = items;
  }, fireImmediately: true);

  return notifier;
});

final assetListProvider = Provider<List<AssetItem>>((ref) {
  final asyncAssets = ref.watch(assetProvider);
  return asyncAssets.whenOrNull(data: (assets) => assets.map((a) => AssetItem(
        id: a.assetId,
        name: a.assetName,
        purchasePrice: a.purchasePrice,
        purchaseDate: a.purchaseDate,
        iconId: a.iconId,
        projectToRoom: a.projectToRoom,
      )).toList()) ?? [];
});

final subscriptionListProvider = Provider<List<SubscriptionItem>>((ref) {
  final asyncSubs = ref.watch(subscriptionProvider);
  final accounts = ref.watch(accountProvider);

  final accountMap = {for (final a in accounts.valueOrNull ?? <PaymentAccount>[]) a.accountId: a.accountName};

  return asyncSubs.whenOrNull(data: (subs) => subs.map((s) => SubscriptionItem(
        id: s.subscriptionId,
        serviceName: s.serviceName,
        amount: s.amount,
        billingCycle: s.billingCycle,
        nextBillingDate: s.nextBillingDate,
        accountId: s.accountId,
        accountName: accountMap[s.accountId] ?? s.accountId,
        alertEnabled: s.alertEnabled,
        isActive: s.isActive,
      )).toList()) ?? [];
});

// Legacy compatibility: todayTransactionsProvider already defined above as Drift-backed.
// The name is the same so existing consumers still work.
