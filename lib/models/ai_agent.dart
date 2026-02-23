class AiAgent {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String modelName;
  final String? avatarPath;
  final DateTime createdAt;

  AiAgent({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.modelName,
    this.avatarPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'system_prompt': systemPrompt,
      'model_name': modelName,
      'avatar_path': avatarPath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory AiAgent.fromMap(Map<String, dynamic> map) {
    return AiAgent(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      systemPrompt: map['system_prompt'],
      modelName: map['model_name'],
      avatarPath: map['avatar_path'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}
