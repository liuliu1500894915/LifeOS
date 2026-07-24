// hide isNull:drift 与 flutter_test 都导出 isNull,本文件用 matcher 版本(drift 仅用 driftRuntimeOptions)。
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/features/finance/data/repositories/finance_repository.dart';
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

    test('deleteAccount with transactions is blocked (P0-5 FK guard)', () async {
      await repo.addAccount('卡', 'CASH', false, 0);
      final id = (await singleAccount()).accountId;
      await repo.ensureCategoriesSeeded();
      await repo.addTransaction(
        flowType: 'EXPENSE',
        amount: 10,
        categoryId: 'food',
        accountId: id,
      );
      // 有关联交易 → 应用层前置校验抛 EntityInUseException(友好提示),
      // 不让裸 FK 错误冒到 UI。
      await expectLater(
        repo.deleteAccount(id),
        throwsA(isA<EntityInUseException>()),
      );
      // 账户与交易均仍在,未成孤儿。
      expect(await repo.getAccounts(), hasLength(1));
      expect(await repo.getTransactions(), hasLength(1));
    });
  });

  group('transactions', () {
    // P0-5:addTransaction 的 categoryId 现 FK,需先 seed 默认分类('food'/'salary' 等)。
    setUp(() async {
      await repo.ensureCategoriesSeeded();
    });

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

    test('watchTransactionsWithCategory joins DB category/account name (P0-5)',
        () async {
      await repo.addAccount('卡', 'CASH', false, 0);
      final accountId = (await singleAccount()).accountId;
      await repo.addTransaction(
        flowType: 'EXPENSE',
        amount: 25,
        categoryId: 'food',
        accountId: accountId,
      );
      final rows = await repo.watchTransactionsWithCategory().first;
      expect(rows, hasLength(1));
      // 分类名/图标来自 DB join(expense_categories),非硬编码 categoryForId。
      expect(rows.single.categoryName, '三餐');
      expect(rows.single.categoryIcon, '🍱');
      expect(rows.single.accountName, '卡');
    });

    test('addTransaction with dangling accountId/categoryId violates FK (P0-5)',
        () async {
      // 'food' 已 seed;但 accountId 不存在 → FK 违规。
      await expectLater(
        repo.addTransaction(
          flowType: 'EXPENSE',
          amount: 10,
          categoryId: 'food',
          accountId: 'no-such-account',
        ),
        throwsA(anything),
      );
      // 账户存在但 categoryId 不存在 → FK 违规。
      await repo.addAccount('卡', 'CASH', false, 0);
      final accountId = (await singleAccount()).accountId;
      await expectLater(
        repo.addTransaction(
          flowType: 'EXPENSE',
          amount: 10,
          categoryId: 'no-such-category',
          accountId: accountId,
        ),
        throwsA(anything),
      );
    });

    // ── P1-2:一次性摊销开关 ──

    test('AMORTIZED writes nature+range, balance still full-deducted (P1-2)',
        () async {
      await repo.addAccount('卡', 'CASH', false, 100);
      final accountId = (await singleAccount()).accountId;

      // 金额(300)超过余额(100):长期摊销只改分析口径,余额照常按**全额**扣 → -200。
      await repo.addTransaction(
        flowType: 'EXPENSE',
        amount: 300,
        categoryId: 'food',
        accountId: accountId,
        expenseNature: 'AMORTIZED',
        amortizeStart: DateTime(2026, 1, 1),
        amortizeEnd: DateTime(2026, 1, 30),
      );
      expect((await singleAccount()).balance, -200);

      final tx = (await repo.getTransactions()).single;
      expect(tx.expenseNature, 'AMORTIZED');
      // 区间按 dateOnly 截断存储(含头含尾)。
      expect(tx.amortizeStartDate, DateTime(2026, 1, 1));
      expect(tx.amortizeEndDate, DateTime(2026, 1, 30));
    });

    test('AMORTIZED single-day range (end==start) is accepted (P1-2)', () async {
      await repo.addAccount('卡', 'CASH', false, 100);
      final accountId = (await singleAccount()).accountId;
      await repo.addTransaction(
        flowType: 'EXPENSE',
        amount: 10,
        categoryId: 'food',
        accountId: accountId,
        expenseNature: 'AMORTIZED',
        amortizeStart: DateTime(2026, 2, 10),
        amortizeEnd: DateTime(2026, 2, 10), // 单日合法(coverageDays=1)
      );
      final tx = (await repo.getTransactions()).single;
      expect(tx.expenseNature, 'AMORTIZED');
      expect(tx.amortizeStartDate, tx.amortizeEndDate);
    });

    test('AMORTIZED rejects end<start range (P1-2)', () async {
      await repo.addAccount('卡', 'CASH', false, 100);
      final accountId = (await singleAccount()).accountId;
      await expectLater(
        repo.addTransaction(
          flowType: 'EXPENSE',
          amount: 10,
          categoryId: 'food',
          accountId: accountId,
          expenseNature: 'AMORTIZED',
          amortizeStart: DateTime(2026, 1, 10),
          amortizeEnd: DateTime(2026, 1, 1), // 结束早于开始
        ),
        throwsA(isA<ArgumentError>()),
      );
      // 校验拦截 → 未写入。
      expect(await repo.getTransactions(), isEmpty);
      expect((await singleAccount()).balance, 100);
    });

    test('AMORTIZED rejects missing range (P1-2)', () async {
      await repo.addAccount('卡', 'CASH', false, 100);
      final accountId = (await singleAccount()).accountId;
      await expectLater(
        repo.addTransaction(
          flowType: 'EXPENSE',
          amount: 10,
          categoryId: 'food',
          accountId: accountId,
          expenseNature: 'AMORTIZED',
          // 故意不带 amortizeStart/End
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repo.getTransactions(), isEmpty);
    });

    test('addTransaction defaults to SPOT, no amortize range (P1-2 回归)',
        () async {
      await repo.addAccount('卡', 'CASH', false, 100);
      final accountId = (await singleAccount()).accountId;
      await repo.addTransaction(
        flowType: 'EXPENSE',
        amount: 30,
        categoryId: 'food',
        accountId: accountId,
      );
      final tx = (await repo.getTransactions()).single;
      expect(tx.expenseNature, 'SPOT');
      expect(tx.amortizeStartDate, isNull);
      expect(tx.amortizeEndDate, isNull);
      expect(tx.sourceSubscriptionId, isNull);
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

    test('deleteCategory with transactions is blocked (P0-5 FK guard)', () async {
      await repo.addAccount('卡', 'CASH', false, 0);
      final accountId = (await repo.getAccounts()).single.accountId;
      await repo.addCategory('咖啡', '☕');
      final categoryId = (await repo.getCategories()).single.categoryId;
      await repo.addTransaction(
        flowType: 'EXPENSE',
        amount: 10,
        categoryId: categoryId,
        accountId: accountId,
      );
      // 被引用的分类不可删(与 FK RESTRICT 一致),抛 EntityInUseException。
      await expectLater(
        repo.deleteCategory(categoryId),
        throwsA(isA<EntityInUseException>()),
      );
      expect(await repo.getCategories(), hasLength(1));
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
