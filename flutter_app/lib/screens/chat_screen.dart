import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/theme.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerPublicKeyBase64;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerPublicKeyBase64,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <Message>[];
  late SecretKey _sharedSecret;
  String? _myUserId;
  bool _isInit = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _initCryptoAndListeners();
  }

  Future<void> _initCryptoAndListeners() async {
    try {
      // 1. Get my user ID and key pair
      _myUserId = await KeyStore.getUserId();
      final myKeyPair = await KeyStore.loadKeyPair();
      if (myKeyPair == null) return;

      // 2. Import peer's public key
      if (widget.peerPublicKeyBase64 == null) return;
      final peerPubKey = await CryptoService.importPublicKey(widget.peerPublicKeyBase64!);

      // 3. Derive ECDH shared secret
      _sharedSecret = await CryptoService.deriveSharedSecret(myKeyPair, peerPubKey);
      if (!mounted) return;
      setState(() => _isInit = true);

      // 4. Get a socket auth token from secure storage, then connect
      final token = await KeyStore.getAuthToken();
      if (token == null) {
        throw Exception('Missing auth token - please login again.');
      }
      await SocketService.connect(_myUserId!, token);


      // 5. Listen for incoming text messages
      SocketService.onMessage((data) async {
        try {
          final payload = Map<String, dynamic>.from(data['payload']);
          // Decrypt incoming ciphertext
          final plaintext = await CryptoService.decrypt(payload, _sharedSecret);

          final msg = Message(
            id: data['messageId'] ?? const Uuid().v4(),
            fromUserId: data['from'],
            text: plaintext,
            sentAt: DateTime.fromMillisecondsSinceEpoch(data['sentAt']),
            type: MessageType.text,
          );

          _addMessageLocally(msg);
        } catch (e) {
          print('❌ Decrypt error: $e');
        }
      });

      // 6. Listen for typing indicators
      SocketService.onTyping((from, isTyping) {
        if (from == widget.peerId && mounted) {
          setState(() => _isTyping = isTyping);
        }
      });

    } catch (e) {
      print('❌ Chat init error: $e');
    }
  }

  void _addMessageLocally(Message msg) {
    if (mounted) setState(() => _messages.add(msg));
    // Set auto-delete timer
    Future.delayed(msg.expiresAt.difference(DateTime.now()), () {
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == msg.id));
    });
  }

  void _onTextChanged(String val) {
    // Send typing indicator
    SocketService.sendTyping(toUserId: widget.peerId, isTyping: val.isNotEmpty);
    _typingTimer?.cancel();
    if (val.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        SocketService.sendTyping(toUserId: widget.peerId, isTyping: false);
      });
    }
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_isInit) return;

    _controller.clear();
    _onTextChanged('');

    final messageId = const Uuid().v4();

    try {
      // 1. Encrypt plaintext
      final encrypted = await CryptoService.encrypt(text, _sharedSecret);

      // 2. Send encrypted payload via socket
      SocketService.sendMessage(
        toUserId: widget.peerId,
        encryptedPayload: encrypted,
        messageId: messageId,
      );

      // 3. Show in local UI immediately
      final msg = Message(
        id: messageId,
        fromUserId: _myUserId!,
        text: text,
        sentAt: DateTime.now(),
        type: MessageType.text,
      );
      _addMessageLocally(msg);

    } catch (e) {
      print('❌ Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    SocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (_isTyping)
              const Text('typing...', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(8.0),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = _messages[_messages.length - 1 - i];
                  return ChatBubble(
                    message: msg,
                    isMe: msg.fromUserId == _myUserId,
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () {
              // TODO: Add media sending
            },
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(),
              ),
              onChanged: _onTextChanged,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendText,
          ),
        ],
      ),
    );
  }
}
