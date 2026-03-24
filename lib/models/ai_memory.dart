class AiMemory {
  final String id;
  final String agentId;
  final String content;
  final String category;
  final int importance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiMemory({
    required this.id,
    required this.agentId,
    required this.content,
    this.category = 'general',
    this.importance = 3,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'agent_id': agentId,
        'content': content,
        'category': category,
        'importance': importance,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory AiMemory.fromMap(Map<String, dynamic> map) => AiMemory(
        id: map['id'] as String,
        agentId: map['agent_id'] as String,
        content: map['content'] as String,
        category: (map['category'] as String?) ?? 'general',
        importance: (map['importance'] as int?) ?? 3,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );

  AiMemory copyWith({
    String? content,
    String? category,
    int? importance,
    DateTime? updatedAt,
  }) =>
      AiMemory(
        id: id,
        agentId: agentId,
        content: content ?? this.content,
        category: category ?? this.category,
        importance: importance ?? this.importance,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// 根据类别返回对应的中文标签和 emoji
  static (String label, String emoji) categoryMeta(String category) {
    return switch (category) {
      'preference' => ('偏好', '❤️'),
      'reminder' => ('提醒', '⏰'),
      'habit' => ('习惯', '🔄'),
      'personal' => ('个人信息', '👤'),
      _ => ('一般', '📝'),
    };
  }
}
