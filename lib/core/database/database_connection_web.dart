import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Opens the web database.
///
/// **No encryption on web** (documented degradation): the browser's
/// `indexedDb` storage used by `WebDatabase` does not support SQLCipher, so
/// `PRAGMA key` is not applicable here. Native platforms (Android/iOS/desktop)
/// are SQLCipher-encrypted via [applySqlCipherSetup]; web is plaintext.
///
/// Consequence (per docs/LifeOS-开发执行计划.md §5 risk 4): the web build is
/// for development/demo only and must not be treated as a trusted store for
/// sensitive data. Sensitive features should gate themselves off on web until
/// a web encryption strategy is added.
QueryExecutor createDatabaseConnection() {
  return WebDatabase.withStorage(
    DriftWebStorage.indexedDb('life_os_web_db'),
    setup: (db) {
      db.run('PRAGMA foreign_keys = ON');
    },
  );
}
