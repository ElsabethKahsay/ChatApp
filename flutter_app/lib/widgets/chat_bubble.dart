import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/message.dart';
import 'message_status_widget.dart';
import 'voice_message_widget.dart';

class ChatBubble extends StatefulWidget {
  final Message message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  late Timer _timer;
  String _timeLeft = '';

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateTimeLeft());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTimeLeft() {
    if (!mounted) return;
    final diff = widget.message.expiresAt.difference(DateTime.now());
    setState(() {
      if (diff.isNegative) {
        _timeLeft = 'Expired';
      } else if (diff.inHours > 0) {
        _timeLeft = '${diff.inHours}h left';
      } else {
        _timeLeft = '${diff.inMinutes}m left';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: widget.isMe ? AppTheme.primaryGradient : null,
              color: widget.isMe ? null : (isDark ? AppTheme.darkSurface : AppTheme.softWhite),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                bottomRight: Radius.circular(widget.isMe ? 4 : 16),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContent(),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(widget.message.sentAt),
                      style: TextStyle(fontSize: 10, color: widget.isMe ? Colors.white70 : Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    if (widget.isMe) MessageStatusWidget(message: widget.message, isMe: true),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _timeLeft,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: _timeLeft.contains('m') ? Colors.orange : Colors.grey.withValues(alpha: 0.5)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final text = widget.message.text.toLowerCase();

    // V1 PERFECTION: Case-insensitive media detection
    if (text.contains('[image]') && widget.message.mediaUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(widget.message.mediaUrl!), width: 200, fit: BoxFit.cover),
      );
    }

    if (text.contains('[voice]') && widget.message.mediaUrl != null) {
       return VoicePlayerWidget(
        filePath: widget.message.mediaUrl!,
        isMe: widget.isMe,
        backgroundColor: widget.isMe ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
      );
    }

    return Text(
      widget.message.text,
      style: TextStyle(
        color: widget.isMe ? Colors.white : (AppTheme.isDarkMode ? Colors.white : AppTheme.textDark),
        fontSize: 15,
      ),
    );
  }
}
