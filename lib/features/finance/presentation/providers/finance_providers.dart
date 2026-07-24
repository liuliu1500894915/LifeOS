import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../data/category_seeds.dart';
import '../../data/repositories/finance_repository_drift.dart';

// ── Notifiers ──
//
// 这些 AsyncNotifier 是 presentation 层的状态编排 —— 只调
// [FinanceRepository] 接口,无任何 `db.`/`Companion`/裸查询(P0-3)。
// 读取仍是 Future 一次性取 + 写后手动 refetch;P0-4 将改为 `.watch()` 流,
// 届时移除 `state = AsyncData(await getXxx())`、`ref.invalidate` 与 prev 回滚。

class AccountNotifier extends AsyncNotifier<List<PaymentAccount>> {
  @override
  Future<List<PaymentAccount>> build() async {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.read(financeRepositoryProvider);
    var accounts = await repo.getAccounts();
    if (accounts.isEmpty) {
      await repo.ensureAccountsSeeded();
      accounts = await repo.getAccounts();
    }
    return accounts;
  }

  Future<void> addAccount(String name, String type, bool isLiability, double balance) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.addAccount(name, type, isLiability, balance);
      state = AsyncData(await repo.getAccounts());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> updateAccount(String accountId, {String? name, double? balance}) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.updateAccount(accountId, name: name, balance: balance);
      state = AsyncData(await repo.getAccounts());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> deleteAccount(String accountId) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.deleteAccount(accountId);
      state = AsyncData(await repo.getAccounts());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

class TransactionNotifier extends AsyncNotifier<List<FinancialTransactionData>> {
  @override
  Future<List<FinancialTransactionData>> build() async {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.read(financeRepositoryProvider);
    return await repo.getTransactions();
  }

  Future<void> addTransaction({
    required String flowType,
    required double amount,
    required String categoryId,
    required String accountId,
    String? remark,
    DateTime? loggedAt,
  }) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.addTransaction(
        flowType: flowType,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        remark: remark,
        loggedAt: loggedAt,
      );
      ref.invalidate(accountProvider);
      state = AsyncData(await repo.getTransactions());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.deleteTransaction(transactionId);
      ref.invalidate(accountProvider);
      state = AsyncData(await repo.getTransactions());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

class AssetNotifier extends AsyncNotifier<List<AssetInventoryData>> {
  @override
  Future<List<AssetInventoryData>> build() async {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.read(financeRepositoryProvider);
    return await repo.getAssets();
  }

  Future<void> addAsset({
    required String name,
    required double price,
    required DateTime purchaseDate,
    required String iconId,
    bool projectToRoom = true,
  }) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.addAsset(
        name: name,
        price: price,
        purchaseDate: purchaseDate,
        iconId: iconId,
        projectToRoom: projectToRoom,
      );
      state = AsyncData(await repo.getAssets());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> updateAsset(
    String assetId, {
    String? name,
    double? price,
    DateTime? purchaseDate,
    String? iconId,
    bool? projectToRoom,
  }) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.updateAsset(
        assetId,
        name: name,
        price: price,
        purchaseDate: purchaseDate,
        iconId: iconId,
        projectToRoom: projectToRoom,
      );
      state = AsyncData(await repo.getAssets());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> deleteAsset(String assetId) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.deleteAsset(assetId);
      state = AsyncData(await repo.getAssets());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

class SubscriptionNotifier extends AsyncNotifier<List<SubscriptionService>> {
  @override
  Future<List<SubscriptionService>> build() async {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.read(financeRepositoryProvider);
    return await repo.getSubscriptions();
  }

  Future<void> addSubscription({
    required String serviceName,
    required double amount,
    required String billingCycle,
    required DateTime nextBillingDate,
    required String accountId,
    bool alertEnabled = true,
  }) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.addSubscription(
        serviceName: serviceName,
        amount: amount,
        billingCycle: billingCycle,
        nextBillingDate: nextBillingDate,
        accountId: accountId,
        alertEnabled: alertEnabled,
      );
      state = AsyncData(await repo.getSubscriptions());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

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
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.updateSubscription(
        subscriptionId,
        serviceName: serviceName,
        amount: amount,
        billingCycle: billingCycle,
        nextBillingDate: nextBillingDate,
        accountId: accountId,
        alertEnabled: alertEnabled,
        isActive: isActive,
      );
      state = AsyncData(await repo.getSubscriptions());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.deleteSubscription(subscriptionId);
      state = AsyncData(await repo.getSubscriptions());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

class BudgetNotifier extends AsyncNotifier<List<BudgetSetting>> {
  @override
  Future<List<BudgetSetting>> build() async {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.read(financeRepositoryProvider);
    return await repo.getBudgets();
  }

  Future<void> setBudget(String monthKey, double amount) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.setBudget(monthKey, amount);
      state = AsyncData(await repo.getBudgets());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

class CategoryNotifier extends AsyncNotifier<List<ExpenseCategory>> {
  @override
  Future<List<ExpenseCategory>> build() async {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.read(financeRepositoryProvider);
    var categories = await repo.getCategories();
    if (categories.isEmpty) {
      await repo.ensureCategoriesSeeded();
      categories = await repo.getCategories();
    }
    return categories;
  }

  Future<void> addCategory(String name, String icon, {bool isIncome = false}) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.addCategory(name, icon, isIncome: isIncome);
      state = AsyncData(await repo.getCategories());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? icon,
    bool? isIncome,
  }) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.updateCategory(categoryId, name: name, icon: icon, isIncome: isIncome);
      state = AsyncData(await repo.getCategories());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    final prev = state.valueOrNull ?? [];
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.deleteCategory(categoryId);
      state = AsyncData(await repo.getCategories());
    } catch (e) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

// ── Providers ──

final accountProvider = AsyncNotifierProvider<AccountNotifier, List<PaymentAccount>>(
  AccountNotifier.new,
);

final transactionProvider =
    AsyncNotifierProvider<TransactionNotifier, List<FinancialTransactionData>>(
  TransactionNotifier.new,
);

final assetProvider = AsyncNotifierProvider<AssetNotifier, List<AssetInventoryData>>(
  AssetNotifier.new,
);

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, List<SubscriptionService>>(
  SubscriptionNotifier.new,
);

final budgetProvider = AsyncNotifierProvider<BudgetNotifier, List<BudgetSetting>>(
  BudgetNotifier.new,
);

final categoryProvider = AsyncNotifierProvider<CategoryNotifier, List<ExpenseCategory>>(
  CategoryNotifier.new,
);

final expenseCategoryListProvider = Provider<List<ExpenseCategory>>((ref) {
  final asyncCats = ref.watch(categoryProvider);
  return asyncCats.whenOrNull(data: (cats) => cats.where((c) => !c.isIncome && c.isActive).toList()) ?? [];
});

final incomeCategoryListProvider = Provider<List<ExpenseCategory>>((ref) {
  final asyncCats = ref.watch(categoryProvider);
  return asyncCats.whenOrNull(data: (cats) => cats.where((c) => c.isIncome && c.isActive).toList()) ?? [];
});

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

class _TransactionItemNotifier extends StateNotifier<List<TransactionItem>> {
  _TransactionItemNotifier(this._ref) : super([]);

  final Ref _ref;

  void addTransaction(TransactionItem item) {
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
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member, P0-4 将改用流式,届时移除此直接写 state
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
