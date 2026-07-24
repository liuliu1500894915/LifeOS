
import '../../../../core/database/app_database.dart';

/// 数据访问抽象层 —— presentation 只依赖此接口,不碰 `AppDatabase`。
///
/// 读暴露 `watchXxx()`(Drift `.watch()` 流,P0-4 起 Provider 改用它)与一次性
/// `getXxx()`；写一律 `Future`。事务性写(如"插交易 + 改余额")在实现里包
/// `db.transaction`。历史金额为冻结值,余额增量更新用 SQL 表达式。
///
/// 见 docs/LifeOS-开发执行计划.md §3.6 与 §1.4。
abstract interface class FinanceRepository {
  // ── 账户 ──
  Stream<List<PaymentAccount>> watchAccounts();
  Future<List<PaymentAccount>> getAccounts();
  Future<void> ensureAccountsSeeded();
  Future<void> addAccount(String name, String type, bool isLiability, double balance);
  Future<void> updateAccount(String accountId, {String? name, double? balance});
  Future<void> deleteAccount(String accountId);

  // ── 交易 ──
  Stream<List<FinancialTransactionData>> watchTransactions();
  Future<List<FinancialTransactionData>> getTransactions();
  Future<void> addTransaction({
    required String flowType,
    required double amount,
    required String categoryId,
    required String accountId,
    String? remark,
    DateTime? loggedAt,
  });
  Future<void> deleteTransaction(String transactionId);

  // ── 资产 ──
  Stream<List<AssetInventoryData>> watchAssets();
  Future<List<AssetInventoryData>> getAssets();
  Future<void> addAsset({
    required String name,
    required double price,
    required DateTime purchaseDate,
    required String iconId,
    bool projectToRoom = true,
  });
  Future<void> updateAsset(
    String assetId, {
    String? name,
    double? price,
    DateTime? purchaseDate,
    String? iconId,
    bool? projectToRoom,
  });
  Future<void> deleteAsset(String assetId);

  // ── 订阅 ──
  Stream<List<SubscriptionService>> watchSubscriptions();
  Future<List<SubscriptionService>> getSubscriptions();
  Future<void> addSubscription({
    required String serviceName,
    required double amount,
    required String billingCycle,
    required DateTime nextBillingDate,
    required String accountId,
    bool alertEnabled = true,
  });
  Future<void> updateSubscription(
    String subscriptionId, {
    String? serviceName,
    double? amount,
    String? billingCycle,
    DateTime? nextBillingDate,
    String? accountId,
    bool? alertEnabled,
    bool? isActive,
  });
  Future<void> deleteSubscription(String subscriptionId);

  // ── 预算 ──
  Stream<List<BudgetSetting>> watchBudgets();
  Future<List<BudgetSetting>> getBudgets();
  Future<void> setBudget(String monthKey, double amount);

  // ── 分类 ──
  Stream<List<ExpenseCategory>> watchCategories();
  Future<List<ExpenseCategory>> getCategories();
  Future<void> ensureCategoriesSeeded();
  Future<void> addCategory(String name, String icon, {bool isIncome = false});
  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? icon,
    bool? isIncome,
  });
  Future<void> deleteCategory(String categoryId);
}
