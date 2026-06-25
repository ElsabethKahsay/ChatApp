import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'key_store.dart';

/// Handles all cryptographic operations for SecureChat.
/// Key agreement: X25519 (a form of ECDH on Curve25519)
/// Symmetric encryption: AES-256-GCM (authenticated)
class CryptoService {
  // ── Key Pair (X25519 ECDH) ─────────────────────────────────────────────────

  /// Generate a new X25519 key pair. Called once on first launch.
  static Future<SimpleKeyPair> generateKeyPair() async {
    return X25519().newKeyPair();
  }

  /// Export the public key as a base64 string (safe to store on the server).
  static Future<String> exportPublicKey(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Reconstruct a peer's public key from a base64 string.
  static Future<SimplePublicKey> importPublicKey(String base64Key) async {
    final bytes = base64Decode(base64Key);
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  // ── Shared Secret (ECDH) ───────────────────────────────────────────────────

  /// Perform X25519 key agreement → produces a shared secret.
  /// Both sides run this independently and get the same secret.
  /// The server never sees this secret.
  static Future<SecretKey> deriveSharedSecret(
    SimpleKeyPair myKeyPair,
    SimplePublicKey theirPublicKey,
  ) async {
    return X25519().sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: theirPublicKey,
    );
  }

  // ── Forward Secrecy ────────────────────────────────────────────────────────

  /// Generate a new X25519 key pair and save it in KeyStore.
  /// Returns the new public key (base64) to upload to the server.
  static Future<String> rotateKeyPair() async {
    final newKeyPair = await X25519().newKeyPair();
    await KeyStore.saveKeyPair(newKeyPair);
    return exportPublicKey(newKeyPair);
  }

  /// Establish a shared secret from raw key data.
  static Future<SecretKey> establishSharedSecret(
    SecretKey myPrivateKey,
    SimplePublicKey remotePublicKey,
  ) async {
    final myPrivateKeyData = await myPrivateKey.extract();
    final myKeyPair = SimpleKeyPairData(
      myPrivateKeyData.bytes,
      publicKey: remotePublicKey,
      type: KeyPairType.x25519,
    );
    return X25519().sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: remotePublicKey,
    );
  }

  // ── AES-256-GCM Encrypt ────────────────────────────────────────────────────

  /// Encrypts [plaintext] with the given [sharedSecret].
  /// Returns { 'ciphertext', 'nonce', 'mac' } as base64 strings.
  static Future<Map<String, String>> encrypt(
    String plaintext,
    SecretKey sharedSecret,
  ) async {
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: sharedSecret,
      nonce: nonce,
    );
    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  // ── AES-256-GCM Decrypt ────────────────────────────────────────────────────

  /// Decrypts a payload produced by [encrypt].
  /// Throws if authentication fails (tampered message) or if payload is malformed.
  static Future<String> decrypt(
    Map<String, dynamic> encrypted,
    SecretKey sharedSecret,
  ) async {
    try {
      // Validate required fields
      if (encrypted['ciphertext'] == null ||
          encrypted['nonce'] == null ||
          encrypted['mac'] == null) {
        throw Exception('Invalid encrypted payload: missing required fields');
      }

      final ciphertext = base64Decode(encrypted['ciphertext'] as String);
      final nonce = base64Decode(encrypted['nonce'] as String);
      final macBytes = base64Decode(encrypted['mac'] as String);

      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final plainBytes = await algorithm.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );
      return utf8.decode(plainBytes);
    } on FormatException catch (e) {
      throw Exception('Invalid encrypted payload format: $e');
    } on SecretBoxAuthenticationError catch (_) {
      throw Exception('Message authentication failed - possible tampering');
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // ── File Encryption ────────────────────────────────────────────────────────

  /// Encrypts raw file [bytes] with AES-256-GCM.
  /// Returns { cipherBytes, nonce, mac } as Uint8Lists.
  static Future<Map<String, Uint8List>> encryptBytes(
    Uint8List bytes,
    SecretKey sharedSecret,
  ) async {
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      bytes,
      secretKey: sharedSecret,
      nonce: nonce,
    );
    return {
      'cipherBytes': Uint8List.fromList(secretBox.cipherText),
      'nonce': Uint8List.fromList(secretBox.nonce),
      'mac': Uint8List.fromList(secretBox.mac.bytes),
    };
  }

  /// Decrypts file bytes previously encrypted with [encryptBytes].
  static Future<Uint8List> decryptBytes(
    Uint8List cipherBytes,
    Uint8List nonce,
    Uint8List mac,
    SecretKey sharedSecret,
  ) async {
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      cipherBytes,
      nonce: nonce,
      mac: Mac(mac),
    );
    final plain = await algorithm.decrypt(secretBox, secretKey: sharedSecret);
    return Uint8List.fromList(plain);
  }
}
