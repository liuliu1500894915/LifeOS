/// Non-secret SQLCipher configuration constants.
///
/// The encryption **key** is NOT defined here. It is generated on first launch
/// and stored in platform secure storage — see `key_store.dart`. This file
/// holds only parameters that are non-secret and must stay stable across opens
/// of the same database (page size).
class EncryptionConfig {
  const EncryptionConfig._();

  /// SQLCipher page size in bytes. Non-secret; must match the value used when
  /// the database was first created.
  static const int pageSize = 4096;
}
