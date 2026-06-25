class SavedMessage {
  final String id;
  final Map<String, dynamic> encryptedContent;
  final String? label;
  final DateTime createdAt;

  SavedMessage({
    required this.id,
    required this.encryptedContent,
    this.label,
    required this.createdAt,
  });

  factory SavedMessage.fromJson(Map<String, dynamic> json) {
    return SavedMessage(
      id: json['_id'],
      encryptedContent: Map<String, dynamic>.from(json['content']),
      label: json['label'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}