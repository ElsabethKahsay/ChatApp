import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/message.dart';
import '../models/group.dart';
import 'message_store.dart';
import 'api_service.dart';
import 'group_chat_service.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';

class SocketService {
  static IO.Socket? _socket;
  static String? _myUserId;
  static String? _authToken;
  static final Map<String, SecretKey> _secretCache = {};
  static final Map<String, SecretKey> _groupKeyCache = {};
  static final List<Map<String, dynamic>> _outgoingQueue = []; // {event, data}
  static final _dio = Dio();

  static final _messageController = StreamController<Message>.broadcast();
  static Stream<Message> get messageStream => _messageController.stream;

  static final _ackController = StreamController<String>.broadcast();
  static Stream<String> get ackStream => _ackController.stream;
  static Stream<String> get deliveryStream => _ackController.stream;

  static final _readController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get readStream => _readController.stream;

  static final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  static final _connectionController = StreamController<bool>.broadcast();
  static Stream<bool> get connectionStream => _connectionController.stream;

  static String? get myUserId => _myUserId;

  static Future<void> connect(String userId, String token) async {
    if (_socket?.connected == true && _myUserId == userId) return;
    _myUserId = userId;
    _authToken = token;

    _socket = IO.io(Constants.serverUrl, IO.OptionBuilder()
      .setTransports(['websocket', 'polling'])
      .enableAutoConnect()
      .enableReconnection()
      .setAuth({'token': token})
      .build());

    _socket!.onConnect((_) {
      debugPrint('✅ Socket Connected');
      _connectionController.add(true);
      _flushQueue();
      _warmGroupKeys();
    });

    _socket!.onDisconnect((_) => _connectionController.add(false));
    _socket!.onConnectError((_) => _connectionController.add(false));

    _socket!.on('receive_message', (data) => _handleIncoming(data, isGroup: false));
    _socket!.on('receive_group_message', (data) => _handleIncoming(data, isGroup: true));

    _socket!.on('message_ack', (data) {
      final id = data['messageId'];
      MessageStore.markAsDelivered(id);
      _ackController.add(id);
    });

    _socket!.on('message_read', (data) async {
      final map = Map<String, dynamic>.from(data as Map);
      // V1 PERFECTION: Persist read status so unread badges stay gone
      if (map['messageId'] != null) {
        await MessageStore.markMessageAsRead(map['messageId']);
      }
      _readController.add(map);
    });

    _socket!.on('typing', (data) {
      _typingController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('stop_typing', (data) {
      _typingController.add(Map<String, dynamic>.from({...data as Map, 'stopped': true}));
    });
  }

  static Future<void> _warmGroupKeys() async {
    try {
      final groups = await ApiService.getGroups(_authToken!);
      for (var g in groups) {
        final group = Group.fromJson(g, _myUserId!);
        _groupKeyCache[group.id] = await GroupChatService.decryptGroupKey(group);
      }
    } catch (_) {}
  }

  static Future<void> _handleIncoming(dynamic data, {required bool isGroup}) async {
    final fromId = data['from'];
    final conversationId = isGroup ? data['groupId'] : fromId;
    final payload = Map<String, dynamic>.from(data['payload']);

    SecretKey? secret;
    if (isGroup) {
      if (!_groupKeyCache.containsKey(conversationId)) await _warmGroupKeys();
      secret = _groupKeyCache[conversationId];
    } else {
      if (!_secretCache.containsKey(fromId)) {
        final myKeyPair = await KeyStore.loadKeyPair();
        if (myKeyPair == null) { print('❌ _handleIncoming: no key pair'); return; }
        final peerKeyB64 = await ApiService.getPublicKey(fromId, _authToken!);
        _secretCache[fromId] = await CryptoService.deriveSharedSecret(
          myKeyPair, await CryptoService.importPublicKey(peerKeyB64)
        );
      }
      secret = _secretCache[fromId];
    }

    String text = '';
    String? mediaPath;

    try {
      final processed = await processPayload(payload: payload, secret: secret!, messageId: data['messageId']);
      text = processed['text']!;
      mediaPath = processed['mediaPath'];
    } catch (e) {
      print('❌ _handleIncoming decrypt failed for ${data['messageId']}: $e');
      _secretCache.remove(fromId);
      return;
    }

    final msg = Message(
      id: data['messageId'],
      fromUserId: fromId,
      groupId: isGroup ? conversationId : null,
      text: text,
      sentAt: DateTime.fromMillisecondsSinceEpoch(data['sentAt'] ?? DateTime.now().millisecondsSinceEpoch),
      isMe: false,
      delivered: true,
      mediaUrl: mediaPath,
    );

    HapticFeedback.lightImpact();
    await MessageStore.saveMessage(message: msg, conversationId: conversationId, isMe: false);
    _messageController.add(msg);
    sendAck(toUserId: fromId, messageId: data['messageId']);
  }

  static bool get isConnected => _socket?.connected == true;

  static Future<Map<String, String?>> processPayload({
    required Map<String, dynamic> payload,
    required SecretKey secret,
    required String messageId,
  }) async {
    String text = '';
    String? mediaPath;
    if (payload.containsKey('url')) {
      final response = await _dio.get(payload['url'], options: Options(responseType: ResponseType.bytes));
      final decryptedBytes = await CryptoService.decryptBytes(
        Uint8List.fromList(response.data),
        base64.decode(payload['nonce']),
        base64.decode(payload['mac']),
        secret,
      );
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$messageId.bin');
      await file.writeAsBytes(decryptedBytes);
      mediaPath = file.path;
      text = '[${payload['type']}]';
    } else {
      text = await CryptoService.decrypt(Map<String, String>.from(payload), secret);
    }
    return {'text': text, 'mediaPath': mediaPath};
  }

  static void sendMessage({required String toUserId, required Map<String, String> encryptedPayload, required String messageId}) {
    HapticFeedback.mediumImpact();
    final data = {'to': toUserId, 'payload': encryptedPayload, 'messageId': messageId, 'sentAt': DateTime.now().millisecondsSinceEpoch};
    if (isConnected) { _socket!.emit('send_message', data); } else { _outgoingQueue.add({'event': 'send_message', 'data': data}); }
  }

  static void sendGroupMessage({required String groupId, required Map<String, String> encryptedPayload, required String messageId}) {
    HapticFeedback.mediumImpact();
    final data = {'groupId': groupId, 'payload': encryptedPayload, 'messageId': messageId, 'sentAt': DateTime.now().millisecondsSinceEpoch};
    if (isConnected) { _socket!.emit('send_group_message', data); } else { _outgoingQueue.add({'event': 'send_group_message', 'data': data}); }
  }

  static void sendReadReceipt({required String toUserId, required String messageId}) {
    if (isConnected) _socket!.emit('message_read', {'toUserId': toUserId, 'messageId': messageId});
  }

  static void sendAck({required String toUserId, required String messageId}) {
    if (isConnected) _socket!.emit('message_ack', {'to': toUserId, 'messageId': messageId});
  }

  static void sendTyping({String? toUserId, String? groupId}) {
    if (isConnected) _socket!.emit('typing', {'toUserId': toUserId, 'groupId': groupId});
  }

  static void sendStopTyping({String? toUserId, String? groupId}) {
    if (isConnected) _socket!.emit('stop_typing', {'toUserId': toUserId, 'groupId': groupId});
  }

  static void _flushQueue() {
    while (_outgoingQueue.isNotEmpty && isConnected) {
      final item = _outgoingQueue.removeAt(0);
      _socket!.emit(item['event'] as String, item['data']);
    }
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _secretCache.clear();
    _groupKeyCache.clear();
  }
}
