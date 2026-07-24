import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../data/category_seeds.dart';
import '../../data/repositories/finance_repository_drift.dart';

// ── Stream-backed notifiers ──
//
// 这些 Notifier 是 presentation 层的状态编排 —— 只调 [FinanceRepository] 接口,
// 无任何 `db.`/`Companion`/裸查询(P0-3)。读取走 Repository 的 `.watch()` 流
// (Drift StreamQueries):写库后流自动重发新值,UI 自动刷新。因此:
//   - 命令(add/update/delete)只转发给 Repository,**不触碰 state**;
//   - **不**手动 `_fetchAll` 全量重查;
//   - **不**靠 `ref.invalidate` 维持跨 Provider 同步(交易改余额由
//     `watchAccounts()` 流承载 —— Repository 的余额写用 `customUpdate`
//     声明受影响表,Drift 在事务 commit 后自动通知该流);
//   - **无** `prev`→出错还原的死乐观回滚(P0-4)。
//
// 系统用户前置:每个写方法首行 `await ref.read(systemBootstrapProvider.future)`。
// 旧 AsyncNotifier 的 `async` build 在被访问时**同步**执行到首个 await,顺带把
// systemBootstrap 排进队列,使随后的写不会撞 FK;StreamNotifier 的 `async*`
// build 体是惰性的(被 listen 才跑),这层隐式保证失效,故改为写方法显式自保护。
class AccountNotifier extends StreamNotifier<List<PaymentAccount>> {
  @override
  Stream<List<PaymentAccount>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.watch(financeRepositoryProvider);
    // 首启种子:仅当库为空时补默认账户(ensureAccountsSeeded 非幂等,故需空检查)。
    if ((await repo.getAccounts()).isEmpty) {
      await repo.ensureAccountsSeeded();
    }
    yield* repo.watchAccounts();
  }

  Future<void> addAccount(String name, String type, bool isLiability, double balance) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).addAccount(name, type, isLiability, balance);
  }

  Future<void> updateAccount(String accountId, {String? name, double? balance}) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).updateAccount(accountId, name: name, balance: balance);
  }

  Future<void> deleteAccount(String accountId) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).deleteAccount(accountId);
  }
}

class TransactionNotifier extends StreamNotifier<List<FinancialTransactionData>> {
  @override
  Stream<List<FinancialTransactionData>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(financeRepositoryProvider).watchTransactions();
  }

  Future<void> addTransaction({
    required String flowType,
    required double amount,
    required String categoryId,
    required String accountId,
    String? remark,
    DateTime? loggedAt,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).addTransaction(
          flowType: flowType,
          amount: amount,
          categoryId: categoryId,
          accountId: accountId,
          remark: remark,
          loggedAt: loggedAt,
        );
  }

  Future<void> deleteTransaction(String transactionId) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).deleteTransaction(transactionId);
  }
}

class AssetNotifier extends StreamNotifier<List<AssetInventoryData>> {
  @override
  Stream<List<AssetInventoryData>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(financeRepositoryProvider).watchAssets();
  }

  Future<void> addAsset({
    required String name,
    required double price,
    required DateTime purchaseDate,
    required String iconId,
    bool projectToRoom = true,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).addAsset(
          name: name,
          price: price,
          purchaseDate: purchaseDate,
          iconId: iconId,
          projectToRoom: projectToRoom,
        );
  }

  Future<void> updateAsset(
    String assetId, {
    String? name,
    double? price,
    DateTime? purchaseDate,
    String? iconId,
    bool? projectToRoom,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).updateAsset(
            assetId,
            name: name,
            price: price,
            purchaseDate: purchaseDate,
            iconId: iconId,
            projectToRoom: projectToRoom,
          );
  }

  Future<void> deleteAsset(String assetId) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).deleteAsset(assetId);
  }
}

