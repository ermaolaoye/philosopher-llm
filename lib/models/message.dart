enum MessageRole {
  user,
  assistant,
  system
}

class Message {
  String content;
  final MessageRole role;
  final DateTime timestamp;

  Message({
    required this.content,
    required this.role,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'role': role.toString().split('.').last,
      'content': content,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      content: json['content'],
      role: MessageRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
      ),
    );
  }
} 