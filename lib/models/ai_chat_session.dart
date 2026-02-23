class AiChatSession {
  final String id;
  final String agentId;
  final String title;
  final DateTime updatedAt;

  AiChatSession({
    required this.id,
    required this.agentId,
    required this.title,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agent_id': agentId,
      'title': title,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AiChatSession.fromMap(Map<String, dynamic> map) {
    return AiChatSession(
      id: map['id'],
      agentId: map['agent_id'],
      title: map['title'],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}
