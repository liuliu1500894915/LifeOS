import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/crypto/key_store.dart';

/// Dart strings have no `*` operator; replicate the test literals with this.
String _repeat(String s, int n) => List.filled(n, s).join();

void main() {
  group('DbKeyStore', () {
    test('generated key is 64 lowercase hex chars (32 bytes)', () {
      final key = DbKeyStore.generateRawKeyHex();
      expect(DbKeyStore.isValidRawKeyHex(key), isTrue);
      expect(key.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
    });

    test('getOrCreateRawKeyHex persists and is idempotent', () async {
      final backend = _MemoryBackend();
      final store = DbKeyStore(backend: backend);

      final first = await store.getOrCreateRawKeyHex();
      expect(DbKeyStore.isValidRawKeyHex(first), isTrue);
      // Persisted to the backend.
      expect(backend.map[DbKeyStore.storageKey], first);

      // Second call returns the same key, no regeneration.
      final second = await store.getOrCreateRawKeyHex();
      expect(second, first);
    });

    test('a new instance shares the persisted key across stores', () async {
      final backend = _MemoryBackend();
      final first = await DbKeyStore(backend: backend).getOrCreateRawKeyHex();
      // A second store backed by the same storage reuses the key.
      final second = await DbKeyStore(backend: backend).getOrCreateRawKeyHex();
      expect(second, first);
    });

    test('two independent backends get independent keys', () {
      // Randomness sanity: independent stores should (practically) never
      // collide. Probability of collision is ~2^-256.
      final a = DbKeyStore.generateRawKeyHex();
      final b = DbKeyStore.generateRawKeyHex();
      expect(a, isNot(b));
    });

    test('stored valid key is returned unchanged (no overwrite)', () async {
      final preset = _repeat('0123456789abcdef', 4); // 64 hex chars
      final backend = _MemoryBackend(initial: {DbKeyStore.storageKey: preset});

      final key = await DbKeyStore(backend: backend).getOrCreateRawKeyHex();
      expect(key, preset);
    });

    test('corrupt stored value is regenerated and overwritten', () async {
      final backend = _MemoryBackend(initial: {
        DbKeyStore.storageKey: 'not-a-valid-key',
      });

      final key = await DbKeyStore(backend: backend).getOrCreateRawKeyHex();
      expect(DbKeyStore.isValidRawKeyHex(key), isTrue);
      expect(key, isNot('not-a-valid-key'));
      // Backend now holds the fresh valid key.
      expect(backend.map[DbKeyStore.storageKey], key);
    });

    test('isValidRawKeyHex rejects malformed candidates', () {
      expect(DbKeyStore.isValidRawKeyHex(''), isFalse);
      expect(
        DbKeyStore.isValidRawKeyHex(_repeat('ABCDEF0123456789', 4)),
        isFalse,
        reason: 'uppercase rejected',
      );
      expect(DbKeyStore.isValidRawKeyHex(_repeat('0', 63)), isFalse, reason: 'too short');
      expect(DbKeyStore.isValidRawKeyHex(_repeat('0', 65)), isFalse, reason: 'too long');
      expect(DbKeyStore.isValidRawKeyHex(_repeat('g', 64)), isFalse, reason: 'bad char');
      expect(DbKeyStore.isValidRawKeyHex(_repeat('0123456789abcdef', 4)), isTrue);
    });
  });
}

class _MemoryBackend implements SecureStorageBackend {
  _MemoryBackend({Map<String, String>? initial}) : map = {...?initial};

  final Map<String, String> map;

  @override
  Future<String?> read({required String key}) async => map[key];

  @override
  Future<void> write({required String key, required String value}) async {
    map[key] = value;
  }
}
