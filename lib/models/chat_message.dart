class ChatMsg {
  final int id;
  final String role;
  final String content;
  final DateTime createdAt;
  final int? mealId;

  ChatMsg({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.mealId,
  });

  factory ChatMsg.fromJson(Map<String, dynamic> json) {
    return ChatMsg(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      mealId: json['meal_id'],
    );
  }
}
