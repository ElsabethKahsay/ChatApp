import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';

/// SECURITY FIX: Encrypts all values before storing in browser localStorage.
///
/// Browser localStorage is inherently insecure (accessible via JS / XSS).
/// This layer encrypts at-rest data using AES-256-GCM with a key derived
/// from a per-install random salt. This mitigates casual theft (automated
/// scrapers, simple XSS payloads) but cannot fully protect against a
/// sophisticated attacker with persistent JS execution context.
class StorageService {
  static SecretKey? _derivedKey;
  static const _saltKey = '__sc_salt__';
  static const _prefix = '__enc__';

  /// Derive (or re-derive) the encryption key from a per-install salt.
  /// The salt is stored in localStorage itself — this is NOT meant to be
  /// unbreakable, only to raise the bar above plaintext storage.
  Future<SecretKey> _getKey() async {
    if (_derivedKey != null) return _derivedKey!;

    final prefs = await SharedPreferences.getInstance();
    String? saltB64 = prefs.getString(_saltKey);

    if (saltB64 == null) {
      // Generate a random 32-byte salt on first use
      final rng = Random.secure();
      final salt = Uint8List(32);
      for (var i = 0; i < 32; i++) salt[i] = rng.nextInt(256);
      saltB64 = base64Encode(salt);
      await prefs.setString(_saltKey, saltB64);
    }

    final salt = base64Decode(saltB64);

    // Derive a 256-bit key using HKDF with the salt and a fixed app identifier
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    _derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(salt),
      nonce: utf8.encode('SecureChat-Web-Storage-v1'),
    );
    return _derivedKey!;
  }

  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;

    // Support reading legacy unencrypted values (migration path)
    if (!raw.startsWith(_prefix)) {
      // Migrate: encrypt the old plaintext value on read
      await write(key, raw);
      return raw;
    }

    try {
      final encKey = await _getKey();
      final payload = raw.substring(_prefix.length);
      final parts = payload.split('.');
      if (parts.length != 3) return null;

      final nonce = base64Decode(parts[0]);
      final ciphertext = base64Decode(parts[1]);
      final mac = base64Decode(parts[2]);

      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(mac),
      );
      final plainBytes = await algorithm.decrypt(secretBox, secretKey: encKey);
      return utf8.decode(plainBytes);
    } catch (e) {
      // If decryption fails (key changed, corrupted), remove the value
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final encKey = await _getKey();

    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      utf8.encode(value),
      secretKey: encKey,
      nonce: nonce,
    );

    // Store as: __enc__<nonce_b64>.<ciphertext_b64>.<mac_b64>
    final encoded = '$_prefix'
        '${base64Encode(nonce)}.'
        '${base64Encode(secretBox.cipherText)}.'
        '${base64Encode(secretBox.mac.bytes)}';

    await prefs.setString(key, encoded);
  }

  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
