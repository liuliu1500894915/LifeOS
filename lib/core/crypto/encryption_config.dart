/// SQLCipher encryption configuration.
class EncryptionConfig {
  const EncryptionConfig._({required this.key});

  static const String defaultKey = 'life_os_v1_encryption_key';
  static const int pageSize = 4096;
  static const int kdfIter = 256000;

  final String key;

  factory EncryptionConfig.withDefaultKey() =>
      const EncryptionConfig._(key: defaultKey);
  factory EncryptionConfig.withKey(String key) =>
      EncryptionConfig._(key: key);
}
