import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'crypto_service.dart';
import '../services/message_store.dart';

/// Persists user's X25519 key pair in the device's secure enclave.
/// iOS: Keychain  |  Android: Keystore (EncryptedSharedPreferences)
/// The private key NEVER leaves this device.
class KeyStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  
  // In-memory fallback for web development
  static final Map<String, String> _memoryStorage = {};
  

  static const _kPrivateKey = 'x25519_private';
  static const _kPublicKey  = 'x25519_public';
  static const _kUserId     = 'user_id';
  static const _kUsername   = 'username';
  static const _kAuthToken  = 'auth_token';

  // ── Key pair ───────────────────────────────────────────────────────────────

  static Future<void> saveKeyPair(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBase64 = base64Encode(publicKey.bytes);
    // For private key, extract the secret key bytes
    final secretKey = await keyPair.extract();
    final privateKeyBase64 = base64Encode(secretKey.bytes);
    print('KEYSTORE: Saving key pair');
    print('   Is web: $kIsWeb');
    
    try {
      if (kIsWeb) {
        _memoryStorage[_kPrivateKey] = privateKeyBase64;
        _memoryStorage[_kPublicKey] = publicKeyBase64;
        print('KEYSTORE: Key pair saved to memory (web)');
      } else {
        await _storage.write(key: _kPrivateKey, value: privateKeyBase64);
        await _storage.write(key: _kPublicKey,  value: publicKeyBase64);
        print('KEYSTORE: Key pair saved to secure storage');
      }
    } catch (e) {
      print('KEYSTORE: Error saving key pair: $e');
      rethrow;
    }
  }

  static Future<SimpleKeyPair?> loadKeyPair() async {
    try {
      String? privateKeyBase64;
      String? publicKeyBase64;
      
      if (kIsWeb) {
        privateKeyBase64 = _memoryStorage[_kPrivateKey];
        publicKeyBase64 = _memoryStorage[_kPublicKey];
        print('KEYSTORE: Loading key pair from memory (web)');
      } else {
        privateKeyBase64 = await _storage.read(key: _kPrivateKey);
        publicKeyBase64 = await _storage.read(key: _kPublicKey);
        print('KEYSTORE: Loading key pair from secure storage');
      }
      
      if (privateKeyBase64 == null || publicKeyBase64 == null) {
        print('KEYSTORE: No key pair found');
        return null;
      }

      // Reconstruct key pair from stored bytes using X25519
      final publicKey = SimplePublicKey(
        base64Decode(publicKeyBase64!),
        type: KeyPairType.x25519,
      );
      final privateKeyBytes = base64Decode(privateKeyBase64!);
      // Create key pair data from the private key bytes
      final keyPairData = SimpleKeyPairData(
        privateKeyBytes,
        publicKey: publicKey,
        type: KeyPairType.x25519,
      );
      print('KEYSTORE: Key pair loaded successfully');
      return keyPairData;
    } catch (e) {
      print('KEYSTORE: Error loading key pair: $e');
      return null;
    }
  }

  static Future<String?> getPublicKeyBase64() async {
    if (kIsWeb) {
      return _memoryStorage[_kPublicKey];
    } else {
      return _storage.read(key: _kPublicKey);
    }
  }

  // ── User identity ──────────────────────────────────────────────────────────

  static Future<void> saveIdentity({
    required String userId,
    required String username,
  }) async {
    print('KEYSTORE: Saving identity');
    print('   User ID: $userId');
    print('   Username: $username');
    print('   Is web: $kIsWeb');
    
    try {
      if (kIsWeb) {
        _memoryStorage[_kUserId] = userId;
        _memoryStorage[_kUsername] = username;
        print('KEYSTORE: Identity saved to memory (web)');
      } else {
        await _storage.write(key: _kUserId,   value: userId);
        await _storage.write(key: _kUsername, value: username);
        print('KEYSTORE: Identity saved to secure storage');
      }
    } catch (e) {
      print('KEYSTORE: Error saving identity: $e');
      rethrow;
    }
  }

  static Future<String?> getUserId() async {
    try {
      String? userId;
      if (kIsWeb) {
        userId = _memoryStorage[_kUserId];
        print('KEYSTORE: Getting user ID from memory');
      } else {
        userId = await _storage.read(key: _kUserId);
        print('KEYSTORE: Getting user ID from secure storage');
      }
      print('   User ID exists: ${userId != null}');
      print('   User ID: $userId');
      return userId;
    } catch (e) {
      print('KEYSTORE: Error getting user ID: $e');
      return null;
    }
  }
  static Future<String?> getUsername() async {
    if (kIsWeb) {
      return _memoryStorage[_kUsername];
    } else {
      return _storage.read(key: _kUsername);
    }
  }
  static Future<String?> getAuthToken() async {
    String? token;
    if (kIsWeb) {
      token = _memoryStorage[_kAuthToken];
    } else {
      token = await _storage.read(key: _kAuthToken);
    }
    print('KEYSTORE: Getting auth token');
    print('   Token exists: ${token != null}');
    print('   Token length: ${token?.length ?? 0}');
    if (token != null) {
      print('   Token preview: ${token.substring(0, 20)}...');
    }
    return token;
  }

  static Future<void> saveAuthToken(String token) async {
    print('KEYSTORE: Saving auth token');
    print('   Token length: ${token.length}');
    print('   Token preview: ${token.substring(0, 20)}...');
    print('   Is web: $kIsWeb');
    
    try {
      if (kIsWeb) {
        _memoryStorage[_kAuthToken] = token;
        print('KEYSTORE: Token saved to memory (web)');
      } else {
        await _storage.write(key: _kAuthToken, value: token);
        print('KEYSTORE: Token saved to secure storage');
      }
    } catch (e) {
      print('KEYSTORE: Error saving token: $e');
      rethrow;
    }
  }

  static Future<void> clearAuthToken() async {
    print('KEYSTORE: Clearing auth token');
    try {
      if (kIsWeb) {
        _memoryStorage.remove(_kAuthToken);
        print('KEYSTORE: Token cleared from memory (web)');
      } else {
        await _storage.delete(key: _kAuthToken);
        print('KEYSTORE: Token cleared from secure storage');
      }
    } catch (e) {
      print('KEYSTORE: Error clearing token: $e');
    }
  }

  static Future<bool> hasIdentity() async {
    if (kIsWeb) {
      return _memoryStorage[_kUserId] != null;
    } else {
      final id = await _storage.read(key: _kUserId);
      return id != null;
    }
  }

  /// Wipe everything — useful for "sign out" or "reset app".
  static Future<void> clear() async {
    print('KEYSTORE: Clearing all storage');
    try {
      if (kIsWeb) {
        _memoryStorage.clear();
        print('KEYSTORE: Memory cleared (web)');
      } else {
        await _storage.deleteAll();
        print('KEYSTORE: Secure storage cleared');
      }
      await MessageStore.clearAll();
      print('KEYSTORE: All storage cleared successfully');
    } catch (e) {
      print('KEYSTORE: Error clearing storage: $e');
    }
  }
}
