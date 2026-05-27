import 'dart:convert';

enum AiProviderType {
  backendOllama('backend_ollama', '本机推理（llama-server）'),
  llamaCppServer('llama_cpp_server', '本机 llama.cpp'),
  openAiCompatible('openai_compatible', 'OpenAI 兼容'),
  ;

  const AiProviderType(this.value, this.label);

  final String value;
  final String label;

  static AiProviderType fromValue(String raw) {
    // 旧版 App 内嵌 GGUF 已移除，历史数据映射到 llama-server。
    if (raw == 'local_gguf') {
      return AiProviderType.llamaCppServer;
    }
    for (final item in AiProviderType.values) {
      if (item.value == raw) return item;
    }
    return AiProviderType.llamaCppServer;
  }
}

class AiProviderProfile {
  static const String builtinBackendId = 'builtin_backend_ollama';
  static const String builtinLlamaCppId = 'builtin_local_llama_cpp';

  /// 旧内置 ID（App 内嵌 GGUF），仅用于迁移到 [builtinLlamaCppId]。
  static const String legacyLocalGgufId = 'builtin_local_gguf';

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
  bool get isBuiltinLlamaCpp => id == builtinLlamaCppId;
  bool get isLegacyLocalGguf => id == legacyLocalGgufId;
  bool get isBuiltin => isBuiltinBackend || isBuiltinLlamaCpp;
  bool get isBackendOllama => providerType == AiProviderType.backendOllama;

  /// 本机 llama-server / 后端统一推理（历史字段名 backend_ollama）。
  bool get isBackendInference => isBackendOllama || isBuiltinBackend;
  bool get isLlamaCppServer => providerType == AiProviderType.llamaCppServer;
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
      name: '后端推理（已废弃）',
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

  factory AiProviderProfile.builtinLlamaCpp() {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return AiProviderProfile(
      id: builtinLlamaCppId,
      name: '本机 llama.cpp',
      providerType: AiProviderType.llamaCppServer,
      baseUrl: 'http://127.0.0.1:6633',
      defaultModel: 'qwen2',
      manualModels: const ['qwen2'],
      useServerMemory: false,
      supportsSystemMessages: true,
      supportsStreaming: false,
      supportsVision: false,
      supportsToolCalls: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  static const String defaultLocalProviderId = builtinLlamaCppId;

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
