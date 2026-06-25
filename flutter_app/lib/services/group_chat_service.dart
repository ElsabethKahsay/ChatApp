import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import '../models/group.dart';
import 'api_service.dart';

class GroupChatService {
  static Future<SecretKey> _generateGroupKey() async {
    final algorithm = AesGcm.with256bits();
    return await algorithm.newSecretKey();
  }

  static Future<Group> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final token = await KeyStore.getAuthToken();
    final myUserId = await KeyStore.getUserId();
    if (token == null || myUserId == null) throw Exception('Auth session missing');

    if (!memberIds.contains(myUserId)) memberIds.add(myUserId);

    final groupKey = await _generateGroupKey();
    final groupKeyBytes = await groupKey.extractBytes();
    final myKeyPair = await KeyStore.loadKeyPair();
    final myPublicKey = await CryptoService.exportPublicKey(myKeyPair!);

    final encryptedKeys = <String, Map<String, String>>{};
    
    for (final memberId in memberIds) {
      final peerKeyB64 = await ApiService.getPublicKey(memberId, token);
      final sharedSecret = await CryptoService.deriveSharedSecret(
        myKeyPair,
        await CryptoService.importPublicKey(peerKeyB64)
      );
      encryptedKeys[memberId] = await CryptoService.encrypt(base64Encode(groupKeyBytes), sharedSecret);
    }

    await ApiService.createGroup(
      token: token,
      name: name,
      members: memberIds,
      encryptedKeys: encryptedKeys,
      creatorPublicKey: myPublicKey, // V1 Requirement
    );

    final groups = await ApiService.getGroups(token);
    final json = groups.firstWhere((g) => g['name'] == name);
    return Group.fromJson(json, myUserId);
  }

  static Future<SecretKey> decryptGroupKey(Group group) async {
    try {
      final myKeyPair = await KeyStore.loadKeyPair();
      // V1 FIX: To decrypt, we MUST use the creator's public key to derive the secret
      final creatorPubKey = await CryptoService.importPublicKey(group.creatorPublicKey);
      
      final sharedSecret = await CryptoService.deriveSharedSecret(myKeyPair!, creatorPubKey);
      final decryptedKeyB64 = await CryptoService.decrypt(group.myWrappedKey, sharedSecret);

      return SecretKey(base64Decode(decryptedKeyB64));
    } catch (e) {
      throw Exception('Security Error: Unable to unlock group history.');
    }
  }

  static Future<List<Group>> fetchMyGroups() async {
    final token = await KeyStore.getAuthToken();
    final myUserId = await KeyStore.getUserId();
    final groupsJson = await ApiService.getGroups(token!);
    return groupsJson.map((json) => Group.fromJson(json, myUserId!)).toList();
  }
}
