import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/finance_repository_drift.dart';
import '../../domain/amortization.dart';

// 导出 join 读投影 DTO(TransactionWithCategory)供消费层引用。
export '../../data/repositories/finance_repository.dart';

// ── Finance 启动种子 ──
//
// 加 FK 后(P0-5),交易必须引用已存在的账户/分类,否则 FK 违规。但旧设计里
// 默认账户/分类是「惰性」seed(仅在 AccountNotifier/CategoryNotifier 被 watch
// 时跑)——若先经 drink_drawer 等非 finance UI 写交易(它不 watch 分类流),
// 目标分类尚未入库即插入,FK 必败。本 Provider 收敛为单一启动种子:系统用户 →
// 默认账户 → 默认分类(均幂等,仅空时补)。所有 finance 读/写 notifier 在
// build/写前 await 它,保证目标行先于任何交易存在。
final financeBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(systemBootstrapProvider.future);
  final repo = ref.read(financeRepositoryProvider);
  if ((await repo.getAccounts()).isEmpty) {
    await repo.ensureAccountsSeeded();
  }
  if ((await repo.getCategories()).isEmpty) {
    await repo.ensureCategoriesSeeded();
  }
});

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
    await ref.read(financeBootstrapProvider.future);
    yield* ref.watch(financeRepositoryProvider).watchTransactions();
  }

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
    await ref.read(financeBootstrapProvider.future);
    await ref.read(financeRepositoryProvider).addTransaction(
          flowType: flowType,
          amount: amount,
          categoryId: categoryId,
          accountId: accountId,
          remark: remark,
          loggedAt: loggedAt,
          expenseNature: expenseNature,
          amortizeStart: amortizeStart,
          amortizeEnd: amortizeEnd,
          sourceSubscriptionId: sourceSubscriptionId,
        );
  }

  Future<void> deleteTransaction(String transactionId) async {
    await ref.read(financeBootstrapProvider.future);
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

/// 交易 + 分类名/账户名 join 流(P0-5:分类名来自 DB,非硬编码)。
///
/// watch [financeBootstrapProvider] 注册依赖:它从 loading→data 时本 Provider
/// 重建,确保分类/账户种子完成后再取首帧。join 流本身也监听
/// expense_categories/payment_accounts,种子写入后自动重发。
final transactionsWithCategoryProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
  ref.watch(financeBootstrapProvider);
  return ref.watch(financeRepositoryProvider).watchTransactionsWithCategory();
});

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

// 带 DB 分类名/账户名的今日/本月交易子集(P0-5)。供展示分类名/icon 的列表页
// (今日明细 / 月度消费)直接消费,无需再 categoryForId + 查 accountProvider。
final todayTransactionsWithCategoryProvider =
    Provider<List<TransactionWithCategory>>((ref) {
  final async = ref.watch(transactionsWithCategoryProvider);
  final start = _todayStart();
  final end = start.add(const Duration(days: 1));
  return async.whenOrNull(
        data: (txs) => txs
            .where((t) => !t.loggedAt.isBefore(start) && t.loggedAt.isBefore(end))
            .toList(),
      ) ??
      [];
});

final monthTransactionsWithCategoryProvider =
    Provider<List<TransactionWithCategory>>((ref) {
  final async = ref.watch(transactionsWithCategoryProvider);
  final start = _monthStart();
  final end = DateTime(start.year, start.month + 1, 1);
  return async.whenOrNull(
        data: (txs) => txs
            .where((t) => !t.loggedAt.isBefore(start) && t.loggedAt.isBefore(end))
            .toList(),
      ) ??
      [];
});

