import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/message_store.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerPublicKeyBase64;
  final dynamic contact;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerPublicKeyBase64,
    this.contact,
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
    _initChat();
  }

  Future<void> _initChat() async {
    await MessageStore.init();
    await _initCryptoAndListeners();
    await _loadStoredMessages();
  }

  Future<void> _loadStoredMessages() async {
    try {
      final stored = await MessageStore.getMessages(widget.peerId);
      if (mounted && stored.isNotEmpty) {
        setState(() {
          _messages.addAll(stored.map((m) => Message(
            id: m['id'] as String,
            fromUserId: m['fromUserId'] as String,
            text: m['text'] as String,
            sentAt: DateTime.fromMillisecondsSinceEpoch(m['sentAt'] as int),
            isMe: m['isMe'] as bool,
            delivered: m['delivered'] as bool,
            read: m['read'] as bool,
            readAt: m['readAt'] != null
                ? DateTime.fromMillisecondsSinceEpoch(m['readAt'] as int)
                : null,
          )));
        });
      }
    } catch (e) {
      print('❌ Failed to load stored messages: $e');
    }
  }

  Future<void> _initCryptoAndListeners() async {
    try {
      // 1. Get my user ID and key pair
      _myUserId = await KeyStore.getUserId();
      final myKeyPair = await KeyStore.loadKeyPair();
      if (myKeyPair == null) return;

      // 2. Import peer's public key
      if (widget.peerPublicKeyBase64 == null) {
        throw Exception('Missing peer public key - cannot establish secure chat');
      }
      final peerPubKey =
          await CryptoService.importPublicKey(widget.peerPublicKeyBase64!);

      // 3. Derive ECDH shared secret
      _sharedSecret =
          await CryptoService.deriveSharedSecret(myKeyPair, peerPubKey);
      if (!mounted) return;
      setState(() => _isInit = true);

      // 4. Ensure socket is connected and set status to online
      if (!SocketService.isConnected) {
        final token = await KeyStore.getAuthToken();
        if (token == null) {
          throw Exception('Missing auth token - please login again.');
        }
        await SocketService.connect(_myUserId!, token);
      }
      SocketService.sendStatus(online: true);

      // Listen for incoming text messages
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
            isMe: data['from'] == _myUserId,
            delivered: true,
          );

          _addMessageLocally(msg);

          // Save to secure local storage
          await MessageStore.saveMessage(
            message: msg,
            conversationId: widget.peerId,
            isMe: false,
          );

          // Send delivery acknowledgement
          SocketService.sendAck(
              toUserId: data['from'], messageId: data['messageId']);

          // Send read receipt
          SocketService.sendReadReceipt(
              toUserId: data['from'], messageId: data['messageId']);
          await MessageStore.markAsRead(msg.id);
        } catch (e) {
          print('❌ Decrypt error: $e');
        }
      });

      // 6. Listen for read receipts
      SocketService.onReadReceipt((messageId, readAt) {
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                read: true,
                readAt: DateTime.fromMillisecondsSinceEpoch(readAt),
              );
            }
          });
        }
      });

      // 6. Listen for typing indicators
      SocketService.onTyping((from, isTyping) {
        if (from == widget.peerId && mounted) {
          setState(() => _isTyping = isTyping);
        }
      });

      // 7. Listen for delivery acknowledgments
      SocketService.onAck((messageId) {
        if (mounted) {
          print('✅ Message delivered: $messageId');
        }
      });

      // 8. Presence updates (optional)
      SocketService.onPresence((userId, online) {
        if (userId == widget.peerId && mounted) {
          print('Presence update: $userId is ${online ? 'online' : 'offline'}');
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

  Future<void> _saveMessage(Message msg) async {
    try {
      final token = await KeyStore.getAuthToken();
      if (token == null) {
        _showError('Not authenticated');
        return;
      }

      await ApiService.saveMessage(
        token: token,
        messageId: msg.id,
        text: msg.text,
        senderName: msg.isMe ? 'Me' : widget.peerName,
        senderId: msg.fromUserId,
      );

      _showSuccess('Message saved!');
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('Exception:')) {
        errorMsg = errorMsg.replaceFirst('Exception:', '').trim();
      }
      if (errorMsg.contains('already saved')) {
        _showInfo('Message already saved');
      } else {
        _showError(errorMsg);
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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

      // 3. Show in local UI and persist
      final msg = Message(
        id: messageId,
        fromUserId: _myUserId!,
        text: text,
        sentAt: DateTime.now(),
        type: MessageType.text,
        isMe: true,
        delivered: false,
      );
      _addMessageLocally(msg);

      // Save to secure local storage
      await MessageStore.saveMessage(
        message: msg,
        conversationId: widget.peerId,
        isMe: true,
      );
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
    SocketService.sendStatus(online: false);
    SocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            if (_isTyping)
              const Text('typing...',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFDE0EC), Color(0xFFEFDFFF), Color(0xFFFFF6FB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[_messages.length - 1 - i];
                    return ChatBubble(
                      message: msg,
                      isMe: msg.fromUserId == _myUserId,
                      onLongPress: () => _saveMessage(msg),
                    );
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(246, 154, 205, 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildInputBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Row(
      children: [
        IconButton(
          icon:
              const Icon(Icons.photo_library_rounded, color: Color(0xFFB56AA5)),
          onPressed: () {
            // TODO: Add media sending
          },
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Write something sweet...',
              hintStyle: const TextStyle(color: Color(0xFF9E8FA8)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _onTextChanged,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _sendText,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF69ACD), Color(0xFFBA7BEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child:
                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}
