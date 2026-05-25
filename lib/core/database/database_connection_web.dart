import 'package:drift/drift.dart';
import 'package:drift/web.dart';

import '../crypto/encryption_config.dart';

QueryExecutor createDatabaseConnection(EncryptionConfig config) {
  return WebDatabase.withStorage(
    DriftWebStorage.indexedDb('life_os_web_db'),
    setup: (db) {
      db.run('PRAGMA foreign_keys = ON');
    },
  );
}
