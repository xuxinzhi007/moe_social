/// 角色卡：账号下的一条 JSON 记录（人设 + 绑定模型等），存于服务器 `agents_json`。
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
  final String? createdByUserId;
  final DateTime? updatedAt;
  final bool isPublic;
  final String? authorName;

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
    this.createdByUserId,
    this.updatedAt,
    this.isPublic = false,
    this.authorName,
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
      if (createdByUserId != null && createdByUserId!.isNotEmpty)
        'created_by_user_id': createdByUserId,
      if (updatedAt != null) 'updated_at': updatedAt!.millisecondsSinceEpoch,
      'is_public': isPublic,
      if (authorName != null && authorName!.isNotEmpty) 'author_name': authorName,
    };
  }

  factory AiAgent.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    final createdAt = createdRaw is num
        ? DateTime.fromMillisecondsSinceEpoch(createdRaw.toInt())
        : DateTime.now();
    final updatedRaw = map['updated_at'];
    final updatedAt = updatedRaw is num
        ? DateTime.fromMillisecondsSinceEpoch(updatedRaw.toInt())
        : null;

    return AiAgent(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      systemPrompt: map['system_prompt']?.toString() ?? '',
      modelName: map['model_name']?.toString() ?? '',
      avatarPath: map['avatar_path'] as String?,
      providerProfileId: map['provider_profile_id'] as String?,
      lorebookId: map['lorebook_id'] as String?,
      persona: (map['persona'] ?? '').toString(),
      scenario: (map['scenario'] ?? '').toString(),
      openingMessage: (map['opening_message'] ?? '').toString(),
      exampleDialogues: (map['example_dialogues'] ?? '').toString(),
      createdAt: createdAt,
      createdByUserId: map['created_by_user_id']?.toString(),
      updatedAt: updatedAt,
      isPublic: _parseBool(map['is_public']),
      authorName: map['author_name']?.toString(),
    );
  }

  static bool _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final s = raw?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes';
  }

  AiAgent copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
    String? modelName,
    String? avatarPath,
    String? providerProfileId,
    String? lorebookId,
    String? persona,
    String? scenario,
    String? openingMessage,
    String? exampleDialogues,
    DateTime? createdAt,
    String? createdByUserId,
    DateTime? updatedAt,
    bool? isPublic,
    String? authorName,
  }) {
    return AiAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelName: modelName ?? this.modelName,
      avatarPath: avatarPath ?? this.avatarPath,
      providerProfileId: providerProfileId ?? this.providerProfileId,
      lorebookId: lorebookId ?? this.lorebookId,
      persona: persona ?? this.persona,
      scenario: scenario ?? this.scenario,
      openingMessage: openingMessage ?? this.openingMessage,
      exampleDialogues: exampleDialogues ?? this.exampleDialogues,
      createdAt: createdAt ?? this.createdAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      authorName: authorName ?? this.authorName,
    );
  }
}
