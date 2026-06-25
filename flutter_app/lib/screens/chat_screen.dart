import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../services/socket_service.dart';
import '../services/message_store.dart';
import '../services/api_service.dart';
import '../services/media_service.dart';
import '../models/message.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerPublicKeyBase64;

  const ChatScreen({super.key, required this.peerId, required this.peerName, this.peerPublicKeyBase64});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <Message>[];
  final _seenIds = <String>{};
  SecretKey? _sharedSecret;
  String? _myUserId;
  bool _isInit = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _msgSub;
  StreamSubscription? _readSub;
  StreamSubscription? _typingSub;

  void _addMessage(Message msg) {
    if (!_seenIds.add(msg.id)) return;
    setState(() => _messages.insert(0, msg));
  }

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _readSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    try {
      _myUserId = await KeyStore.getUserId();
      final myKeyPair = await KeyStore.loadKeyPair();
      if (myKeyPair == null || widget.peerPublicKeyBase64 == null) return;

      final peerPubKey = await CryptoService.importPublicKey(widget.peerPublicKeyBase64!);
      _sharedSecret = await CryptoService.deriveSharedSecret(myKeyPair, peerPubKey);

      // 1. Instant Load: Local history
      final localMsgs = (await MessageStore.getMessages(widget.peerId)).map((m) => Message(
        id: m['id'], fromUserId: m['fromUserId'], text: m['text'],
        sentAt: DateTime.fromMillisecondsSinceEpoch(m['sentAt']),
        isMe: m['isMe'], delivered: m['delivered'],
        readAt: m['readAt'] != null ? DateTime.fromMillisecondsSinceEpoch(m['readAt']) : null,
      )).toList();

      if (mounted) { setState(() { for (var m in localMsgs) _seenIds.add(m.id); _messages.addAll(localMsgs); _isInit = true; }); }

      // 2. Perfection Sync: Fetch 24h gaps + TRIGGER READ RECEIPTS
      final token = await KeyStore.getAuthToken();
      if (token != null) {
        final serverHistory = await ApiService.getMessageHistory(widget.peerId, token);
        for (var sm in serverHistory) {
          if (_messages.any((m) => m.id == sm['messageId'])) continue;
          try {
            final payload = Map<String, dynamic>.from(sm['payload'] as Map);
            final processed = await SocketService.processPayload(
              payload: payload,
              secret: _sharedSecret!,
              messageId: sm['messageId']
            );
            
            final msg = Message(
              id: sm['messageId'], 
              fromUserId: sm['from'], 
              text: processed['text']!, 
              sentAt: DateTime.fromMillisecondsSinceEpoch(sm['sentAt']), 
              isMe: sm['from'] == _myUserId,
              mediaUrl: processed['mediaPath'],
              delivered: true,
            );
            if (mounted) _addMessage(msg);
            await MessageStore.saveMessage(message: msg, conversationId: widget.peerId, isMe: msg.isMe);
          } catch (_) {}
        }
        if (mounted) setState(() => _messages.sort((a, b) => b.sentAt.compareTo(a.sentAt)));

        // V1 FINAL POLISH: Mark all currently visible messages as read locally and on server
        await MessageStore.markAsRead(widget.peerId);
        SocketService.sendReadReceipt(toUserId: widget.peerId, messageId: 'batch');
      }

      // 3. LISTEN for real-time updates
      _msgSub = SocketService.messageStream.listen((msg) {
        if (msg.fromUserId == widget.peerId && mounted) {
          _addMessage(msg);
          SocketService.sendReadReceipt(toUserId: widget.peerId, messageId: msg.id);
        }
      });

      _readSub = SocketService.readStream.listen((data) {
        if (data['from'] == widget.peerId && mounted) {
          setState(() {
            for (var i = 0; i < _messages.length; i++) {
              if (_messages[i].isMe) _messages[i] = _messages[i].copyWith(readAt: DateTime.now());
            }
          });
        }
      });

      _typingSub = SocketService.typingStream.listen((data) {
        if (data['from'] == widget.peerId && mounted) {
          if (data['stopped'] == true) {
            setState(() => _isTyping = false);
          } else {
            setState(() => _isTyping = true);
          }
        }
      });
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_isInit) return;
    _controller.clear();
    final id = const Uuid().v4();
    final encrypted = await CryptoService.encrypt(text, _sharedSecret!);
    SocketService.sendMessage(toUserId: widget.peerId, encryptedPayload: encrypted, messageId: id);
    final msg = Message(id: id, fromUserId: _myUserId!, text: text, sentAt: DateTime.now(), isMe: true);
    _addMessage(msg);
    await MessageStore.saveMessage(message: msg, conversationId: widget.peerId, isMe: true);
    HapticFeedback.lightImpact();
  }

  Future<void> _onImageTap() async {
    if (!_isInit) return;
    if (await Permission.photos.request().isGranted) {
      await MediaService.pickAndSendImage(toId: widget.peerId, encryptionKey: _sharedSecret!, isGroup: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.isDarkMode ? AppTheme.darkBg : AppTheme.softWhite,
      appBar: AppBar(title: Text(widget.peerName, style: const TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => ChatBubble(message: _messages[i], isMe: _messages[i].isMe),
            ),
          ),
          if (_isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              alignment: Alignment.centerLeft,
              child: Text('${widget.peerName} is typing...',
                style: TextStyle(color: AppTheme.primaryPurple, fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.isDarkMode ? AppTheme.darkSurface : Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.image_outlined, color: AppTheme.primaryPurple), onPressed: _onImageTap),
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textDark),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  filled: true,
                  fillColor: AppTheme.isDarkMode ? AppTheme.darkBg : AppTheme.softWhite,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                ),
                onChanged: (_) {
                  _typingTimer?.cancel();
                  SocketService.sendTyping(toUserId: widget.peerId);
                  _typingTimer = Timer(const Duration(seconds: 2), () {
                    SocketService.sendStopTyping(toUserId: widget.peerId);
                  });
                },
                onSubmitted: (_) {
                  _typingTimer?.cancel();
                  SocketService.sendStopTyping(toUserId: widget.peerId);
                  _sendText();
                },
              ),
            ),
            IconButton(icon: const Icon(Icons.send_rounded, color: AppTheme.primaryPurple), onPressed: _sendText),
          ],
        ),
      ),
    );
  }
}
