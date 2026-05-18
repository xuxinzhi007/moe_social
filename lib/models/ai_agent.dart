class AiAgent {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String modelName;
  final String? avatarPath;
  final String? providerProfileId;
  final String? lorebookId;
  final String persona;
  final String scenario;
  final String openingMessage;
  final String exampleDialogues;
  final DateTime createdAt;

  AiAgent({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.modelName,
    this.avatarPath,
    this.providerProfileId,
    this.lorebookId,
    this.persona = '',
    this.scenario = '',
    this.openingMessage = '',
    this.exampleDialogues = '',
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
      'provider_profile_id': providerProfileId,
      'lorebook_id': lorebookId,
      'persona': persona,
      'scenario': scenario,
      'opening_message': openingMessage,
      'example_dialogues': exampleDialogues,
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
      providerProfileId: map['provider_profile_id'] as String?,
      lorebookId: map['lorebook_id'] as String?,
      persona: (map['persona'] ?? '').toString(),
      scenario: (map['scenario'] ?? '').toString(),
      openingMessage: (map['opening_message'] ?? '').toString(),
      exampleDialogues: (map['example_dialogues'] ?? '').toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}
