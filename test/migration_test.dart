import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'generated_migrations/schema.dart';

/// Schema migration tests (P0-2).
///
/// Verifies the `stepByStep` v1→v2 migration produces a schema matching a fresh
/// install, that it preserves pre-existing rows, and that `beforeOpen` enables
/// foreign keys on every open.
///
/// The v1/v2 schema snapshots live in `drift_schemas/`; the per-version database
/// helpers in `test/generated_migrations/` are generated via
/// `dart run drift_dev schema generate`. See CLAUDE.md → Drift 迁移工具链.
void main() {
  group('database migration', () {
    final verifier = SchemaVerifier(GeneratedHelper());

    test('v1 -> v2 migration yields a schema matching the v2 definition',
        () async {
      // Open a fresh v1 database (25 tables, no expense_categories) and run the
      // app's migration to v2. migrateAndValidate throws if the resulting
      // schema doesn't match the generated v2 definition — i.e. this is the
      // "fresh install == upgrade install" guarantee.
      final connection = await verifier.startAt(1);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 2);
    });

    test('v1 -> v2 migration preserves pre-existing rows', () async {
      // v1→v2 only adds the expense_categories table, so existing data is safe
      // by construction — but this exercises the data-integrity path that
      // future (column-changing) migrations must keep passing.
      final schema = await verifier.schemaAt(1);
      // rawDatabase is the synchronous sqlite3 handle — no await.
      schema.rawDatabase.execute(
        "INSERT INTO user_accounts (user_id, display_name) "
        "VALUES ('user-001', '默认用户')",
      );

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);
      await db.close();

      final rows = schema.rawDatabase.select(
        'SELECT display_name FROM user_accounts WHERE user_id = ?',
        ['user-001'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['display_name'], '默认用户');
    });

    test('fresh install creates the full schema and enables foreign keys',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      // Force open so onCreate + beforeOpen run.
      await db.customSelect('SELECT 1').get();

      // beforeOpen must enable FK regardless of the connection's setup.
      final fk =
          (await db.customSelect('PRAGMA foreign_keys').get()).single.data;
      expect(fk['foreign_keys'], 1);

      // Fresh schema matches the generated definition (no missing/extra tables).
      await db.validateDatabaseSchema();
    });

    test('v5 -> v6 migration yields a schema matching the v6 definition',
        () async {
      // v5→v6: 生活瞬间两张新表 life_moment / moment_photo（P4-1）。只 createTable，
      // 不触碰既有表，旧库升级零数据风险。migrateAndValidate 校验升级后 schema
      // 与 fresh v6 定义一致（即「fresh install == upgrade install」）。
      final connection = await verifier.startAt(5);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 6);
    });

    test('v5 -> v6 migration preserves pre-existing rows', () async {
      // v6 仅新增表，既有数据不受影响；此处验证升级路径不丢旧数据
      // （以 user_accounts 为代表），并确认新表 life_moment 可用。
      final schema = await verifier.schemaAt(5);
      schema.rawDatabase.execute(
        "INSERT INTO user_accounts (user_id, display_name) "
        "VALUES ('user-001', '默认用户')",
      );

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 6);
      await db.close();

      final rows = schema.rawDatabase.select(
        'SELECT display_name FROM user_accounts WHERE user_id = ?',
        ['user-001'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['display_name'], '默认用户');

      // 新表存在且空（升级未破坏其创建）。
      final momentRows = schema.rawDatabase.select('SELECT COUNT(*) AS c FROM life_moment');
      expect(momentRows.single['c'], 0);
    });

    test('v6 -> v7 migration yields a schema matching the v7 definition',
        () async {
      // v6→v7: DailyReviewLog 加结构化复盘三列 highlight/improve/tomorrow（P4-2）。
      // 均 addColumn、可空，旧库升级零数据风险。migrateAndValidate 校验升级后 schema
      // 与 fresh v7 定义一致（即「fresh install == upgrade install」）。
      final connection = await verifier.startAt(6);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 7);
    });

    test('v6 -> v7 migration preserves review rows and adds nullable columns',
        () async {
      // 既有 daily_review_log 行的旧列（review_date/mood_tag/insights_content/
      // summary_snapshot_json）升级后必须保留；新增的三列对存量行落 NULL（可空）。
      final schema = await verifier.schemaAt(6);
      schema.rawDatabase.execute(
        "INSERT INTO user_accounts (user_id, display_name) "
        "VALUES ('user-001', '默认用户')",
      );
      schema.rawDatabase.execute(
        "INSERT INTO daily_review_log "
        "(review_date, user_id, mood_tag, insights_content, summary_snapshot_json) "
        "VALUES (1721779200, 'user-001', '😊', '旧复盘内容', '{\"expense\":50}')",
      );

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 7);
      await db.close();

      final rows = schema.rawDatabase.select(
        'SELECT mood_tag, insights_content, summary_snapshot_json, '
        'highlight_text, improve_text, tomorrow_plan_text '
        'FROM daily_review_log WHERE user_id = ?',
        ['user-001'],
      );
      expect(rows, hasLength(1));
      final r = rows.first;
      // 旧列保留。
      expect(r['mood_tag'], '😊');
      expect(r['insights_content'], '旧复盘内容');
      expect(r['summary_snapshot_json'], '{"expense":50}');
      // 新列存在且对存量行为 NULL（可空，旧库升级零数据风险）。
      expect(r['highlight_text'], isNull);
      expect(r['improve_text'], isNull);
      expect(r['tomorrow_plan_text'], isNull);
    });
  });
}
