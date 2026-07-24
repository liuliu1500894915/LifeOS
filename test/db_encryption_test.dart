import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:life_os/core/crypto/key_store.dart';
import 'package:life_os/core/database/database_connection_native.dart';

/// Verifies the SQLCipher connection path end-to-end:
///   1. a key from [DbKeyStore] round-trips a real database file, and
///   2. a *wrong* key is rejected.
///
/// (2) only holds under a real SQLCipher build. The plain-sqlite3 library used
/// by the host test runner silently ignores `PRAGMA key`, so we probe
/// `cipher_version`: if SQLCipher is absent we still run the round-trip (which
/// exercises the PRAGMA sequence / connection code path) and skip the wrong-key
/// rejection with a notice. On a device/emulator (where `sqlcipher_flutter_libs`
/// ships the real cipher) the full assertion runs.
void main() {
  test('DB opened with the generated key round-trips data; wrong key rejected',
      () async {
    final backend = _MemoryBackend();
    final keyHex = await DbKeyStore(backend: backend).getOrCreateRawKeyHex();
    expect(DbKeyStore.isValidRawKeyHex(keyHex), isTrue);

    final dir = await Directory.systemTemp.createTemp('life_os_cipher_');
    addTearDown(() => dir.delete(recursive: true));
    final dbFile = File('${dir.path}/life_os.db');

    Database openWithKey(String keyHex) {
      final db = sqlite3.open(dbFile.path);
      applySqlCipherSetup(db, keyHex);
      return db;
    }

    // Write with the real key.
    final writer = openWithKey(keyHex);
    writer.execute('CREATE TABLE t(a INTEGER)');
    writer.execute('INSERT INTO t VALUES (42)');
    writer.dispose();

    // Reopen with the SAME key → readable.
    final reader = openWithKey(keyHex);
    final rows = reader.select('SELECT a FROM t');
    expect(rows.first['a'], 42);
    reader.dispose();

    // Detect whether the running sqlite is actually SQLCipher.
    final hasCipher = _detectSqlCipher();
    if (!hasCipher) {
      // Host plain-sqlite ignores PRAGMA key, so wrong-key rejection can't be
      // verified here. Verified on device/emulator instead.
      // ignore: avoid_print, intentional host-only skip diagnostic
      print('SQLCipher not present on this runner — skipped wrong-key '
          'rejection assertion (round-trip still passed).');
      return;
    }

    // Reopen with a DIFFERENT key → must be rejected.
    final wrongKey = DbKeyStore.generateRawKeyHex();
    expect(wrongKey, isNot(keyHex));
    final bad = openWithKey(wrongKey);
    addTearDown(bad.dispose);
    expect(() => bad.select('SELECT a FROM t'), throwsA(anything));
  });
}

bool _detectSqlCipher() {
  final probe = sqlite3.openInMemory();
  try {
    final rows = probe.select('PRAGMA cipher_version');
    return rows.isNotEmpty &&
        (rows.first['cipher_version'] as String?)?.isNotEmpty == true;
  } catch (_) {
    return false;
  } finally {
    probe.dispose();
  }
}

class _MemoryBackend implements SecureStorageBackend {
  final Map<String, String> map = {};

  @override
  Future<String?> read({required String key}) async => map[key];

  @override
  Future<void> write({required String key, required String value}) async {
    map[key] = value;
  }
}
