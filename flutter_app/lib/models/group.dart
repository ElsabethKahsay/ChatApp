class Group {
  final String id;
  final String name;
  final List<String> members;
  final Map<String, dynamic> myWrappedKey;

  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.myWrappedKey,
  });

  factory Group.fromJson(Map<String, dynamic> json, String currentUserId) {
    final keysMap = json['encryptedKeys'] as Map<String, dynamic>;
    // Extract only the key wrapped for the current user
    final wrappedKey = keysMap[currentUserId] ?? {};
    
    return Group(
      id: json['_id'],
      name: json['name'],
      members: List<String>.from(json['members']),
      myWrappedKey: Map<String, dynamic>.from(wrappedKey),
    );
  }
}