// ── P1-5: 日/月支出拆「日常 SPOT」/「长期摊销」/「真实成本」三层 ──
//
// 长期摊销类支出(expenseNature == AMORTIZED,如年付订阅/保险)余额仍按全额
// 扣(现金流不变),但在分析口径上按覆盖区间平摊到每一天,避免「一次性全额
// 尖峰」扭曲日/月曲线。故:
//   - 日常(SPOT)      = 当日/当月真实发生的一次性支出全额;
//   - 摊销(AMORTIZED) = 由 domain/amortization.dart 按区间平摊到当日/当月的
//                        份额(dailyAmortizedCost / amortizedCostInRange);
//   - 真实成本         = 日常 + 摊销(三层自洽:日常+摊销=真实,验收 P1-5)。
//
// 摊销可由「上一计费周期 post 的交易」覆盖到本月(如年付订阅),故摊销源取
// 全量交易流里所有 AMORTIZED 交易、再按目标日/区间筛覆盖,而非仅看当月新单。

/// 全量 AMORTIZED 交易,适配为 domain 边界 [AmortizedTx](仅金额 + 起止)。
///
/// 取全量交易流而非当月子集 —— 摊销区间可跨多月(年付订阅),上月 post 的
/// 交易同样分摊到本月每日。仅取 EXPENSE 且起止区间齐全者;缺区间的非法
/// AMORTIZED 行不计(domain 守卫亦会跳过,见 amortization.dart)。
final amortizedTransactionsProvider = Provider<List<AmortizedTx>>((ref) {
  final txs = ref.watch(transactionProvider).valueOrNull ?? const <FinancialTransactionData>[];
  return txs
      .where((t) =>
          t.flowType == 'EXPENSE' &&
          t.expenseNature == 'AMORTIZED' &&
          t.amortizeStartDate != null &&
          t.amortizeEndDate != null)
      .map((t) => AmortizedTx(
            amount: t.amount,
            start: t.amortizeStartDate!,
            end: t.amortizeEndDate!,
          ))
      .toList(growable: false);
});

// ── 今日三层 ──

/// 今日「日常」:当日发生的 SPOT 支出全额。
final todaySpotExpenseProvider = Provider<double>((ref) {
  final txs = ref.watch(todayTransactionsProvider);
  return txs
      .where((t) => t.flowType == 'EXPENSE' && t.expenseNature == 'SPOT')
      .fold<double>(0, (s, t) => s + t.amount);
});

/// 今日「摊销」:所有覆盖今日的 AMORTIZED 交易,按「金额 ÷ 覆盖天数」求和。
final todayAmortizedExpenseProvider = Provider<double>((ref) {
  final amort = ref.watch(amortizedTransactionsProvider);
  return dailyAmortizedCost(amort, _todayStart());
});

/// 今日「真实日成本」= 日常 SPOT + 当日摊销份额。
final todayTrueExpenseProvider = Provider<double>(
    (ref) => ref.watch(todaySpotExpenseProvider) + ref.watch(todayAmortizedExpenseProvider));

// ── 本月三层 ──

/// 本月「日常」:当月发生的 SPOT 支出全额。
final monthSpotExpenseProvider = Provider<double>((ref) {
  final txs = ref.watch(monthTransactionsProvider);
  return txs
      .where((t) => t.flowType == 'EXPENSE' && t.expenseNature == 'SPOT')
      .fold<double>(0, (s, t) => s + t.amount);
});

/// 本月「摊销」:[月初, 月末] 每日摊销合计(含头含尾)。
final monthAmortizedExpenseProvider = Provider<double>((ref) {
  final amort = ref.watch(amortizedTransactionsProvider);
  final start = _monthStart();
  // 月末(含):DateTime(year, month+1, 0) = 当月最后一天。amortizedCostInRange
  // 区间含头含尾,故 [月初, 月末] 覆盖当月每一天。
  final end = DateTime(start.year, start.month + 1, 0);
  return amortizedCostInRange(amort, start, end);
});

/// 本月「真实月成本」= 日常 SPOT + 当月摊销合计。
final monthTrueExpenseProvider = Provider<double>(
    (ref) => ref.watch(monthSpotExpenseProvider) + ref.watch(monthAmortizedExpenseProvider));

