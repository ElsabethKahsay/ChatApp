import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:cryptography/cryptography.dart';
import 'api_service.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import 'socket_service.dart';

class MediaService {
  static final _picker = ImagePicker();
  static final _dio = Dio();

  /// V1 PERFECTION: Handles E2E Encrypted Media Upload (Image or Voice)
  static Future<void> uploadAndSend({
    required String toId,
    required List<int> bytes,
    required String extension,
    required SecretKey encryptionKey,
    required bool isGroup,
    required String type, // 'image' or 'voice'
  }) async {
    try {
      // 1. Double Encryption: Encrypt file bytes
      final encrypted = await CryptoService.encryptBytes(Uint8List.fromList(bytes), encryptionKey);

      // 2. Get Presigned URL from Backend
      final token = await KeyStore.getAuthToken();
      final presign = await ApiService.getPresignedUrl(token!, extension);

      // 3. Secure Upload to B2
      await _dio.put(
        presign['uploadUrl'],
        data: encrypted['cipherBytes'],
        options: Options(headers: {'Content-Type': 'application/octet-stream'}),
      );

      // 4. Relay Metadata via Socket
      final payload = {
        'url': presign['downloadUrl'] as String,
        'nonce': base64.encode(encrypted['nonce']!),
        'mac': base64.encode(encrypted['mac']!),
        'type': type,
      };

      if (isGroup) {
        SocketService.sendGroupMessage(groupId: toId, encryptedPayload: Map<String, String>.from(payload), messageId: presign['key']);
      } else {
        SocketService.sendMessage(toUserId: toId, encryptedPayload: Map<String, String>.from(payload), messageId: presign['key']);
      }
    } catch (e) {
      print('❌ V1 Media Error: $e');
    }
  }

  static Future<void> pickAndSendImage({required String toId, required SecretKey encryptionKey, required bool isGroup}) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    final bytes = await File(image.path).readAsBytes();
    final ext = p.extension(image.path).replaceAll('.', '');
    await uploadAndSend(toId: toId, bytes: bytes, extension: ext, encryptionKey: encryptionKey, isGroup: isGroup, type: 'image');
  }
}
