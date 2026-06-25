import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'storage_service.dart';

/// Persists user's X25519 key pair in the device's secure enclave.
/// iOS: Keychain  |  Android: Keystore (EncryptedSharedPreferences)
/// Web: SharedPreferences (window.localStorage) — survives page reloads.
/// The private key NEVER leaves this device.
class KeyStore {
  static final _storage = StorageService();

  static const _kUserId     = 'user_id';
  static const _kUsername   = 'username';

  static String _privateKeyKey(String uid) => 'x25519_private_$uid';
  static String _publicKeyKey(String uid) => 'x25519_public_$uid';
  static String _authTokenKey(String uid) => 'auth_token_$uid';

  /// Returns the currently-stored user ID (last-logged-in user).
  static Future<String?> getUserId() => _storage.read(_kUserId);

  /// Returns the currently-stored username.
  static Future<String?> getUsername() => _storage.read(_kUsername);

  static Future<bool> hasIdentity() async {
    final id = await _storage.read(_kUserId);
    return id != null;
  }

  static Future<void> saveIdentity({
    required String userId,
    required String username,
  }) async {
    try {
      await _storage.write(_kUserId, userId);
      await _storage.write(_kUsername, username);
    } catch (e) {
      debugPrint('KEYSTORE: Error saving identity: $e');
      rethrow;
    }
  }

  // ── Key pair (scoped per-user) ─────────────────────────────────────────────

  static Future<void> saveKeyPair(SimpleKeyPair keyPair, {String? userId}) async {
    final uid = userId ?? await getUserId();
    if (uid == null) {
      debugPrint('KEYSTORE: Cannot save key pair — no userId');
      return;
    }
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBase64 = base64Encode(publicKey.bytes);
    final secretKey = await keyPair.extract();
    final privateKeyBase64 = base64Encode(secretKey.bytes);

    try {
      await _storage.write(_privateKeyKey(uid), privateKeyBase64);
      await _storage.write(_publicKeyKey(uid), publicKeyBase64);
    } catch (e) {
      debugPrint('KEYSTORE: Error saving key pair: $e');
      rethrow;
    }
  }

  static Future<SimpleKeyPair?> loadKeyPair({String? userId}) async {
    final uid = userId ?? await getUserId();
    if (uid == null) return null;
    try {
      var privateKeyBase64 = await _storage.read(_privateKeyKey(uid));
      var publicKeyBase64 = await _storage.read(_publicKeyKey(uid));

      // Migrate from old unscoped keys (pre-per-user-scoping)
      if (privateKeyBase64 == null || publicKeyBase64 == null) {
        const legacyPriv = 'x25519_private';
        const legacyPub = 'x25519_public';
        privateKeyBase64 = await _storage.read(legacyPriv);
        publicKeyBase64 = await _storage.read(legacyPub);
        if (privateKeyBase64 != null && publicKeyBase64 != null) {
          await _storage.write(_privateKeyKey(uid), privateKeyBase64);
          await _storage.write(_publicKeyKey(uid), publicKeyBase64);
          await _storage.delete(legacyPriv);
          await _storage.delete(legacyPub);
        }
      }

      if (privateKeyBase64 == null || publicKeyBase64 == null) {
        debugPrint('KEYSTORE: No key pair found for user $uid');
        return null;
      }

      final publicKey = SimplePublicKey(
        base64Decode(publicKeyBase64),
        type: KeyPairType.x25519,
      );
      final privateKeyBytes = base64Decode(privateKeyBase64);
      final keyPairData = SimpleKeyPairData(
        privateKeyBytes,
        publicKey: publicKey,
        type: KeyPairType.x25519,
      );
      return keyPairData;
    } catch (e) {
      debugPrint('KEYSTORE: Error loading key pair: $e');
      return null;
    }
  }

  static Future<String?> getPublicKeyBase64({String? userId}) async {
    final uid = userId ?? await getUserId();
    if (uid == null) return null;
    return _storage.read(_publicKeyKey(uid));
  }

  // ── Auth token (scoped per-user) ───────────────────────────────────────────

  static Future<String?> getAuthToken({String? userId}) async {
    final uid = userId ?? await getUserId();
    if (uid == null) return null;
    return _storage.read(_authTokenKey(uid));
  }

  static Future<void> saveAuthToken(String token, {String? userId}) async {
    final uid = userId ?? await getUserId();
    if (uid == null) {
      debugPrint('KEYSTORE: Cannot save auth token — no userId');
      return;
    }
    try {
      await _storage.write(_authTokenKey(uid), token);
    } catch (e) {
      debugPrint('KEYSTORE: Error saving token: $e');
      rethrow;
    }
  }

  static Future<void> clearAuthToken({String? userId}) async {
    final uid = userId ?? await getUserId();
    if (uid == null) return;
    await _storage.delete(_authTokenKey(uid));
  }

  /// Wipe everything — useful for "sign out" or "reset app".
  static Future<void> clear() async {
    debugPrint('KEYSTORE: Clearing all storage');
    try {
      await _storage.delete(_kUserId);
      await _storage.delete(_kUsername);
      // Remove user-scoped keys for current user
      final uid = await getUserId();
      if (uid != null) {
        await _storage.delete(_privateKeyKey(uid));
        await _storage.delete(_publicKeyKey(uid));
        await _storage.delete(_authTokenKey(uid));
      }
      // Clean up legacy unscoped keys
      await _storage.delete('x25519_private');
      await _storage.delete('x25519_public');
      await _storage.delete('auth_token');
      // Messages are intentionally NOT cleared — they persist locally
      // and auto-delete 24 hours after being read.
    } catch (e) {
      debugPrint('KEYSTORE: Error clearing storage: $e');
    }
  }
}
