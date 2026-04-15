import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import 'api_service.dart';

class GroupService {
  final CryptoService _crypto = CryptoService();

  /// Creates a group and distributes the Group Key to all members
  Future<void> createSecureGroup(String name, List<String> memberIds) async {
    final token = await KeyStore.getAuthToken();
    final myKeyPair = await KeyStore.loadKeyPair();
    
    if (token == null || myKeyPair == null) throw Exception('Auth failed');

    // 1. Generate a random Group Key (AES-256)
    final aesGen = AesGcm.with256bits();
    final groupKey = await aesGen.newSecretKey();
    final groupKeyBytes = await groupKey.extractBytes();

    Map<String, Map<String, String>> encryptedKeys = {};

    // 2. Wrap the key for every member (including self)
    final allMembers = [...memberIds, await KeyStore.getUserId() ?? ''];
    
    for (String userId in allMembers) {
      // Fetch the member's public key from the server
      final memberPubKeyBase64 = await ApiService.getPublicKey(userId, token);
      final memberPubKey = await CryptoService.importPublicKey(memberPubKeyBase64);
      
      // Derive a secret for this specific member
      final sharedSecret = await CryptoService.deriveSharedSecret(myKeyPair, memberPubKey);
      
      // Encrypt the Group Key using the shared secret
      final wrapped = await _crypto.encrypt(base64Encode(groupKeyBytes), sharedSecret);
      
      encryptedKeys[userId] = {
        'ciphertext': wrapped['ciphertext']!,
        'nonce': wrapped['nonce']!,
      };
    }

    // 3. Post the group metadata and wrapped keys to the server
    await ApiService.createGroup(
      token: token,
      name: name,
      members: memberIds,
      encryptedKeys: encryptedKeys,
    );
  }
}