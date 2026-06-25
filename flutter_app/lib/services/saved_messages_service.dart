import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Save media file to persistent storage
  /// This prevents the media from being auto-deleted
  static Future<String> saveMediaFile(String sourcePath, String messageId) async {
    try {
      // Get persistent storage directory
      final appDir = await getApplicationDocumentsDirectory();
      final savedMediaDir = Directory('${appDir.path}/saved_media');
      
      // Create directory if it doesn't exist
      if (!await savedMediaDir.exists()) {
        await savedMediaDir.create(recursive: true);
      }
      
      // Get file extension
      final sourceFile = File(sourcePath);
      final extension = sourcePath.split('.').last;
      
      // Create new filename with messageId
      final savedPath = '${savedMediaDir.path}/${messageId}_saved.$extension';
      
      // Copy file to persistent location
      await sourceFile.copy(savedPath);
      
      debugPrint('💾 Media saved to: $savedPath');
      return savedPath;
    } catch (e) {
      debugPrint('❌ Failed to save media: $e');
      throw Exception('Failed to save media: $e');
    }
  }
  
  /// Check if media file is saved
  static Future<bool> isMediaSaved(String messageId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savedMediaDir = Directory('${appDir.path}/saved_media');
      
      if (!await savedMediaDir.exists()) return false;
      
      // Check for any file with this messageId
      final files = await savedMediaDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.contains('${messageId}_saved')) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Get saved media path
  static Future<String?> getSavedMediaPath(String messageId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savedMediaDir = Directory('${appDir.path}/saved_media');
      
      if (!await savedMediaDir.exists()) return null;
      
      final files = await savedMediaDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.contains('${messageId}_saved')) {
          return file.path;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}