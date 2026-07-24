import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/features/finance/data/repositories/finance_repository_drift.dart';

/// FinanceRepository (Drift 实现) 集成测 —— 在 NativeDatabase.memory() 上验证
/// CRUD、交易↔余额的原子增量、seed、预算 upsert,以及系统用户的前置依赖。
void main() {
  late AppDatabase db;
  late FinanceRepositoryDrift repo;

  setUpAll(() {
    // FK 测试需额外建一个 AppDatabase,抑制 drift 的 multiple-DB 调试警告。
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 系统用户由 SystemBootstrap 一次性确保;Repository 不再自调 ensureSystemUser。
    await SystemBootstrap(db).ensureSystemUser();
    repo = FinanceRepositoryDrift(db);
  });

  tearDown(() async => db.close());

  Future<PaymentAccount> singleAccount() async =>
      (await repo.getAccounts()).single;

  group('accounts', () {
    test('ensureAccountsSeeded seeds exactly the 4 defaults', () async {
      expect(await repo.getAccounts(), isEmpty);
      await repo.ensureAccountsSeeded();
      final accounts = await repo.getAccounts();
      expect(accounts, hasLength(4));
      expect(accounts.map((a) => a.sortOrder).toSet(), {0, 1, 2, 3});
    });

    test('addAccount appends with next sortOrder', () async {
      await repo.ensureAccountsSeeded();
      await repo.addAccount('招行', 'CASH', false, 500);
      final accounts = await repo.getAccounts();
      expect(accounts, hasLength(5));
      expect(accounts.last.accountName, '招行');
      expect(accounts.last.sortOrder, 4);
      expect(accounts.last.balance, 500);
    });

    test('update / delete account', () async {
      await repo.addAccount('现金', 'CASH', false, 0);
      final id = (await singleAccount()).accountId;
      await repo.updateAccount(id, name: '零钱', balance: 88);
      final updated = await singleAccount();
      expect(updated.accountName, '零钱');
      expect(updated.balance, 88);
      await repo.deleteAccount(id);
      expect(await repo.getAccounts(), isEmpty);
    });
  });

  group('transactions', () {
    test('EXPENSE decrements account balance, INCOME increments', () async {
      await repo.addAccount('卡', 'CASH', false, 100);
      final accountId = (await singleAccount()).accountId;

      await repo.addTransaction(
        flowType: 'EXPENSE',
        amount: 30,
        categoryId: 'food',
        accountId: accountId,
      );
      expect((await singleAccount()).balance, 70);
      expect(await repo.getTransactions(), hasLength(1));

      await repo.addTransaction(
        flowType: 'INCOME',
        amount: 50,
        categoryId: 'salary',
        accountId: accountId,
      );
      expect((await singleAccount()).balance, 120);
      expect(await repo.getTransactions(), hasLength(2));
    });

    test('deleteTransaction reverses the balance change', () async {
      await repo.addAccount('卡', 'CASH', false, 100);
      final accountId = (await singleAccount()).accountId;
      await repo.addTransaction(
        flowType: 'EXPENSE',
        amount: 30,
        categoryId: 'food',
        accountId: accountId,
      );
      final txId = (await repo.getTransactions()).single.transactionId;

      await repo.deleteTransaction(txId);

      expect(await repo.getTransactions(), isEmpty);
      expect((await singleAccount()).balance, 100); // refunded
    });

    test('deleteTransaction on unknown id is a no-op', () async {
      await repo.deleteTransaction('does-not-exist'); // must not throw
    });
  });

  group('categories', () {
    test('ensureCategoriesSeeded seeds the default set', () async {
      await repo.ensureCategoriesSeeded();
      final cats = await repo.getCategories();
      expect(cats, hasLength(12));
      expect(cats.where((c) => c.isIncome), hasLength(3));
    });

    test('add / update / delete category', () async {
      await repo.addCategory('咖啡', '☕');
      var cats = await repo.getCategories();
      expect(cats, hasLength(1));
      final id = cats.single.categoryId;
      await repo.updateCategory(id, name: '咖啡豆');
      expect((await repo.getCategories()).single.categoryName, '咖啡豆');
      await repo.deleteCategory(id);
      expect(await repo.getCategories(), isEmpty);
    });
  });

  group('budget', () {
    test('setBudget upserts by monthKey', () async {
      await repo.setBudget('2026-07', 1000);
      var budgets = await repo.getBudgets();
      expect(budgets, hasLength(1));
      expect(budgets.single.budgetAmount, 1000);

      await repo.setBudget('2026-07', 2500); // update, not insert
      budgets = await repo.getBudgets();
      expect(budgets, hasLength(1));
      expect(budgets.single.budgetAmount, 2500);
    });
  });

  group('assets & subscriptions', () {
    test('asset CRUD', () async {
      await repo.addAsset(
        name: 'MacBook',
        price: 9999,
        purchaseDate: DateTime(2026, 1, 1),
        iconId: 'laptop',
      );
      var assets = await repo.getAssets();
      expect(assets, hasLength(1));
      expect(assets.single.assetName, 'MacBook');
      final id = assets.single.assetId;
      await repo.updateAsset(id, price: 8000);
      expect((await repo.getAssets()).single.purchasePrice, 8000);
      await repo.deleteAsset(id);
      expect(await repo.getAssets(), isEmpty);
    });

    test('subscription CRUD', () async {
      await repo.addAccount('卡', 'CASH', false, 0);
      final accountId = (await singleAccount()).accountId;
      await repo.addSubscription(
        serviceName: '流媒体',
        amount: 25,
        billingCycle: 'MONTHLY',
        nextBillingDate: DateTime(2026, 8, 1),
        accountId: accountId,
      );
      expect(await repo.getSubscriptions(), hasLength(1));
      final id = (await repo.getSubscriptions()).single.subscriptionId;
      await repo.updateSubscription(id, amount: 30, isActive: false);
      final s = (await repo.getSubscriptions()).single;
      expect(s.amount, 30);
      expect(s.isActive, false);
      await repo.deleteSubscription(id);
      expect(await repo.getSubscriptions(), isEmpty);
    });
  });

  group('system user dependency (FK)', () {
    test('repo writes require the system user to exist', () async {
      // A fresh DB without the system user seeded.
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      final freshRepo = FinanceRepositoryDrift(fresh);
      // PaymentAccounts.userId FK -> UserAccounts; no user => violation.
      await expectLater(
        freshRepo.addAccount('孤儿', 'CASH', false, 0),
        throwsA(anything),
      );
    });
  });
}
