import 'dart:convert';

enum AiProviderType {
  backendOllama('backend_ollama', '后端推理'),
  llamaCppServer('llama_cpp_server', '本机 llama.cpp'),
  openAiCompatible('openai_compatible', 'OpenAI 兼容'),
  ;

  const AiProviderType(this.value, this.label);

  final String value;
  final String label;

  static AiProviderType fromValue(String raw) {
    for (final item in AiProviderType.values) {
      if (item.value == raw) return item;
    }
    return AiProviderType.openAiCompatible;
  }
}

class AiProviderProfile {
  static const String builtinBackendId = 'builtin_backend_ollama';
  static const String legacyBuiltinLocalLlamaCppId = 'builtin_local_llama_cpp';

  static const Set<String> builtinProviderIds = {
    builtinBackendId,
    legacyBuiltinLocalLlamaCppId,
  };

  final String id;
  final String name;
  final AiProviderType providerType;
  final String baseUrl;
  final String defaultModel;
  final List<String> manualModels;
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
    this.supportsSystemMessages = true,
    this.supportsStreaming = false,
    this.supportsVision = false,
    this.supportsToolCalls = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isBuiltinBackend => isBuiltinProviderId(id);
  bool get isBuiltin => isBuiltinBackend;
  bool get isBackendOllama => providerType == AiProviderType.backendOllama;
  bool get isLlamaCppServer => providerType == AiProviderType.llamaCppServer;
  bool get isOpenAiCompatible =>
      providerType == AiProviderType.openAiCompatible;

  static bool isBuiltinProviderId(String? raw) {
    final normalized = raw?.trim() ?? '';
    return builtinProviderIds.contains(normalized);
  }

  static bool isLegacyBuiltinProviderId(String? raw) {
    return raw?.trim() == legacyBuiltinLocalLlamaCppId;
  }

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

  /// 发送聊天时实际使用的模型 ID；没有显式默认值时取列表第一项。
  String get effectiveModelId {
    final preferred = defaultModel.trim();
    if (preferred.isNotEmpty) return preferred;
    final ids = effectiveModelIds;
    return ids.isEmpty ? '' : ids.first;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider_type': providerType.value,
      'base_url': baseUrl,
      'default_model': defaultModel,
      'manual_models_json': jsonEncode(manualModels),
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
      name: '后端推理',
      providerType: AiProviderType.backendOllama,
      baseUrl: '',
      defaultModel: '',
      manualModels: const [],
      supportsSystemMessages: true,
      supportsStreaming: true,
      supportsVision: false,
      supportsToolCalls: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 直连本机 llama.cpp / 局域网 OpenAI 兼容网关时可不填 Key。
  bool get requiresApiKey =>
      isOpenAiCompatible &&
      !isLlamaCppServer &&
      baseUrl.trim().isNotEmpty &&
      !_looksLikeLocalBaseUrl(baseUrl);

  static bool _looksLikeLocalBaseUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return true;
    final h = uri.host.toLowerCase();
    return h == 'localhost' ||
        h == '127.0.0.1' ||
        h == '10.0.2.2' ||
        h.startsWith('192.168.') ||
        h.startsWith('10.');
  }

  AiProviderProfile copyWith({
    String? id,
    String? name,
    AiProviderType? providerType,
    String? baseUrl,
    String? defaultModel,
    List<String>? manualModels,
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
