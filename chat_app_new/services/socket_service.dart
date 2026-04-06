import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants.dart';

/// Socket.IO client for real-time messaging
class SocketService {
  static IO.Socket? _socket;
  static String? _myUserId;

  // ── Connection Management ────────────────────────────────────────────────

  static Future<void> connect(String userId, String token) async {
    _myUserId = userId;

    _socket = IO.io(
      Constants.serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        print('✅ Socket connected');
      })
      ..onConnectError((e) => print('❌ Socket connect error: $e'))
      ..onDisconnect((_) {
        print('🔌 Socket disconnected');
        _myUserId = null;
      })
      ..on('session_replaced', (data) {
        print('⚠️ Session replaced by another login: $data');
      })
      ..on('offline_queued', (data) {
        print('🕒 Message queued for offline recipient: $data');
      })
      ..on('presence_update', (data) {
        final map = Map<String, dynamic>.from(data as Map);
        print('📡 Presence update: ${map['userId']} -> ${map['online']}');
      });
  }

  static bool get isConnected => _socket?.connected == true;

  // ── Message Sending ───────────────────────────────────────────────────────

  static void sendMessage({
    required String toUserId,
    required Map<String, String> encryptedPayload,
    required String messageId,
  }) {
    if (!isConnected) {
      print('❌ Cannot send message - not connected');
      return;
    }

    _socket!.emit('send_message', {
      'to': toUserId,
      'payload': encryptedPayload,
      'messageId': messageId,
    });
    
    print('📤 Message sent to $toUserId');
  }

  // ── Message Receiving ─────────────────────────────────────────────────────

  static void onMessage(void Function(Map<String, dynamic>) handler) {
    _socket?.on('receive_message', (data) {
      print('📥 Message received: ${data['messageId']}');
      handler(Map<String, dynamic>.from(data as Map));
    });
  }

  // ── Typing Indicators ─────────────────────────────────────────────────────

  static void sendTyping({required String toUserId, required bool isTyping}) {
    if (!isConnected) return;
    _socket!.emit('typing', {'to': toUserId, 'isTyping': isTyping});
  }

  static void sendStatus({required bool online}) {
    if (!isConnected) return;
    _socket!.emit('set_status', {'status': online});
  }

  static void onTyping(void Function(String from, bool isTyping) handler) {
    _socket?.on('typing', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['from'] as String, map['isTyping'] as bool);
    });
  }

  // ── Message Acknowledgments ─────────────────────────────────────────────────

  static void sendAck({required String toUserId, required String messageId}) {
    if (!isConnected) return;
    _socket!.emit('message_ack', {'to': toUserId, 'messageId': messageId});
  }

  static void onAck(void Function(String messageId) handler) {
    _socket?.on('message_ack', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['messageId'] as String);
    });
  }

  static void onPresence(void Function(String userId, bool online) handler) {
    _socket?.on('presence_update', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['userId'] as String, map['online'] as bool);
    });
  }

  // ── Media Messages ─────────────────────────────────────────────────────────

  static void sendMedia({
    required String toUserId,
    required Map<String, dynamic> encryptedPayload,
    required String messageId,
  }) {
    if (!isConnected) return;
    _socket!.emit('send_media', {
      'to': toUserId,
      'payload': encryptedPayload,
      'messageId': messageId,
    });
  }

  static void onMedia(void Function(Map<String, dynamic>) handler) {
    _socket?.on('receive_media', (data) {
      print('📥 Media received: ${data['messageId']}');
      handler(Map<String, dynamic>.from(data as Map));
    });
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    print('🔌 Socket disconnected manually');
  }
}
