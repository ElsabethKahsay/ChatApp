import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

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
  /// Throws if authentication fails (tampered message).
  static Future<String> decrypt(
    Map<String, dynamic> encrypted,
    SecretKey sharedSecret,
  ) async {
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      base64Decode(encrypted['ciphertext'] as String),
      nonce: base64Decode(encrypted['nonce'] as String),
      mac: Mac(base64Decode(encrypted['mac'] as String)),
    );
    final plainBytes = await algorithm.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );
    return utf8.decode(plainBytes);
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
