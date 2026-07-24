import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value backend that [DbKeyStore] depends on.
///
/// Exists so the key lifecycle can be unit-tested with an in-memory fake —
/// the real [FlutterSecureStorage] is a platform plugin with no host-side
/// implementation and cannot run inside `flutter test`.
abstract interface class SecureStorageBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
}

class FlutterSecureStorageBackend implements SecureStorageBackend {
  FlutterSecureStorageBackend([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(
          // resetOnError lets a corrupted entry self-heal instead of bricking
          // first launch. (flutter_secure_storage 9.x migrated off the
          // deprecated EncryptedSharedPreferences to its own ciphers, so we do
          // not set that flag.)
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          aOptions: AndroidOptions(resetOnError: true),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

/// Owns the lifecycle of the SQLCipher database encryption key.
///
/// The key is a 32-byte (256-bit) random value generated once on first launch
/// and persisted to platform secure storage (Android Keystore / iOS Keychain
/// via [FlutterSecureStorage]). It is then applied to SQLCipher as a *raw*
/// key (`PRAGMA key = "x'<hex>'"`), which bypasses the PBKDF2 KDF — a random
/// 256-bit key needs no stretching.
///
/// Reinstalling the app gives a fresh key; the previous install's DB cannot be
/// decrypted (expected — there is no server-side key escrow).
class DbKeyStore {
  DbKeyStore({SecureStorageBackend? backend})
      : _backend = backend ?? FlutterSecureStorageBackend();

  /// Storage key under which the DB cipher key is persisted.
  static const String storageKey = 'life_os_db_cipher_key_v1';

  /// Length of the raw key in bytes (256-bit).
  static const int keyLengthBytes = 32;

  final SecureStorageBackend _backend;

  /// Returns the raw SQLCipher key as 64 lowercase hex chars, generating and
  /// persisting it on first call. Idempotent: repeated calls return the same
  /// value. If the stored entry is missing or fails validation, a fresh key is
  /// generated and overwrites it.
  Future<String> getOrCreateRawKeyHex() async {
    final existing = await _backend.read(key: storageKey);
    if (existing != null && isValidRawKeyHex(existing)) {
      return existing;
    }
    final generated = generateRawKeyHex();
    await _backend.write(key: storageKey, value: generated);
    return generated;
  }

  /// Generates a fresh random raw key as 64 lowercase hex chars.
  static String generateRawKeyHex() {
    final rng = Random.secure();
    final bytes = List<int>.generate(keyLengthBytes, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// A valid raw key is exactly 64 lowercase hex chars (32 bytes).
  static bool isValidRawKeyHex(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}
