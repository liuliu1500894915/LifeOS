import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON');
      },
    ));
  });

  tearDown(() async {
    await db.close();
  });

  test('ensureSystemUser inserts and upserts correctly', () async {
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: 'user-001', displayName: '默认用户'),
        );
    final users = await db.select(db.userAccounts).get();
    expect(users.length, 1);

    // Upsert should not throw or duplicate
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: 'user-001', displayName: '默认用户'),
        );
    final users2 = await db.select(db.userAccounts).get();
    expect(users2.length, 1);
  });

  test('add payment account CASH works end-to-end', () async {
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: 'user-001', displayName: '默认用户'),
        );

    await db.into(db.paymentAccounts).insert(
          PaymentAccountsCompanion.insert(
            accountId: 'acc-001',
            userId: 'user-001',
            accountName: '招商银行卡',
            accountType: 'CASH',
            isLiability: Value(false),
            balance: Value(100.0),
            sortOrder: Value(0),
          ),
        );

    final accounts = await db.select(db.paymentAccounts).get();
    expect(accounts.length, 1);
    expect(accounts.first.accountName, '招商银行卡');
    expect(accounts.first.accountType, 'CASH');
    expect(accounts.first.balance, 100.0);
  });

  test('add DEBIT account works', () async {
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: 'user-001', displayName: '默认用户'),
        );
    await db.into(db.paymentAccounts).insert(
          PaymentAccountsCompanion.insert(
            accountId: 'acc-002',
            userId: 'user-001',
            accountName: '储蓄卡',
            accountType: 'DEBIT',
          ),
        );
    final accounts = await db.select(db.paymentAccounts).get();
    expect(accounts.first.accountType, 'DEBIT');
  });

  test('add CREDIT account works', () async {
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: 'user-001', displayName: '默认用户'),
        );
    await db.into(db.paymentAccounts).insert(
          PaymentAccountsCompanion.insert(
            accountId: 'acc-003',
            userId: 'user-001',
            accountName: '花呗',
            accountType: 'CREDIT',
            isLiability: Value(true),
          ),
        );
    final accounts = await db.select(db.paymentAccounts).get();
    expect(accounts.first.isLiability, true);
  });

  test('FK constraint: add account without user fails', () async {
    try {
      await db.into(db.paymentAccounts).insert(
            PaymentAccountsCompanion.insert(
              accountId: 'acc-fail',
              userId: 'user-001',
              accountName: 'NoUser',
              accountType: 'CASH',
            ),
          );
      fail('Should have thrown FK constraint error');
    } catch (e) {
      expect(e.toString(), contains('FOREIGN KEY'));
    }
  });

  test('expense categories CRUD works', () async {
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: 'user-001', displayName: '默认用户'),
        );
    await db.into(db.expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(
            categoryId: 'food',
            userId: 'user-001',
            categoryName: '三餐',
            categoryIcon: '🍱',
          ),
        );
    final cats = await db.select(db.expenseCategories).get();
    expect(cats.length, 1);
    expect(cats.first.categoryName, '三餐');
  });

  test('full add-account flow matches provider logic', () async {
    // Simulates AccountNotifier.addAccount
    const systemUserId = 'user-001';

    // _ensureSystemUser
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: systemUserId, displayName: '默认用户'),
        );

    // addAccount: find max sortOrder
    final maxSort = await (db.select(db.paymentAccounts)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();

    // insert
    await db.into(db.paymentAccounts).insert(
          PaymentAccountsCompanion.insert(
            accountId: 'new-acc-001',
            userId: systemUserId,
            accountName: '微信支付',
            accountType: 'CASH',
            isLiability: Value(false),
            balance: Value(500.0),
            sortOrder: Value((maxSort?.sortOrder ?? -1) + 1),
          ),
        );

    // _fetchAll
    final accounts = await (db.select(db.paymentAccounts)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    expect(accounts.length, 1);
    expect(accounts.first.accountName, '微信支付');
    expect(accounts.first.balance, 500.0);
    expect(accounts.first.sortOrder, 0);
  });

  test('seed defaults then add more accounts', () async {
    const systemUserId = 'user-001';
    await db.into(db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(userId: systemUserId, displayName: '默认用户'),
        );

    // Seed 4 defaults (matches _seedDefaults)
    const defaults = [
      ('微信支付', 'CASH', false, 0.0),
      ('支付宝', 'CASH', false, 0.0),
      ('银行卡', 'DEBIT', false, 0.0),
      ('花呗', 'CREDIT', true, 0.0),
    ];
    for (var i = 0; i < defaults.length; i++) {
      await db.into(db.paymentAccounts).insert(
            PaymentAccountsCompanion.insert(
              accountId: 'seed-$i',
              userId: systemUserId,
              accountName: defaults[i].$1,
              accountType: defaults[i].$2,
              isLiability: Value(defaults[i].$3),
              balance: Value(defaults[i].$4),
              sortOrder: Value(i),
            ),
          );
    }

    // Now add a new account (like the user does in the UI)
    final maxSort = await (db.select(db.paymentAccounts)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();

    await db.into(db.paymentAccounts).insert(
          PaymentAccountsCompanion.insert(
            accountId: 'new-acc',
            userId: systemUserId,
            accountName: '招商银行卡',
            accountType: 'CASH',
            isLiability: Value(false),
            balance: Value(1000.0),
            sortOrder: Value((maxSort?.sortOrder ?? -1) + 1),
          ),
        );

    final accounts = await (db.select(db.paymentAccounts)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    expect(accounts.length, 5);
    expect(accounts.last.accountName, '招商银行卡');
    expect(accounts.last.sortOrder, 4);
  });
}
