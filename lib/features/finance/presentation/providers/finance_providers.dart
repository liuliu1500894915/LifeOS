import 'package:flutter_riverpod/flutter_riverpod.dart';


enum FlowType { income, expense, transfer }

enum BillingCycle { monthly, quarterly, yearly }

enum CategoryId { food, transport, entertainment, drink, shopping, housing, pet, other }

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

// ── StateNotifier ──

class TransactionNotifier extends StateNotifier<List<TransactionItem>> {
  TransactionNotifier() : super(_mockTransactions);

  void addTransaction(TransactionItem item) {
    state = [...state, item];
  }

  static DateTime _todayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static final _mockTransactions = [
    TransactionItem(
      id: '1', flowType: 'EXPENSE', amount: 25.0,
      categoryId: 'food', categoryName: '三餐',
      accountName: '微信支付', remark: '黄焖鸡米饭',
      loggedAt: _todayAt(12, 30),
    ),
    TransactionItem(
      id: '2', flowType: 'EXPENSE', amount: 15.0,
      categoryId: 'transport', categoryName: '交通',
      accountName: '支付宝', remark: '上班打车',
      loggedAt: _todayAt(8, 15),
    ),
    TransactionItem(
      id: '3', flowType: 'EXPENSE', amount: 5.0,
      categoryId: 'drink', categoryName: '饮品',
      accountName: '现金', remark: '便利店矿泉水',
      loggedAt: _todayAt(7, 30),
    ),
  ];
}

// ── Providers ──

final transactionNotifierProvider =
    StateNotifierProvider<TransactionNotifier, List<TransactionItem>>((ref) {
  return TransactionNotifier();
});

final todayTransactionsProvider = Provider<List<TransactionItem>>((ref) {
  return ref.watch(transactionNotifierProvider);
});

final assetListProvider = Provider<List<AssetItem>>((ref) {
  return [
    AssetItem(id: '1', name: 'MacBook Pro M3 Max', purchasePrice: 18000, purchaseDate: DateTime(2026, 1, 24), iconId: 'laptop', projectToRoom: true),
    AssetItem(id: '2', name: '人体工学电竞椅', purchasePrice: 3500, purchaseDate: DateTime(2024, 12, 1), iconId: 'chair', projectToRoom: true),
    AssetItem(id: '3', name: '富士 X-T5 相机', purchasePrice: 12500, purchaseDate: DateTime(2025, 6, 15), iconId: 'camera', projectToRoom: true),
    AssetItem(id: '4', name: 'Fender 电吉他', purchasePrice: 8600, purchaseDate: DateTime(2025, 3, 10), iconId: 'guitar', projectToRoom: true),
    AssetItem(id: '5', name: 'iPad Pro', purchasePrice: 6200, purchaseDate: DateTime(2026, 2, 5), iconId: 'tablet', projectToRoom: true),
  ];
});

final subscriptionListProvider = Provider<List<SubscriptionItem>>((ref) {
  return [
    SubscriptionItem(id: '1', serviceName: 'ChatGPT Plus', amount: 145, billingCycle: 'MONTHLY', nextBillingDate: DateTime(2026, 5, 27), accountId: '1', accountName: '招商银行卡', alertEnabled: true, isActive: true),
    SubscriptionItem(id: '2', serviceName: 'Netflix Premium', amount: 98, billingCycle: 'MONTHLY', nextBillingDate: DateTime(2026, 6, 1), accountId: '2', accountName: '微信支付', alertEnabled: true, isActive: true),
    SubscriptionItem(id: '3', serviceName: 'Spotify', amount: 45, billingCycle: 'MONTHLY', nextBillingDate: DateTime(2026, 6, 15), accountId: '2', accountName: '微信支付', alertEnabled: false, isActive: true),
  ];
});
