enum MessageType { text, media }

class Message {
  final String id;
  final String fromUserId;
  final String text;
  final DateTime sentAt;
  final DateTime expiresAt;
  final MessageType type;
  final String? mediaUrl;
  final bool isMe;
  final bool delivered;
  final bool read;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.fromUserId,
    required this.text,
    required this.sentAt,
    Duration? ttl,
    this.type = MessageType.text,
    this.mediaUrl,
    this.isMe = false,
    this.delivered = false,
    this.read = false,
    this.readAt,
  }) : expiresAt = sentAt.add(ttl ?? const Duration(seconds: 30));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Message copyWith({
    bool? delivered,
    bool? read,
    DateTime? readAt,
  }) {
    return Message(
      id: id,
      fromUserId: fromUserId,
      text: text,
      sentAt: sentAt,
      ttl: expiresAt.difference(sentAt),
      type: type,
      mediaUrl: mediaUrl,
      isMe: isMe,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
    );
  }
}
