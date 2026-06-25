import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securechat/crypto/crypto_service.dart';

void main() {
  group('CryptoService', () {
    late SimpleKeyPair aliceKeyPair;
    late SimpleKeyPair bobKeyPair;
    late SimplePublicKey alicePublicKey;
    late SimplePublicKey bobPublicKey;

    setUpAll(() async {
      aliceKeyPair = await CryptoService.generateKeyPair();
      bobKeyPair = await CryptoService.generateKeyPair();
      alicePublicKey = await aliceKeyPair.extractPublicKey();
      bobPublicKey = await bobKeyPair.extractPublicKey();
    });

    group('Key generation', () {
      test('generateKeyPair returns a valid key pair', () async {
        final keyPair = await CryptoService.generateKeyPair();
        expect(keyPair, isNotNull);
        final publicKey = await keyPair.extractPublicKey();
        expect(publicKey.bytes.length, 32);
        expect(publicKey.type, KeyPairType.x25519);
      });

      test('exportPublicKey returns a base64 string', () async {
        final b64 = await CryptoService.exportPublicKey(aliceKeyPair);
        expect(b64, isA<String>());
        expect(b64.isNotEmpty, true);
        // X25519 public key is 32 bytes -> 44 base64 chars + padding
        expect(b64.length, 44);
      });

      test('importPublicKey round-trips correctly', () async {
        final b64 = await CryptoService.exportPublicKey(aliceKeyPair);
        final imported = await CryptoService.importPublicKey(b64);
        expect(imported.bytes, alicePublicKey.bytes);
        expect(imported.type, KeyPairType.x25519);
      });

      test('two key pairs are different', () async {
        final kp1 = await CryptoService.generateKeyPair();
        final kp2 = await CryptoService.generateKeyPair();
        final pk1 = await kp1.extractPublicKey();
        final pk2 = await kp2.extractPublicKey();
        expect(pk1.bytes, isNot(equals(pk2.bytes)));
      });
    });

    group('ECDH key agreement', () {
      test('deriveSharedSecret produces same 32-byte secret for both parties',
          () async {
        final secretAlice =
            await CryptoService.deriveSharedSecret(aliceKeyPair, bobPublicKey);
        final secretBob =
            await CryptoService.deriveSharedSecret(bobKeyPair, alicePublicKey);
        final bytesAlice = await secretAlice.extractBytes();
        final bytesBob = await secretBob.extractBytes();
        expect(bytesAlice, bytesBob);
        expect(bytesAlice.length, 32);
      });

      test('different key pairs produce different shared secrets', () async {
        final eveKeyPair = await CryptoService.generateKeyPair();
        final evePublicKey = await eveKeyPair.extractPublicKey();
        final secretAliceBob =
            await CryptoService.deriveSharedSecret(aliceKeyPair, bobPublicKey);
        final secretAliceEve =
            await CryptoService.deriveSharedSecret(aliceKeyPair, evePublicKey);
        final bytesAB = await secretAliceBob.extractBytes();
        final bytesAE = await secretAliceEve.extractBytes();
        expect(bytesAB, isNot(equals(bytesAE)));
      });
    });

    group('Encrypt / Decrypt', () {
      late SecretKey sharedSecret;

      setUpAll(() async {
        sharedSecret =
            await CryptoService.deriveSharedSecret(aliceKeyPair, bobPublicKey);
      });

      test('encrypt and decrypt round-trip a text message', () async {
        const original = 'Hello, SecureChat! 🎉';
        final encrypted = await CryptoService.encrypt(original, sharedSecret);
        expect(encrypted.containsKey('ciphertext'), true);
        expect(encrypted.containsKey('nonce'), true);
        expect(encrypted.containsKey('mac'), true);

        final decrypted = await CryptoService.decrypt(encrypted, sharedSecret);
        expect(decrypted, original);
      });

      test('encrypt and decrypt an empty string', () async {
        const original = '';
        final encrypted = await CryptoService.encrypt(original, sharedSecret);
        final decrypted = await CryptoService.decrypt(encrypted, sharedSecret);
        expect(decrypted, original);
      });

      test('encrypt and decrypt a long message (10KB)', () async {
        final original = 'A' * 10240;
        final encrypted = await CryptoService.encrypt(original, sharedSecret);
        final decrypted = await CryptoService.decrypt(encrypted, sharedSecret);
        expect(decrypted, original);
      });

      test('decrypt with wrong key throws', () async {
        final original = 'Secret message';
        final encrypted = await CryptoService.encrypt(original, sharedSecret);

        final eveKeyPair = await CryptoService.generateKeyPair();
        final evePublicKey = await eveKeyPair.extractPublicKey();
        final wrongSecret =
            await CryptoService.deriveSharedSecret(eveKeyPair, evePublicKey);

        expect(
          () => CryptoService.decrypt(encrypted, wrongSecret),
          throwsA(isA<Exception>()),
        );
      });

      test('decrypt with tampered ciphertext throws', () async {
        const original = 'Tamper test';
        final encrypted = await CryptoService.encrypt(original, sharedSecret);

        // Flip a bit in the ciphertext
        final tampered = Map<String, dynamic>.from(encrypted);
        final ct = base64Decode(tampered['ciphertext'] as String);
        ct[0] ^= 1;
        tampered['ciphertext'] = base64Encode(ct);

        expect(
          () => CryptoService.decrypt(tampered, sharedSecret),
          throwsA(isA<Exception>()),
        );
      });

      test('decrypt with tampered mac throws', () async {
        const original = 'MAC tamper test';
        final encrypted = await CryptoService.encrypt(original, sharedSecret);

        final tampered = Map<String, dynamic>.from(encrypted);
        final mac = base64Decode(tampered['mac'] as String);
        mac[0] ^= 1;
        tampered['mac'] = base64Encode(mac);

        expect(
          () => CryptoService.decrypt(tampered, sharedSecret),
          throwsA(isA<Exception>()),
        );
      });

      test('decrypt with missing fields throws', () async {
        expect(
          () => CryptoService.decrypt({'ciphertext': 'abc'}, sharedSecret),
          throwsA(isA<Exception>()),
        );
        expect(
          () => CryptoService.decrypt({}, sharedSecret),
          throwsA(isA<Exception>()),
        );
      });

      test('uniqueness — each encryption produces different nonce', () async {
        const original = 'Same plaintext';
        final e1 = await CryptoService.encrypt(original, sharedSecret);
        final e2 = await CryptoService.encrypt(original, sharedSecret);
        expect(e1['nonce'], isNot(equals(e2['nonce'])));
        expect(e1['ciphertext'], isNot(equals(e2['ciphertext'])));
      });
    });

    group('File encrypt / decrypt', () {
      late SecretKey sharedSecret;

      setUpAll(() async {
        sharedSecret =
            await CryptoService.deriveSharedSecret(aliceKeyPair, bobPublicKey);
      });

      test('encryptBytes and decryptBytes round-trip', () async {
        final original = Uint8List.fromList(
          List.generate(256, (i) => i % 256),
        );
        final encrypted =
            await CryptoService.encryptBytes(original, sharedSecret);
        expect(encrypted.containsKey('cipherBytes'), true);
        expect(encrypted.containsKey('nonce'), true);
        expect(encrypted.containsKey('mac'), true);

        final decrypted = await CryptoService.decryptBytes(
          encrypted['cipherBytes']!,
          encrypted['nonce']!,
          encrypted['mac']!,
          sharedSecret,
        );
        expect(decrypted, original);
      });

      test('encryptBytes with large data (1MB)', () async {
        final original = Uint8List.fromList(
          List.generate(1024 * 1024, (i) => i % 256),
        );
        final encrypted =
            await CryptoService.encryptBytes(original, sharedSecret);
        final decrypted = await CryptoService.decryptBytes(
          encrypted['cipherBytes']!,
          encrypted['nonce']!,
          encrypted['mac']!,
          sharedSecret,
        );
        expect(decrypted, original);
      });

      test('decryptBytes with wrong key throws', () async {
        final original = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encrypted =
            await CryptoService.encryptBytes(original, sharedSecret);

        final eveKeyPair = await CryptoService.generateKeyPair();
        final evePublicKey = await eveKeyPair.extractPublicKey();
        final wrongSecret =
            await CryptoService.deriveSharedSecret(eveKeyPair, evePublicKey);

        expect(
          () => CryptoService.decryptBytes(
            encrypted['cipherBytes']!,
            encrypted['nonce']!,
            encrypted['mac']!,
            wrongSecret,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
