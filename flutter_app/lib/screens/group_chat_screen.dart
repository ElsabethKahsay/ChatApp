import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../services/socket_service.dart';
import '../services/message_store.dart';
import '../services/group_chat_service.dart';
import '../services/api_service.dart';
import '../services/media_service.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../widgets/chat_bubble.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _messages = <Message>[];
  final _typingUsers = <String>{};
  SecretKey? _groupKey;
  String? _myUserId;
  bool _isInit = false;
  Timer? _typingTimer;
  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;

  @override
  void initState() {
    super.initState();
    _initGroup();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initGroup() async {
    try {
      _myUserId = SocketService.myUserId;
      _groupKey = await GroupChatService.decryptGroupKey(widget.group);

      // 1. Load local SQLite history
      final localMsgs = (await MessageStore.getMessages(widget.group.id)).map((m) => Message(
        id: m['id'], fromUserId: m['fromUserId'], text: m['text'],
        sentAt: DateTime.fromMillisecondsSinceEpoch(m['sentAt']),
        isMe: m['isMe'], delivered: m['delivered'], mediaUrl: m['mediaUrl']
      )).toList();

      if (mounted) setState(() { _messages.addAll(localMsgs); _isInit = true; });

      // 2. GAP-FILL: Pull missing history & TRIGGER READ RECEIPTS
      final token = await KeyStore.getAuthToken();
      if (token != null) {
        final serverHistory = await ApiService.getGroupHistory(widget.group.id, token);
        for (var sm in serverHistory) {
          if (_messages.any((m) => m.id == sm['messageId'])) continue;
          try {
            final payload = Map<String, dynamic>.from(sm['payload'] as Map);
            final processed = await SocketService.processPayload(
              payload: payload,
              secret: _groupKey!,
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
            if (mounted) setState(() => _messages.add(msg));
            await MessageStore.saveMessage(message: msg, conversationId: widget.group.id, isMe: msg.isMe);
          } catch (_) {}
        }
        if (mounted) {
           setState(() => _messages.sort((a, b) => b.sentAt.compareTo(a.sentAt)));
           // Mark all as read locally
           await MessageStore.markAsRead(widget.group.id);
        }
      }

      _msgSub = SocketService.messageStream.listen((msg) {
        if (msg.groupId == widget.group.id && !msg.isMe && mounted) {
          setState(() => _messages.insert(0, msg));
        }
      });

      _typingSub = SocketService.typingStream.listen((data) {
        final from = data['from'];
        final stopped = data['stopped'] == true;
        if (from != null && from != _myUserId && data['groupId'] == widget.group.id && mounted) {
          setState(() {
            if (stopped) { _typingUsers.remove(from); } else { _typingUsers.add(from as String); }
          });
        }
      });
    } catch (e) {
      debugPrint('Group Sync Error: $e');
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text('Are you sure you want to leave "${widget.group.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final token = await KeyStore.getAuthToken();
        await ApiService.leaveGroup(widget.group.id, token!);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to leave group: $e')));
      }
    }
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_isInit) return;
    _controller.clear();
    final id = const Uuid().v4();
    final encrypted = await CryptoService.encrypt(text, _groupKey!);
    SocketService.sendGroupMessage(groupId: widget.group.id, encryptedPayload: encrypted, messageId: id);
    final msg = Message(id: id, fromUserId: _myUserId!, text: text, sentAt: DateTime.now(), isMe: true);
    setState(() => _messages.insert(0, msg));
    await MessageStore.saveMessage(message: msg, conversationId: widget.group.id, isMe: true);
    HapticFeedback.lightImpact();
  }

  Future<void> _onImageTap() async {
    if (!_isInit) return;
    if (await Permission.photos.request().isGranted) {
      HapticFeedback.mediumImpact();
      await MediaService.pickAndSendImage(toId: widget.group.id, encryptionKey: _groupKey!, isGroup: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.isDarkMode ? AppTheme.darkBg : AppTheme.softWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${widget.group.members.length} members', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            tooltip: 'Leave group',
            onPressed: _leaveGroup,
          ),
        ],
      ),
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
          if (_typingUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              alignment: Alignment.centerLeft,
              child: Text('${_typingUsers.join(', ')} ${_typingUsers.length == 1 ? 'is' : 'are'} typing...',
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
                  hintText: 'Message...',
                  filled: true,
                  fillColor: AppTheme.isDarkMode ? AppTheme.darkBg : AppTheme.softWhite,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                ),
                onChanged: (_) {
                  _typingTimer?.cancel();
                  SocketService.sendTyping(groupId: widget.group.id);
                  _typingTimer = Timer(const Duration(seconds: 2), () {
                    SocketService.sendStopTyping(groupId: widget.group.id);
                  });
                },
                onSubmitted: (_) {
                  _typingTimer?.cancel();
                  SocketService.sendStopTyping(groupId: widget.group.id);
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
