enum MessageType { text, media, voice, image }

class Message {
  final String id;
  final String fromUserId;
  final String? groupId;
  final String text;
  final DateTime sentAt;
  final DateTime expiresAt;
  final DateTime? readAt;
  final bool isMe;
  final bool delivered;
  final bool sending;
  final String? mediaUrl;
  final Map<String, dynamic>? rawPayload;

  Message({
    required this.id,
    required this.fromUserId,
    this.groupId,
    required this.text,
    required this.sentAt,
    this.readAt,
    this.isMe = false,
    this.delivered = false,
    this.sending = false,
    this.mediaUrl,
    this.rawPayload,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt ?? sentAt.add(const Duration(hours: 24));

  Message copyWith({
    String? text,
    String? fromUserId, // V1 FIX
    bool? delivered,
    bool? sending,
    DateTime? readAt,
    String? mediaUrl, // V1 FIX
  }) {
    return Message(
      id: id,
      fromUserId: fromUserId ?? this.fromUserId,
      groupId: groupId,
      text: text ?? this.text,
      sentAt: sentAt,
      expiresAt: expiresAt,
      readAt: readAt ?? this.readAt,
      isMe: isMe,
      delivered: delivered ?? this.delivered,
      sending: sending ?? this.sending,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      rawPayload: rawPayload,
    );
  }
}