class SubscriptionNotifier extends StreamNotifier<List<SubscriptionService>> {
  @override
  Stream<List<SubscriptionService>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(financeRepositoryProvider).watchSubscriptions();
  }

  Future<void> addSubscription({
    required String serviceName,
    required double amount,
    required String billingCycle,
    required DateTime nextBillingDate,
    required String accountId,
    bool alertEnabled = true,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).addSubscription(
          serviceName: serviceName,
          amount: amount,
          billingCycle: billingCycle,
          nextBillingDate: nextBillingDate,
          accountId: accountId,
          alertEnabled: alertEnabled,
        );
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
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).updateSubscription(
            subscriptionId,
            serviceName: serviceName,
            amount: amount,
            billingCycle: billingCycle,
            nextBillingDate: nextBillingDate,
            accountId: accountId,
            alertEnabled: alertEnabled,
            isActive: isActive,
          );
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).deleteSubscription(subscriptionId);
  }
}

class BudgetNotifier extends StreamNotifier<List<BudgetSetting>> {
  @override
  Stream<List<BudgetSetting>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(financeRepositoryProvider).watchBudgets();
  }

  Future<void> setBudget(String monthKey, double amount) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).setBudget(monthKey, amount);
  }
}

class CategoryNotifier extends StreamNotifier<List<ExpenseCategory>> {
  @override
  Stream<List<ExpenseCategory>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.watch(financeRepositoryProvider);
    // 首启种子:仅当库为空时补默认分类(ensureCategoriesSeeded 非幂等,故需空检查)。
    if ((await repo.getCategories()).isEmpty) {
      await repo.ensureCategoriesSeeded();
    }
    yield* repo.watchCategories();
  }

  Future<void> addCategory(String name, String icon, {bool isIncome = false}) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).addCategory(name, icon, isIncome: isIncome);
  }

  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? icon,
    bool? isIncome,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    await ref
        .read(financeRepositoryProvider)
        .updateCategory(categoryId, name: name, icon: icon, isIncome: isIncome);
  }

  Future<void> deleteCategory(String categoryId) async {
    await ref.read(systemBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).deleteCategory(categoryId);
  }
}

// ── Providers ──

final accountProvider = StreamNotifierProvider<AccountNotifier, List<PaymentAccount>>(
  AccountNotifier.new,
);

final transactionProvider =
    StreamNotifierProvider<TransactionNotifier, List<FinancialTransactionData>>(
  TransactionNotifier.new,
);

final assetProvider = StreamNotifierProvider<AssetNotifier, List<AssetInventoryData>>(
  AssetNotifier.new,
);

final subscriptionProvider =
    StreamNotifierProvider<SubscriptionNotifier, List<SubscriptionService>>(
  SubscriptionNotifier.new,
);

final budgetProvider = StreamNotifierProvider<BudgetNotifier, List<BudgetSetting>>(
  BudgetNotifier.new,
);

final categoryProvider = StreamNotifierProvider<CategoryNotifier, List<ExpenseCategory>>(
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

/// 把交易流 + 账户流派生成展示用的 [TransactionItem](带分类名/账户名)。
///
/// 用同步 [Notifier] 直接 `ref.watch` 两路流 —— 任一变化自动重建,**无需**
/// 手动 `ref.listen` + 外部写 `state`(那会触发 `invalid_use_of_protected_member`,
/// P0-4 已消除)。写路径 `addTransaction` 解析账户名→id 后转发 [TransactionNotifier]。
class TransactionItemListNotifier extends Notifier<List<TransactionItem>> {
  @override
  List<TransactionItem> build() {
    final txs = ref.watch(transactionProvider).valueOrNull ?? const <FinancialTransactionData>[];
    final accounts = ref.watch(accountProvider).valueOrNull ?? const <PaymentAccount>[];
    final accountMap = {for (final a in accounts) a.accountId: a.accountName};
    return txs.map((t) {
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
    }).toList();
  }

  void addTransaction(TransactionItem item) {
    final accounts = ref.read(accountProvider).valueOrNull ?? const <PaymentAccount>[];
    var accountId = item.accountName;
    for (final a in accounts) {
      if (a.accountName == item.accountName) {
        accountId = a.accountId;
        break;
      }
    }
    ref.read(transactionProvider.notifier).addTransaction(
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
    NotifierProvider<TransactionItemListNotifier, List<TransactionItem>>(
  TransactionItemListNotifier.new,
);

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
