import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';
import 'media_service.dart';

class VoiceService {
  static final _audioRecorder = AudioRecorder();

  static Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/${const Uuid().v4()}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
    }
  }

  /// V1 PERFECTION: Encrypts, uploads, and relays the voice note via Socket
  static Future<void> stopAndSend({
    required String toId,
    required SecretKey encryptionKey,
    required bool isGroup,
  }) async {
    final path = await _audioRecorder.stop();
    if (path == null) return;

    final file = File(path);
    final bytes = await file.readAsBytes();

    await MediaService.uploadAndSend(
      toId: toId,
      bytes: bytes,
      extension: 'm4a',
      encryptionKey: encryptionKey,
      isGroup: isGroup,
      type: 'voice',
    );

    if (await file.exists()) await file.delete();
  }
}
