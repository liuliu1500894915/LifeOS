import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/encryption_config.dart';
import '../crypto/key_store.dart';

/// Opens the native (Android/iOS/desktop) SQLCipher-encrypted database.
///
/// The encryption key is read from platform secure storage inside the lazy
/// opener (the underlying [LazyDatabase] already runs asynchronously), so the
/// synchronous [AppDatabase] constructor is unaffected.
QueryExecutor createDatabaseConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = p.join(dbFolder.path, 'life_os.db');
    final keyHex = await DbKeyStore().getOrCreateRawKeyHex();

    return NativeDatabase.createInBackground(
      File(file),
      setup: (rawDb) => applySqlCipherSetup(rawDb, keyHex),
    );
  });
}

/// Applies the SQLCipher open pragmas to a raw sqlite handle.
///
/// Kept top-level so it runs in the background isolate of
/// [NativeDatabase.createInBackground] and can be reused by tests. [keyHex]
/// must be a validated 64-char hex string (see [DbKeyStore.isValidRawKeyHex]);
/// because the alphabet is only `[0-9a-f]`, formatting it into the `x'...'`
/// raw-key blob literal is injection-safe. SQLCipher skips its PBKDF2 KDF for a
/// raw key, so no `kdf_iter` is set. Cipher settings are applied before `key`,
/// per SQLCipher's ordering requirement.
void applySqlCipherSetup(dynamic rawDb, String keyHex) {
  rawDb.execute('PRAGMA cipher_page_size = ${EncryptionConfig.pageSize}');
  rawDb.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
  rawDb.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
  rawDb.execute("PRAGMA key = \"x'$keyHex'\"");
  rawDb.execute('PRAGMA foreign_keys = ON');
  rawDb.execute('PRAGMA journal_mode = WAL');
  rawDb.execute('PRAGMA busy_timeout = 5000');
}
