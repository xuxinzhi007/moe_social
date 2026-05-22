import 'dart:convert';

enum AiProviderType {
  backendOllama('backend_ollama', '后端 Ollama'),
  localGguf('local_gguf', '本机 GGUF'),
  openAiCompatible('openai_compatible', 'OpenAI 兼容'),
  ;

  const AiProviderType(this.value, this.label);

  final String value;
  final String label;

  static AiProviderType fromValue(String raw) {
    for (final item in AiProviderType.values) {
      if (item.value == raw) return item;
    }
    return AiProviderType.backendOllama;
  }
}

class AiProviderProfile {
  static const String builtinBackendId = 'builtin_backend_ollama';
  static const String builtinLocalGgufId = 'builtin_local_gguf';

  final String id;
  final String name;
  final AiProviderType providerType;
  final String baseUrl;
  final String defaultModel;
  final List<String> manualModels;
  final bool useServerMemory;
  final bool supportsSystemMessages;
  final bool supportsStreaming;
  final bool supportsVision;
  final bool supportsToolCalls;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiProviderProfile({
    required this.id,
    required this.name,
    required this.providerType,
    required this.baseUrl,
    required this.defaultModel,
    required this.manualModels,
    required this.useServerMemory,
    this.supportsSystemMessages = true,
    this.supportsStreaming = false,
    this.supportsVision = false,
    this.supportsToolCalls = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isBuiltinBackend => id == builtinBackendId;
  bool get isBuiltinLocal => id == builtinLocalGgufId;
  bool get isBackendOllama => providerType == AiProviderType.backendOllama;
  bool get isLocalGguf => providerType == AiProviderType.localGguf;
  bool get isOpenAiCompatible =>
      providerType == AiProviderType.openAiCompatible;

  /// 当 /models 不可用时，用于下拉与「模型来源」列表的回退模型 ID。
  List<String> get effectiveModelIds {
    final ids = <String>{};
    final def = defaultModel.trim();
    if (def.isNotEmpty) ids.add(def);
    for (final raw in manualModels) {
      final id = raw.trim();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids.toList();
  }

  bool get hasConfiguredModels => effectiveModelIds.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider_type': providerType.value,
      'base_url': baseUrl,
      'default_model': defaultModel,
      'manual_models_json': jsonEncode(manualModels),
      'use_server_memory': useServerMemory ? 1 : 0,
      'supports_system_messages': supportsSystemMessages ? 1 : 0,
      'supports_streaming': supportsStreaming ? 1 : 0,
      'supports_vision': supportsVision ? 1 : 0,
      'supports_tool_calls': supportsToolCalls ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AiProviderProfile.fromMap(Map<String, dynamic> map) {
    final rawModels = (map['manual_models_json'] ?? '[]').toString();
    List<String> manualModels;
    try {
      final decoded = jsonDecode(rawModels);
      manualModels = decoded is List
          ? decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
    } catch (_) {
      manualModels = <String>[];
    }
    return AiProviderProfile(
      id: map['id'].toString(),
      name: map['name'].toString(),
      providerType: AiProviderType.fromValue(map['provider_type'].toString()),
      baseUrl: (map['base_url'] ?? '').toString(),
      defaultModel: (map['default_model'] ?? '').toString(),
      manualModels: manualModels,
      useServerMemory: (map['use_server_memory'] is num)
          ? (map['use_server_memory'] as num).toInt() == 1
          : map['use_server_memory'] == true,
      supportsSystemMessages: (map['supports_system_messages'] is num)
          ? (map['supports_system_messages'] as num).toInt() != 0
          : (map['supports_system_messages'] ?? true) == true,
      supportsStreaming: (map['supports_streaming'] is num)
          ? (map['supports_streaming'] as num).toInt() != 0
          : (map['supports_streaming'] ?? true) == true,
      supportsVision: (map['supports_vision'] is num)
          ? (map['supports_vision'] as num).toInt() == 1
          : map['supports_vision'] == true,
      supportsToolCalls: (map['supports_tool_calls'] is num)
          ? (map['supports_tool_calls'] as num).toInt() == 1
          : map['supports_tool_calls'] == true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
    );
  }

  factory AiProviderProfile.builtinBackend() {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return AiProviderProfile(
      id: builtinBackendId,
      name: '内置 Ollama',
      providerType: AiProviderType.backendOllama,
      baseUrl: '',
      defaultModel: '',
      manualModels: const [],
      useServerMemory: true,
      supportsSystemMessages: true,
      supportsStreaming: true,
      supportsVision: false,
      supportsToolCalls: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 本机已下载 GGUF + llama.cpp；默认开启记忆工具（需 Qwen2.5 等支持 JSON 工具调用的模型）。
  factory AiProviderProfile.builtinLocalGguf() {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return AiProviderProfile(
      id: builtinLocalGgufId,
      name: '本机 GGUF（离线）',
      providerType: AiProviderType.localGguf,
      baseUrl: '',
      defaultModel: 'qwen2.5-1.5b-instruct-q4',
      manualModels: const [
        'qwen2.5-0.5b-instruct-q4',
        'qwen2.5-1.5b-instruct-q4',
      ],
      useServerMemory: false,
      supportsSystemMessages: true,
      supportsStreaming: true,
      supportsVision: false,
      supportsToolCalls: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  AiProviderProfile copyWith({
    String? id,
    String? name,
    AiProviderType? providerType,
    String? baseUrl,
    String? defaultModel,
    List<String>? manualModels,
    bool? useServerMemory,
    bool? supportsSystemMessages,
    bool? supportsStreaming,
    bool? supportsVision,
    bool? supportsToolCalls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiProviderProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      providerType: providerType ?? this.providerType,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      manualModels: manualModels ?? this.manualModels,
      useServerMemory: useServerMemory ?? this.useServerMemory,
      supportsSystemMessages:
          supportsSystemMessages ?? this.supportsSystemMessages,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      supportsVision: supportsVision ?? this.supportsVision,
      supportsToolCalls: supportsToolCalls ?? this.supportsToolCalls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
