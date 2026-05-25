import 'dart:convert';

import 'encryption_config.dart';

class SecureVaultCipher {
  const SecureVaultCipher._();

  static String encrypt(String plainText) {
    final key = EncryptionConfig.defaultKey;
    final salted = '$key::$plainText';
    return base64Encode(utf8.encode(salted));
  }

  static String decrypt(String encryptedText) {
    final decoded = utf8.decode(base64Decode(encryptedText));
    final prefix = '${EncryptionConfig.defaultKey}::';
    if (decoded.startsWith(prefix)) {
      return decoded.substring(prefix.length);
    }
    return decoded;
  }
}
