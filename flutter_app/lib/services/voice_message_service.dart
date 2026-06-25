import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import '../crypto/crypto_service.dart';

/// Service for handling voice message recording and playback
class VoiceMessageService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  
  static bool _isRecording = false;
  static String? _currentRecordingPath;
  static String? _currentlyPlayingPath;
  
  /// Check if currently recording
  static bool get isRecording => _isRecording;
  
  /// Check if currently playing
  static bool get isPlaying => _player.playing;
  
  /// Get the currently playing path
  static String? get currentlyPlayingPath => _currentlyPlayingPath;
  
  /// Get the current recording path (null if not recording)
  static String? get currentRecordingPath => _currentRecordingPath;
  
  /// Request microphone permission
  static Future<bool> requestPermission() async {
    final hasPermission = await _recorder.hasPermission();
    return hasPermission;
  }
  
  /// Start recording voice message
  static Future<String?> startRecording() async {
    try {
      // Check permission
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }
      
      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = path.join(tempDir.path, 'voice_message_$timestamp.m4a');
      
      // Configure recording
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );
      
      // Start recording
      await _recorder.start(config, path: filePath);
      
      _isRecording = true;
      _currentRecordingPath = filePath;
      
      debugPrint('🎤 Started recording: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      return null;
    }
  }
  
  /// Stop recording and return the file path
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      
      final path = await _recorder.stop();
      _isRecording = false;
      
      if (path != null) {
        debugPrint('🎤 Stopped recording: $path');
        
        // Verify file exists and has content
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('🎤 Recording size: $size bytes');
          
          if (size > 1000) { // At least 1KB
            return path;
          } else {
            debugPrint('❌ Recording too small, discarding');
            await file.delete();
            return null;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }
  
  /// Cancel current recording
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stop();
        _isRecording = false;
        
        // Delete the recording file
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
        
        debugPrint('🎤 Recording cancelled');
      }
    } catch (e) {
      debugPrint('❌ Error cancelling recording: $e');
    }
  }
  
  /// Get recording duration (in seconds)
  static Future<Duration?> getRecordingDuration() async {
    try {
      // ignore: unused_local_variable
      final amplitude = await _recorder.getAmplitude();
      // This is a workaround - the record package doesn't expose duration directly
      // We'll track duration separately in the UI
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Play voice message from file path
  static Future<void> playVoiceMessage(String filePath) async {
    try {
      // Stop any current playback
      await stopPlayback();
      
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Voice message file not found');
      }
      
      // Set the audio source
      await _player.setFilePath(filePath);
      
      _currentlyPlayingPath = filePath;
      
      // Start playback
      await _player.play();
      
      debugPrint('▶️ Playing voice message: $filePath');
    } catch (e) {
      debugPrint('❌ Error playing voice message: $e');
    }
  }
  
  /// Stop playback
  static Future<void> stopPlayback() async {
    try {
      if (_player.playing) {
        await _player.stop();
        debugPrint('⏹️ Stopped playback');
      }
      _currentlyPlayingPath = null;
    } catch (e) {
      debugPrint('❌ Error stopping playback: $e');
    }
  }
  
  /// Pause playback
  static Future<void> pausePlayback() async {
    try {
      await _player.pause();
      debugPrint('⏸️ Paused playback');
    } catch (e) {
      debugPrint('❌ Error pausing playback: $e');
    }
  }
  
  /// Resume playback
  static Future<void> resumePlayback() async {
    try {
      await _player.play();
      debugPrint('▶️ Resumed playback');
    } catch (e) {
      debugPrint('❌ Error resuming playback: $e');
    }
  }
  
  /// Seek to position (in seconds)
  static Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('❌ Error seeking: $e');
    }
  }
  
  /// Get current playback position
  static Stream<Duration> get positionStream => _player.positionStream;
  
  /// Get total duration
  static Stream<Duration?> get durationStream => _player.durationStream;
  
  /// Get playback state
  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  /// Get voice message duration from file
  static Future<Duration> getVoiceDuration(String filePath) async {
    try {
      final player = AudioPlayer();
      await player.setFilePath(filePath);
      final duration = player.duration ?? Duration.zero;
      await player.dispose();
      return duration;
    } catch (e) {
      debugPrint('❌ Error getting duration: $e');
      return Duration.zero;
    }
  }
  
  /// Format duration to mm:ss
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  /// Encrypt a voice recording file with AES-256-GCM
  /// Returns a map with encrypted file path, nonce, and mac (base64)
  static Future<Map<String, String>> encryptRecording(
    String filePath,
    SecretKey encryptionKey,
  ) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final encrypted = await CryptoService.encryptBytes(
        Uint8List.fromList(bytes),
        encryptionKey,
      );

      final encryptedPath = '$filePath.enc';
      final encryptedFile = File(encryptedPath);
      await encryptedFile.writeAsBytes([
        ...encrypted['nonce']!,
        ...encrypted['mac']!,
        ...encrypted['cipherBytes']!,
      ]);

      await file.delete();

      debugPrint('🔐 Voice recording encrypted: $encryptedPath');
      return {
        'path': encryptedPath,
        'nonce': base64Encode(encrypted['nonce']!),
        'mac': base64Encode(encrypted['mac']!),
        'originalSize': bytes.length.toString(),
      };
    } catch (e) {
      debugPrint('❌ Voice encryption failed: $e');
      rethrow;
    }
  }

  /// Decrypt a voice file to a temporary location for playback
  /// Returns the path to the decrypted temp file
  static Future<String> decryptToTemp(
    String encryptedPath,
    SecretKey encryptionKey,
  ) async {
    try {
      final encryptedFile = File(encryptedPath);
      final encryptedBytes = await encryptedFile.readAsBytes();

      // First 12 bytes = nonce, next 16 bytes = mac, rest = ciphertext
      final nonce = encryptedBytes.sublist(0, 12);
      final mac = encryptedBytes.sublist(12, 28);
      final cipherBytes = encryptedBytes.sublist(28);

      final decrypted = await CryptoService.decryptBytes(
        cipherBytes,
        nonce,
        mac,
        encryptionKey,
      );

      final tempDir = await getTemporaryDirectory();
      final baseName = path.basenameWithoutExtension(encryptedPath);
      final decryptedPath = path.join(tempDir.path, '$baseName.dec.m4a');
      await File(decryptedPath).writeAsBytes(decrypted);

      debugPrint('🔓 Voice decrypted to temp: $decryptedPath');
      return decryptedPath;
    } catch (e) {
      debugPrint('❌ Voice decryption failed: $e');
      rethrow;
    }
  }

  /// Clean up resources
  static Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