// ── 向后兼容:headline「今日花费 / 本月花费」改用真实成本 ──
//
// 拆 SPOT/摊销后,headline 不再含 AMORTIZED 全额尖峰,而显示「真实日/月
// 成本」(日常+摊销),与三层展示自洽(验收 P1-5:日常视图不含 AMORTIZED
// 全额尖峰)。预算剩余也按真实成本计 —— 摊销份额本就该占预算。
final todayExpenseProvider = Provider<double>((ref) => ref.watch(todayTrueExpenseProvider));
final monthExpenseProvider = Provider<double>((ref) => ref.watch(monthTrueExpenseProvider));

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

/// 本月每日「真实成本」(按日号聚合):SPOT 当日全额 + 当日摊销份额。
///
/// P1-5:旧实现按 loggedAt 把 AMORTIZED 全额堆到 post 当天 → 折线图/日历出现
/// 一次性尖峰。现改为「真实每日成本」—— SPOT 计入当日,dailyAmortizedCost
/// 把每笔 AMORTIZED 按覆盖区间平摊到当月每一天,曲线平滑、无尖峰(验收
/// P1-5)。供月度折线图与日历热力图。
final monthDailyExpenseProvider = Provider<Map<int, double>>((ref) {
  final txs = ref.watch(monthTransactionsProvider);
  final amort = ref.watch(amortizedTransactionsProvider);
  final result = <int, double>{};
  // SPOT:按 loggedAt 计入当天(monthTransactionsProvider 已限定当月)。
  for (final tx in txs.where((t) => t.flowType == 'EXPENSE' && t.expenseNature == 'SPOT')) {
    result.update(tx.loggedAt.day, (v) => v + tx.amount, ifAbsent: () => tx.amount);
  }
  // 摊销:平摊到当月每一天(跨月 AMORTIZED 同样贡献到本月覆盖日)。
  final now = DateTime.now();
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  for (var d = 1; d <= daysInMonth; d++) {
    final dayCost = dailyAmortizedCost(amort, DateTime(now.year, now.month, d));
    if (dayCost > 0) {
      result.update(d, (v) => v + dayCost, ifAbsent: () => dayCost);
    }
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
    // P0-5:分类名/账户名来自 DB join(transactionsWithCategoryProvider),
    // 不再 categoryForId + 内存 accountMap。
    final txs = ref.watch(transactionsWithCategoryProvider).valueOrNull ??
        const <TransactionWithCategory>[];
    return txs
        .map((t) => TransactionItem(
              id: t.transactionId,
              flowType: t.flowType,
              amount: t.amount,
              categoryId: t.categoryId,
              categoryName: t.categoryName,
              accountName: t.accountName,
              remark: t.remark,
              loggedAt: t.loggedAt,
            ))
        .toList();
  }

  Future<void> addTransaction(TransactionItem item) async {
    // accountName→accountId 解析需账户流就绪:旧实现同步读 valueOrNull,若
    // accountProvider 尚未 build(如 drink_drawer 经此路径、且未先 watch 账户流)
    // 会拿不到账户、回退成「账户名」当 id —— P0-5 加 accountId FK 后必触发违规。
    //
    // 注意:await 后**不可再用 ref** —— Riverpod 在依赖变更未重建期间会断言。
    // 故把所有 ref.read 前置同步捕获,await 后只用捕获到的对象。
    final accountsFuture = ref.read(accountProvider.future);
    final txnNotifier = ref.read(transactionProvider.notifier);
    final accounts = await accountsFuture;
    PaymentAccount? match;
    for (final a in accounts) {
      if (a.accountName == item.accountName) {
        match = a;
        break;
      }
    }
    if (match == null) {
      // 无对应账户:不写入(否则 FK 违规)。调用方应确保 accountName 真实存在。
      return;
    }
    txnNotifier.addTransaction(
      flowType: item.flowType,
      amount: item.amount,
      categoryId: item.categoryId,
      accountId: match.accountId,
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
