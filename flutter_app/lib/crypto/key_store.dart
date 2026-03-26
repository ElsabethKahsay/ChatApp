import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's X25519 key pair in the device's secure enclave.
/// iOS: Keychain  |  Android: Keystore (EncryptedSharedPreferences)
/// The private key NEVER leaves this device.
class KeyStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kPrivateKey = 'x25519_private';
  static const _kPublicKey  = 'x25519_public';
  static const _kUserId     = 'user_id';
  static const _kUsername   = 'username';

  // ── Key pair ───────────────────────────────────────────────────────────────

  static Future<void> saveKeyPair(SimpleKeyPair keyPair) async {
    final privateData = await keyPair.extract() as SimpleKeyPairData;
    final publicKey   = await keyPair.extractPublicKey();
    await _storage.write(key: _kPrivateKey, value: base64Encode(privateData.bytes));
    await _storage.write(key: _kPublicKey,  value: base64Encode(publicKey.bytes));
  }

  static Future<SimpleKeyPair?> loadKeyPair() async {
    final privateB64 = await _storage.read(key: _kPrivateKey);
    final publicB64  = await _storage.read(key: _kPublicKey);
    if (privateB64 == null || publicB64 == null) return null;

    return SimpleKeyPairData(
      base64Decode(privateB64),
      publicKey: SimplePublicKey(base64Decode(publicB64), type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }

  static Future<String?> getPublicKeyBase64() async =>
      _storage.read(key: _kPublicKey);

  // ── User identity ──────────────────────────────────────────────────────────

  static Future<void> saveIdentity({
    required String userId,
    required String username,
  }) async {
    await _storage.write(key: _kUserId,   value: userId);
    await _storage.write(key: _kUsername, value: username);
  }

  static Future<String?> getUserId()   => _storage.read(key: _kUserId);
  static Future<String?> getUsername() => _storage.read(key: _kUsername);

  static Future<bool> hasIdentity() async {
    final id = await _storage.read(key: _kUserId);
    return id != null;
  }

  /// Wipe everything — useful for "sign out" or "reset app".
  static Future<void> clear() => _storage.deleteAll();
}
