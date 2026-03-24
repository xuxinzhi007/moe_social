class AiMemorySettings {
  final String agentId;
  final String extractModel;
  final String curateModel;
  final String injectMode;
  final int maxInjectedRawItems;
  final bool autoExtract;
  final bool autoCurate;
  final int curateEveryNMemories;
  final int curateEveryNTurns;
  final DateTime updatedAt;

  const AiMemorySettings({
    required this.agentId,
    required this.extractModel,
    required this.curateModel,
    required this.injectMode,
    required this.maxInjectedRawItems,
    required this.autoExtract,
    required this.autoCurate,
    required this.curateEveryNMemories,
    required this.curateEveryNTurns,
    required this.updatedAt,
  });

  factory AiMemorySettings.defaults({
    required String agentId,
    required String fallbackModel,
  }) {
    final now = DateTime.now();
    return AiMemorySettings(
      agentId: agentId,
      extractModel: fallbackModel,
      curateModel: fallbackModel,
      injectMode: 'profile_plus_top_raw',
      maxInjectedRawItems: 6,
      autoExtract: true,
      autoCurate: true,
      curateEveryNMemories: 4,
      curateEveryNTurns: 6,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        'agent_id': agentId,
        'extract_model': extractModel,
        'curate_model': curateModel,
        'inject_mode': injectMode,
        'max_injected_raw_items': maxInjectedRawItems,
        'auto_extract': autoExtract ? 1 : 0,
        'auto_curate': autoCurate ? 1 : 0,
        'curate_every_n_memories': curateEveryNMemories,
        'curate_every_n_turns': curateEveryNTurns,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory AiMemorySettings.fromMap(Map<String, dynamic> map) {
    return AiMemorySettings(
      agentId: map['agent_id'] as String,
      extractModel: (map['extract_model'] as String?) ?? '',
      curateModel: (map['curate_model'] as String?) ?? '',
      injectMode: (map['inject_mode'] as String?) ?? 'profile_plus_top_raw',
      maxInjectedRawItems: (map['max_injected_raw_items'] as int?) ?? 6,
      autoExtract: ((map['auto_extract'] as int?) ?? 1) == 1,
      autoCurate: ((map['auto_curate'] as int?) ?? 1) == 1,
      curateEveryNMemories: (map['curate_every_n_memories'] as int?) ?? 4,
      curateEveryNTurns: (map['curate_every_n_turns'] as int?) ?? 6,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  AiMemorySettings copyWith({
    String? extractModel,
    String? curateModel,
    String? injectMode,
    int? maxInjectedRawItems,
    bool? autoExtract,
    bool? autoCurate,
    int? curateEveryNMemories,
    int? curateEveryNTurns,
    DateTime? updatedAt,
  }) {
    return AiMemorySettings(
      agentId: agentId,
      extractModel: extractModel ?? this.extractModel,
      curateModel: curateModel ?? this.curateModel,
      injectMode: injectMode ?? this.injectMode,
      maxInjectedRawItems: maxInjectedRawItems ?? this.maxInjectedRawItems,
      autoExtract: autoExtract ?? this.autoExtract,
      autoCurate: autoCurate ?? this.autoCurate,
      curateEveryNMemories:
          curateEveryNMemories ?? this.curateEveryNMemories,
      curateEveryNTurns: curateEveryNTurns ?? this.curateEveryNTurns,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
