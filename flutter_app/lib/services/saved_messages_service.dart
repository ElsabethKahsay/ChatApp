import 'package:cryptography/cryptography.dart';
import '../crypto/key_store.dart';
import '../crypto/crypto_service.dart';
import '../models/saved_message.dart';
import 'api_service.dart';

class SavedMessagesService {
  /// Encrypts and saves a message to the user's private vault.
  /// It uses a shared secret derived with the user's own public key for "self-encryption".
  Future<void> saveMessage(String text, {String? label}) async {
    final token = await KeyStore.getAuthToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in.');
    }

    final myKeyPair = await KeyStore.loadKeyPair();
    if (myKeyPair == null) {
      throw Exception('User key pair not found.');
    }
    
    final myPublicKey = await myKeyPair.extractPublicKey();
    final selfSecret = await CryptoService.deriveSharedSecret(myKeyPair, myPublicKey);
    
    final encrypted = await CryptoService.encrypt(text, selfSecret);

    await ApiService.createSavedMessage(
      token: token,
      content: encrypted,
      label: label,
    );
  }

  Future<List<SavedMessage>> fetchSavedMessages() async {
    final token = await KeyStore.getAuthToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in.');
    }
    final List<Map<String, dynamic>> messagesJson = await ApiService.getSavedMessages(token);
    return messagesJson.map((json) => SavedMessage.fromJson(json)).toList();
  }

  Future<String> decryptSavedMessage(SavedMessage msg) async {
    final myKeyPair = await KeyStore.loadKeyPair();
    if (myKeyPair == null) {
      throw Exception('User key pair not found.');
    }
    
    final myPublicKey = await myKeyPair.extractPublicKey();
    final selfSecret = await CryptoService.deriveSharedSecret(myKeyPair, myPublicKey);
    
    return await CryptoService.decrypt(msg.encryptedContent, selfSecret);
  }
}