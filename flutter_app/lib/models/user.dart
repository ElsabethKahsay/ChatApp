class AppUser {
  final String userId;
  final String username;
  final String? publicKey;   // only loaded when starting a chat
  final DateTime? lastSeen;
  final bool online;

  const AppUser({
    required this.userId,
    required this.username,
    this.publicKey,
    this.lastSeen,
    this.online = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    userId:    json['userId'] as String,
    username:  json['username'] as String,
    publicKey: json['publicKey'] as String?,
    lastSeen:  json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'] as String)
        : null,
    online:    json['status'] == true || json['online'] == true,
  );
}
