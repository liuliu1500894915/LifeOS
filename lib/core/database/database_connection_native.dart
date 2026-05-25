import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/encryption_config.dart';

QueryExecutor createDatabaseConnection(EncryptionConfig config) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = p.join(dbFolder.path, 'life_os.db');

    return NativeDatabase.createInBackground(
      File(file),
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '${config.key}'");
        rawDb.execute('PRAGMA cipher_page_size = ${EncryptionConfig.pageSize}');
        rawDb.execute('PRAGMA kdf_iter = ${EncryptionConfig.kdfIter}');
        rawDb.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
        rawDb.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
        rawDb.execute('PRAGMA foreign_keys = ON');
        rawDb.execute('PRAGMA journal_mode = WAL');
        rawDb.execute('PRAGMA busy_timeout = 5000');
      },
    );
  });
}
