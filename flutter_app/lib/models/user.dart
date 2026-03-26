class AppUser {
  final String userId;
  final String username;
  final String? publicKey;   // only loaded when starting a chat
  final DateTime? lastSeen;

  const AppUser({
    required this.userId,
    required this.username,
    this.publicKey,
    this.lastSeen,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    userId:    json['userId'] as String,
    username:  json['username'] as String,
    publicKey: json['publicKey'] as String?,
    lastSeen:  json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'] as String)
        : null,
  );
}
