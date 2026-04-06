enum MessageType { text, media }

class Message {
  final String id;
  final String fromUserId;
  final String text;
  final DateTime sentAt;
  final DateTime expiresAt;
  final MessageType type;
  final String? mediaUrl;

  Message({
    required this.id,
    required this.fromUserId,
    required this.text,
    required this.sentAt,
    Duration? ttl,
    this.type = MessageType.text,
    this.mediaUrl,
  }) : expiresAt = sentAt.add(ttl ?? const Duration(seconds: 30));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
