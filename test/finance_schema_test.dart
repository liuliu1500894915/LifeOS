// ignore_for_file: discarded_futures
// hide isNull: drift 导出的 SQL `isNull` 与 flutter_test/matcher 的 `isNull`
// 断言同名冲突;本文件只需 matcher 版,故屏蔽 drift 的。
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';

import 'generated_migrations/schema.dart';

/// finance schema 迁移测试(P0-5):v3→v4 给 FinancialTransaction.categoryId/
/// accountId 补外键(SQLite 需 TableMigration 重建表)、建 loggedAt/accountId
/// 索引、清洗孤儿交易。覆盖迁移正确性、链式、索引守门、数据保留、孤儿清洗。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 链式测试会建多个 AppDatabase(各自独立连接),抑制 drift 多 DB 调试警告。
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  final verifier = SchemaVerifier(GeneratedHelper());

  group('finance schema migration (v4)', () {
    test('v3 -> v4 yields a schema matching the v4 definition', () async {
      final connection = await verifier.startAt(3);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      // 迁移后结构必须与 v4 定义一致(fresh install == upgrade install)。
      await verifier.migrateAndValidate(db, 4);
    });

    test('v2 -> v4 and v1 -> v4 chain through every step correctly', () async {
      for (final from in [2, 1]) {
        final connection = await verifier.startAt(from);
        final db = AppDatabase.forTesting(connection);
        addTearDown(db.close);
        await verifier.migrateAndValidate(db, 4);
      }
    });

    test('v3 -> v4 creates the finance transaction indexes', () async {
      // 索引不属于 migrateAndValidate 的列校验范围,需显式查 sqlite_master。
      final schema = await verifier.schemaAt(3);
      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);

      final idx = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_ftx_%'",
          )
          .get();
      final names = idx.map((r) => r.read<String>('name')).toSet();
      expect(names, {'idx_ftx_logged_at', 'idx_ftx_account'});
    });

    test('v3 -> v4 preserves a transaction with valid category/account',
        () async {
      final schema = await verifier.schemaAt(3);
      // v3 库无 FK,裸 SQL 插入完整一套(user + category + account + 交易)。
      schema.rawDatabase.execute(
        'INSERT INTO user_accounts (user_id, display_name) '
        "VALUES ('user-001', '默认用户')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO expense_categories '
        '(category_id, user_id, category_name, category_icon) '
        "VALUES ('food', 'user-001', '三餐', '🍱')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO payment_accounts '
        '(account_id, user_id, account_name, account_type) '
        "VALUES ('acc-001', 'user-001', '卡', 'CASH')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO financial_transaction '
        '(transaction_id, user_id, flow_type, amount, '
        'category_id, account_id, logged_at) '
        "VALUES ('tx-keep', 'user-001', 'EXPENSE', 50.0, "
        "'food', 'acc-001', 1760000000)",
      );

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();

      // 迁移后行仍在,金额不变。
      final rows = schema.rawDatabase.select(
        'SELECT transaction_id, amount FROM financial_transaction '
        "WHERE transaction_id = 'tx-keep'",
      );
      expect(rows, hasLength(1));
      expect(rows.first['amount'], 50.0);
    });

    test('v3 -> v4 cleans orphan transactions (dangling refs)', () async {
      final schema = await verifier.schemaAt(3);
      schema.rawDatabase.execute(
        'INSERT INTO user_accounts (user_id, display_name) '
        "VALUES ('user-001', '默认用户')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO expense_categories '
        '(category_id, user_id, category_name, category_icon) '
        "VALUES ('food', 'user-001', '三餐', '🍱')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO payment_accounts '
        '(account_id, user_id, account_name, account_type) '
        "VALUES ('acc-001', 'user-001', '卡', 'CASH')",
      );
      // 有效引用 → 保留。
      schema.rawDatabase.execute(
        'INSERT INTO financial_transaction '
        '(transaction_id, user_id, flow_type, amount, '
        'category_id, account_id, logged_at) '
        "VALUES ('tx-keep', 'user-001', 'EXPENSE', 10.0, "
        "'food', 'acc-001', 1760000000)",
      );
      // 孤儿:categoryId 悬空 → 迁移清洗删除。
      schema.rawDatabase.execute(
        'INSERT INTO financial_transaction '
        '(transaction_id, user_id, flow_type, amount, '
        'category_id, account_id, logged_at) '
        "VALUES ('tx-orphan-cat', 'user-001', 'EXPENSE', 20.0, "
        "'ghost-cat', 'acc-001', 1760000000)",
      );
      // 孤儿:accountId 悬空 → 迁移清洗删除。
      schema.rawDatabase.execute(
        'INSERT INTO financial_transaction '
        '(transaction_id, user_id, flow_type, amount, '
        'category_id, account_id, logged_at) '
        "VALUES ('tx-orphan-acc', 'user-001', 'EXPENSE', 30.0, "
        "'food', 'ghost-acc', 1760000000)",
      );

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();

      final rows = schema.rawDatabase.select(
        'SELECT transaction_id FROM financial_transaction',
      );
      final ids = rows.map((r) => r['transaction_id'] as String).toSet();
      // 仅有效行保留,两笔孤儿被清洗。
      expect(ids, {'tx-keep'});
    });

    test('fresh install creates the finance indexes and validates schema',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get(); // 强制 onCreate + beforeOpen

      final idx = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name LIKE 'idx_ftx_%'",
      ).get();
      final names = idx.map((r) => r.read<String>('name')).toSet();
      expect(names, {'idx_ftx_logged_at', 'idx_ftx_account'});

      await db.validateDatabaseSchema();
    });

    test('EXPLAIN QUERY PLAN hits the finance indexes (P0-5 验收)', () async {
      // 索引不仅要存在,还要被查询规划器命中(禁止全表扫)。
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      final planAcc = await db
          .customSelect(
            "EXPLAIN QUERY PLAN "
            "SELECT * FROM financial_transaction WHERE account_id = 'x'",
          )
          .get();
      final planAccText = planAcc.map((r) => r.read<String>('detail')).join('\n');
      expect(planAccText, contains('idx_ftx_account'));

      final planLog = await db
          .customSelect(
            "EXPLAIN QUERY PLAN "
            "SELECT * FROM financial_transaction ORDER BY logged_at",
          )
          .get();
      final planLogText = planLog.map((r) => r.read<String>('detail')).join('\n');
      expect(planLogText, contains('idx_ftx_logged_at'));
    });
  });

  group('finance schema migration (v5)', () {
    // P1-1: FinancialTransaction 加摊销四列（expenseNature 默认 SPOT +
    // amortize 区间 + sourceSubscriptionId FK）。覆盖迁移正确性、链式、
    // 数据保留、存量交易默认归 SPOT。
    test('v4 -> v5 yields a schema matching the v5 definition', () async {
      final connection = await verifier.startAt(4);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 5);
    });

    test('v3/v2/v1 -> v5 chain through every step correctly', () async {
      for (final from in [3, 2, 1]) {
        final connection = await verifier.startAt(from);
        final db = AppDatabase.forTesting(connection);
        addTearDown(db.close);
        await verifier.migrateAndValidate(db, 5);
      }
    });

    test('v4 -> v5 preserves a transaction and defaults expenseNature to SPOT',
        () async {
      // v4 库已带 categoryId/accountId 外键（P0-5），裸 SQL 插一套合法引用。
      final schema = await verifier.schemaAt(4);
      schema.rawDatabase.execute(
        'INSERT INTO user_accounts (user_id, display_name) '
        "VALUES ('user-001', '默认用户')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO expense_categories '
        '(category_id, user_id, category_name, category_icon) '
        "VALUES ('food', 'user-001', '三餐', '🍱')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO payment_accounts '
        '(account_id, user_id, account_name, account_type) '
        "VALUES ('acc-001', 'user-001', '卡', 'CASH')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO financial_transaction '
        '(transaction_id, user_id, flow_type, amount, '
        'category_id, account_id, logged_at) '
        "VALUES ('tx-keep', 'user-001', 'EXPENSE', 50.0, "
        "'food', 'acc-001', 1760000000)",
      );

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 5);
      await db.close();

      // 迁移后：行仍在，金额不变；新列存量默认值——expenseNature='SPOT'，
      // 摊销区间与订阅回链为 NULL（一次性交易无区间）。
      final rows = schema.rawDatabase.select(
        'SELECT amount, expense_nature, amortize_start_date, '
        'amortize_end_date, source_subscription_id '
        'FROM financial_transaction WHERE transaction_id = ?',
        ['tx-keep'],
      );
      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row['amount'], 50.0);
      expect(row['expense_nature'], 'SPOT');
      expect(row['amortize_start_date'], isNull);
      expect(row['amortize_end_date'], isNull);
      expect(row['source_subscription_id'], isNull);
    });

    test('v4 -> v5 default SPOT also holds for multiple legacy transactions',
        () async {
      // 多笔存量交易批量升级，确认默认值逐行补齐（非仅首行）。
      final schema = await verifier.schemaAt(4);
      schema.rawDatabase.execute(
        'INSERT INTO user_accounts (user_id, display_name) '
        "VALUES ('user-001', '默认用户')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO expense_categories '
        '(category_id, user_id, category_name, category_icon) '
        "VALUES ('food', 'user-001', '三餐', '🍱')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO payment_accounts '
        '(account_id, user_id, account_name, account_type) '
        "VALUES ('acc-001', 'user-001', '卡', 'CASH')",
      );
      for (var i = 0; i < 3; i++) {
        schema.rawDatabase.execute(
          'INSERT INTO financial_transaction '
          '(transaction_id, user_id, flow_type, amount, '
          'category_id, account_id, logged_at) '
          "VALUES ('tx-$i', 'user-001', 'EXPENSE', ${10.0 + i}, "
          "'food', 'acc-001', 1760000000)",
        );
      }

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 5);
      await db.close();

      final rows = schema.rawDatabase.select(
        'SELECT transaction_id, expense_nature FROM financial_transaction',
      );
      expect(rows, hasLength(3));
      for (final row in rows) {
        expect(row['expense_nature'], 'SPOT');
      }
    });

    test('fresh install creates amortize columns and validates schema',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get(); // 强制 onCreate + beforeOpen

      // 新装库结构须与 v5 定义一致（含四列）。
      await db.validateDatabaseSchema();

      // fresh 写一笔不指定 expenseNature 的交易，落默认 SPOT。
      await db.into(db.userAccounts).insertOnConflictUpdate(
            UserAccountsCompanion.insert(
              userId: 'user-001',
              displayName: '默认用户',
            ),
          );
      await db.into(db.paymentAccounts).insert(
            PaymentAccountsCompanion.insert(
              accountId: 'acc-001',
              userId: 'user-001',
              accountName: '卡',
              accountType: 'CASH',
            ),
          );
      await db.into(db.expenseCategories).insert(
            ExpenseCategoriesCompanion.insert(
              categoryId: 'food',
              userId: 'user-001',
              categoryName: '三餐',
              categoryIcon: '🍱',
            ),
          );
      await db.into(db.financialTransaction).insert(
            FinancialTransactionCompanion.insert(
              transactionId: 'tx-spot',
              userId: 'user-001',
              flowType: 'EXPENSE',
              amount: 12.0,
              categoryId: 'food',
              accountId: 'acc-001',
              loggedAt: DateTime.now(),
            ),
          );
      final row = await (db.select(db.financialTransaction)
            ..where((t) => t.transactionId.equals('tx-spot')))
          .getSingle();
      expect(row.expenseNature, 'SPOT');
      expect(row.amortizeStartDate, isNull);
      expect(row.amortizeEndDate, isNull);
      expect(row.sourceSubscriptionId, isNull);
    });
  });
}
