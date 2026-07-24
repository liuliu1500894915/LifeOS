import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

import '../crypto/encryption_config.dart';

QueryExecutor createDatabaseConnection(EncryptionConfig config) {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseImplementation: WebImplementation.inWebWorker,
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
