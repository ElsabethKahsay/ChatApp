import 'package:flutter/material.dart';
import '../models/message.dart';
import '../core/theme.dart';

class MessageStatusWidget extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageStatusWidget({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();

    if (message.sending) {
      return const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white70),
      );
    }

    // PERFECTION: Double checkmarks that turn Teal when read
    return Icon(
      Icons.done_all_rounded,
      size: 14,
      color: message.readAt != null
          ? AppTheme.primaryTeal
          : (message.delivered ? Colors.white : Colors.white38),
    );
  }
}
