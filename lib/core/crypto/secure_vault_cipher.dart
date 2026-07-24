import 'dart:convert';

/// Obfuscation helper for the secure-documents vault.
///
/// NOTE: this is **not real cryptography** — it base64-encodes the payload with
/// a constant tag prefix. It only defeats casual shoulder-surfing of values
/// stored in the local DB, not a determined attacker with DB access.
///
/// TODO(vault-security): replace with authenticated encryption (AES-GCM) keyed
/// from platform secure storage, and make the API async. This is a separate
/// task from the DB-encryption-key work (P0-1) and is tracked there as a
/// follow-up. The tag below is a non-secret format marker, deliberately *not*
/// the DB encryption key.
class SecureVaultCipher {
  const SecureVaultCipher._();

  /// Non-secret payload tag. Changing it invalidates values encoded with a
  /// prior tag (dev-only impact); decrypt falls back gracefully.
  static const String _payloadTag = 'life_os_vault_v1';

  static String encrypt(String plainText) {
    final salted = '$_payloadTag::$plainText';
    return base64Encode(utf8.encode(salted));
  }

  static String decrypt(String encryptedText) {
    // Legacy plaintext passthrough: values already stored unencrypted with the
    // `ENC:` marker decode as-is.
    if (encryptedText.startsWith('ENC:')) {
      return encryptedText.substring(4);
    }

    try {
      final decoded = utf8.decode(base64Decode(encryptedText));
      final prefix = '$_payloadTag::';
      if (decoded.startsWith(prefix)) {
        return decoded.substring(prefix.length);
      }
      return decoded;
    } catch (_) {
      return encryptedText;
    }
  }
}
