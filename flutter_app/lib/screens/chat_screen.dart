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
import '../services/saved_messages_service.dart';
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
  late SavedMessagesService _savedMessagesService;
  String? _myUserId;
  bool _isInit = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _initChat();
    _savedMessagesService = SavedMessagesService();
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
      print('CHAT: Initializing crypto and listeners');
      _myUserId = await KeyStore.getUserId();
      print('CHAT: Retrieved user ID: $_myUserId');
      
      if (_myUserId == null) {
        print('CHAT: User ID is null, cannot initialize chat');
        return;
      }
      
      final myKeyPair = await KeyStore.loadKeyPair();
      if (myKeyPair == null) {
        print('CHAT: Key pair is null, cannot initialize chat');
        return;
      }

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
      print('CHAT: Checking socket connection status');
      print('   Socket connected: ${SocketService.isConnected}');
      print('   My userId: $_myUserId');
      
      if (!SocketService.isConnected) {
        print('CHAT: Socket not connected, getting auth token...');
        final token = await KeyStore.getAuthToken();
        if (token == null) {
          print('CHAT: No auth token available');
          throw Exception('Missing auth token - please login again.');
        }
        print('CHAT: Auth token found, attempting to connect socket...');
        try {
          await SocketService.connect(_myUserId!, token).timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Connection timeout'),
          );
          print('CHAT: Socket connection successful');
        } catch (e) {
          print('CHAT: Socket reconnect failed: $e');
          // Continue anyway - messages will be sent when connection restores
        }
      }
      if (SocketService.isConnected) {
        SocketService.sendStatus(online: true);
      }

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

  Future<void> _saveMessage(Message messageToSave) async {
    try {
      await _savedMessagesService.saveMessage(
        messageToSave.text,
        label: 'Chat with ${widget.peerName}',
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
    print('CHAT: Attempting to send text message');
    print('   Text: "$text"');
    print('   Is init: $_isInit');
    print('   My userId: $_myUserId');
    print('   Peer ID: ${widget.peerId}');
    
    if (text.isEmpty || !_isInit) {
      print('CHAT: Cannot send - text empty or not initialized');
      return;
    }

    _controller.clear();
    _onTextChanged('');

    final messageId = const Uuid().v4();
    print('CHAT: Generated message ID: $messageId');

    try {
      // 1. Encrypt plaintext
      print('CHAT: Encrypting message...');
      final encrypted = await CryptoService.encrypt(text, _sharedSecret);
      print('CHAT: Message encrypted successfully');

      // 2. Ensure socket is connected before sending
      print('CHAT: Socket connected: ${SocketService.isConnected}');
      if (!SocketService.isConnected) {
        print('CHAT: Socket not connected, attempting to reconnect...');
        final token = await KeyStore.getAuthToken();
        if (token != null) {
          try {
            await SocketService.connect(_myUserId!, token).timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw Exception('Connection timeout'),
            );
            print('CHAT: Reconnection successful');
          } catch (e) {
            print('CHAT: Could not reconnect: $e');
          }
        } else {
          print('CHAT: No auth token available for reconnection');
        }
      }

      // 3. Send encrypted payload via socket
      print('CHAT: Attempting to send message via socket...');
      try {
        SocketService.sendMessage(
          toUserId: widget.peerId,
          encryptedPayload: encrypted,
          messageId: messageId,
        );
        print('CHAT: Message sent successfully via socket');
      } catch (socketError) {
        print('CHAT: Socket error: $socketError');
        // Message will be shown in UI but marked as not delivered
        print('CHAT: Message queued - will send when connection restored');
      }

      // 4. Show in local UI and persist
      final msg = Message(
        id: messageId,
        fromUserId: _myUserId!,
        text: text,
        sentAt: DateTime.now(),
        type: MessageType.text,
        isMe: true,
        delivered: SocketService.isConnected,
      );
      print('CHAT: Created message object, delivered: ${msg.delivered}');
      _addMessageLocally(msg);

      // Save to secure local storage
      await MessageStore.saveMessage(
        message: msg,
        conversationId: widget.peerId,
        isMe: true,
      );

      // Show feedback if not connected
      if (!SocketService.isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message saved - will send when connection restored'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
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
      appBar: AppBar(
        backgroundColor: AppTheme.primaryCoral,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white)),
            if (_isTyping)
              const Text('typing...',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.bgGradient,
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
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.2),
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
    );
  }

  Widget _buildInputBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryPurple),
          onPressed: () {
            // TODO: Add media sending
          },
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Write something sweet...',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
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
              gradient: AppTheme.primaryGradient,
            ),
            child:
                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}
