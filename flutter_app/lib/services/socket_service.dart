import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants.dart';

/// Socket.IO client for real-time messaging
class SocketService {
  static IO.Socket? _socket;
  static String? _myUserId;
  static Completer<void>? _connectCompleter;

  // ── Connection Management ────────────────────────────────────────────────

  static Future<void> connect(String userId, String token) async {
    print('🔌 Connecting socket for user: $userId');
    print('   Server URL: ${Constants.serverUrl}');
    print('   Token: ${token.length > 20 ? token.substring(0, 20) : token}...');
    
    // If already connecting, return the existing future
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      print('⏳ Already connecting, returning existing future');
      return _connectCompleter!.future;
    }

    // If already connected to the same user, just return
    if (_socket != null && _socket!.connected && _myUserId == userId) {
      print('✅ Already connected as same user');
      return;
    }

    // Disconnect existing socket if reconnecting as different user
    if (_socket != null) {
      print('🔄 Disconnecting existing socket');
      disconnect();
    }

    _myUserId = userId;
    _connectCompleter = Completer<void>();

    try {
      _socket = IO.io(
        Constants.serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // Allow polling for better compatibility
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(double.infinity)
            .setReconnectionDelay(1000)
            .setAuth({'token': token})
            .setTimeout(5000) // 5 second connection timeout
            .build(),
      );
      print('🔌 Socket created');

      _socket!
        ..onConnect((_) {
          print('✅ Socket connected');
          if (!_connectCompleter!.isCompleted) {
            _connectCompleter!.complete();
          }
        })
        ..onConnectError((e) {
          print('❌ Socket connect error: $e');
          if (!_connectCompleter!.isCompleted) {
            _connectCompleter!.completeError(Exception('Failed to connect: $e'));
          }
        })
        ..onError((e) {
          print('❌ Socket error: $e');
          if (!_connectCompleter!.isCompleted) {
            _connectCompleter!.completeError(Exception('Socket error: $e'));
          }
        })
        ..onDisconnect((_) {
          print('🔌 Socket disconnected (user: $_myUserId)');
          // Note: We do NOT clear _myUserId here - it represents the identity
          // of the logged-in user, not the socket connection state.
          // This allows reconnection attempts to use the correct user ID.
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

      // Set a manual timeout as backup
      Timer(const Duration(seconds: 10), () {
        if (!_connectCompleter!.isCompleted) {
          _connectCompleter!.completeError(
            Exception('Connection timeout - server not responding'),
          );
        }
      });

      return await _connectCompleter!.future;
    } catch (e) {
      _connectCompleter?.completeError(e);
      rethrow;
    }
  }

  static bool get isConnected => _socket?.connected == true;

  // ── Message Sending ───────────────────────────────────────────────────────

  static void sendMessage({
    required String toUserId,
    required Map<String, String> encryptedPayload,
    required String messageId,
  }) {
    print('📤 Attempting to send message to $toUserId');
    print('   Socket exists: ${_socket != null}');
    print('   Socket connected: ${isConnected}');
    print('   My userId: $_myUserId');
    
    if (_socket == null) {
      print('❌ Socket is null');
      throw Exception('Socket not initialized. Please login again.');
    }
    if (!isConnected) {
      print('❌ Socket not connected');
      throw Exception('Not connected to server. Check your internet connection.');
    }

    final messageData = {
      'to': toUserId,
      'payload': encryptedPayload,
      'messageId': messageId,
    };
    
    print('📤 Emitting send_message: $messageData');
    _socket!.emit('send_message', messageData);
    print('✅ Message emitted to $toUserId');
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
    if (_socket == null || !isConnected) return;
    _socket!.emit('typing', {'to': toUserId, 'isTyping': isTyping});
  }

  static void sendStatus({required bool online}) {
    if (_socket == null || !isConnected) return;
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
    if (_socket == null || !isConnected) return;
    _socket!.emit('message_ack', {'to': toUserId, 'messageId': messageId});
  }

  static void onAck(void Function(String messageId) handler) {
    _socket?.on('message_ack', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['messageId'] as String);
    });
  }

  static void onMessageDelivered(void Function(String messageId, String to) handler) {
    _socket?.on('message_delivered', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['messageId'] as String, map['to'] as String);
    });
  }

  static void onMessageFailed(void Function(String messageId, String error) handler) {
    _socket?.on('message_failed', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['messageId'] as String, map['error'] as String);
    });
  }

  // ── Read Receipts ───────────────────────────────────────────────────────────

  static void sendReadReceipt({required String toUserId, required String messageId}) {
    if (_socket == null || !isConnected) return;
    _socket!.emit('message_read', {'to': toUserId, 'messageId': messageId});
  }

  static void onReadReceipt(void Function(String messageId, int readAt) handler) {
    _socket?.on('message_read', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['messageId'] as String, map['readAt'] as int);
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
    if (_socket == null) {
      throw Exception('Socket not initialized. Please login again.');
    }
    if (!isConnected) {
      throw Exception('Not connected to server. Check your internet connection.');
    }
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
    _connectCompleter = null;
    print('🔌 Socket disconnected manually');
  }

  /// Call this when logging out to fully clear session
  static void logout() {
    disconnect();
    _myUserId = null;
    print('🔌 Socket logged out - all state cleared');
  }
}
