import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../core/constants.dart';
import '../crypto/crypto_service.dart';

/// Handles encrypted media uploads to Cloudflare R2.
class MediaService {
  // ── Step 1: Get a presigned PUT URL from our backend ──────────────────────

  static Future<Map<String, String>> _presign(File file) async {
    final ext = p.extension(file.path).replaceFirst('.', '');
    final mimeMap = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'png': 'image/png',  'gif': 'image/gif',
      'mp4': 'video/mp4',  'mov': 'video/quicktime',
      'webm': 'video/webm',
    };
    final contentType = mimeMap[ext.toLowerCase()] ?? 'application/octet-stream';

    final resp = await http.post(
      Uri.parse('${Constants.serverUrl}/api/presign'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'extension': ext, 'contentType': contentType}),
    );
    if (resp.statusCode != 200) throw Exception('Presign failed: ${resp.body}');
    return Map<String, String>.from(jsonDecode(resp.body) as Map);
  }

  // ── Step 2: Encrypt the file locally with AES-256-GCM ────────────────────

  // ── Step 3: Upload ciphertext to R2 + return encrypted metadata ──────────

  /// Encrypts [file] and uploads it directly to Cloudflare R2.
  /// Returns a JSON string containing encrypted metadata (downloadUrl, nonce, mac).
  /// This metadata is what gets sent via Socket.IO — R2 never sees plaintext.
  static Future<Map<String, String>> uploadEncryptedMedia(
    File file,
    SecretKey sharedSecret,
  ) async {
    final presign = await _presign(file);
    final bytes   = await file.readAsBytes();
    final enc     = await CryptoService.encryptBytes(Uint8List.fromList(bytes), sharedSecret);

    // Upload the ciphertext blob to R2 via the presigned PUT URL
    final putResp = await http.put(
      Uri.parse(presign['uploadUrl']!),
      headers: {'Content-Type': 'application/octet-stream'},
      body: enc['cipherBytes'],
    );
    if (putResp.statusCode != 200) {
      throw Exception('R2 upload failed: ${putResp.statusCode}');
    }

    // Return the metadata the sender will encrypt and relay via Socket.IO
    return {
      'downloadUrl': presign['downloadUrl']!,
      'nonce':       base64Encode(enc['nonce']!),
      'mac':         base64Encode(enc['mac']!),
      'ext':         p.extension(file.path).replaceFirst('.', ''),
    };
  }

  // ── Step 4: Recipient downloads and decrypts ──────────────────────────────

  /// Downloads the encrypted blob from R2 and decrypts it.
  static Future<Uint8List> downloadAndDecrypt({
    required String downloadUrl,
    required String nonceB64,
    required String macB64,
    required SecretKey sharedSecret,
  }) async {
    final resp = await http.get(Uri.parse(downloadUrl));
    if (resp.statusCode != 200) {
      throw Exception('Download failed: ${resp.statusCode}');
    }
    return CryptoService.decryptBytes(
      Uint8List.fromList(resp.bodyBytes),
      base64Decode(nonceB64),
      base64Decode(macB64),
      sharedSecret,
    );
  }
}
