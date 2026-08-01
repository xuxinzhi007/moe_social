import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_response.dart';
import 'api_service.dart';
import 'ai_provider_service.dart';
import '../auth_service.dart';

/// 伙伴聊天 SSE 事件。
class CompanionChatEvent {
  final String type; // start / delta / done / error
  final String text;
  final Map<String, dynamic>? payload;

  const CompanionChatEvent({
    required this.type,
    this.text = '',
    this.payload,
  });
}

/// 伙伴 Profile（从后端获取）。
///
/// 双层身份：name/emoji/avatarUrl/persona = 关系层（用户自定义）；
/// lifeEntityId = 世界层绑定，不反向覆盖关系层形象。
class CompanionProfileData {
  final String name;
  final String emoji;
  final String avatarUrl;
  final String persona;
  final String greetingStyle;
  final int relationshipLevel;
  final double intimacyScore;
  final List<String> personalityTraits;
  final String systemPromptOverride;
  final String agentId;
  final int lifeEntityId;

  /// unbound | bound_ok | bound_missing
  final String worldBindStatus;

  const CompanionProfileData({
    this.name = '',
    this.emoji = '🐾',
    this.avatarUrl = '',
    this.persona = '',
    this.greetingStyle = 'warm',
    this.relationshipLevel = 1,
    this.intimacyScore = 0,
    this.personalityTraits = const [],
    this.systemPromptOverride = '',
    this.agentId = '',
    this.lifeEntityId = 0,
    this.worldBindStatus = 'unbound',
  });

  bool get isWorldBound => lifeEntityId > 0;

  bool get isWorldBindMissing =>
      lifeEntityId > 0 && worldBindStatus == 'bound_missing';

  double get relationshipProgress => (intimacyScore / 100).clamp(0.0, 1.0);

  String get relationshipStageLabel {
    final score = intimacyScore.clamp(0.0, 100.0);
    if (score < 10) return '初识';
    if (score < 25) return '熟悉中';
    if (score < 45) return '开始依赖';
    if (score < 70) return '彼此习惯';
    if (score < 90) return '很懂彼此';
    return '特别亲近';
  }

  String get relationshipProgressLabel {
    final level = relationshipLevel.clamp(1, 10);
    return 'Lv.$level · ${intimacyScore.round()}%';
  }

  factory CompanionProfileData.fromMap(Map<String, dynamic> m) {
    final lifeEntityId = (m['life_entity_id'] as num?)?.toInt() ?? 0;
    var status = m['world_bind_status']?.toString() ??
        m['worldBindStatus']?.toString() ??
        '';
    if (status.isEmpty) {
      status = lifeEntityId > 0 ? 'bound_ok' : 'unbound';
    }
    return CompanionProfileData(
      name: m['name']?.toString() ?? '',
      emoji: m['emoji']?.toString() ?? '🐾',
      avatarUrl:
          m['avatar_url']?.toString() ?? m['avatarUrl']?.toString() ?? '',
      persona: m['persona']?.toString() ?? '',
      greetingStyle: m['greeting_style']?.toString() ?? 'warm',
      relationshipLevel: (m['relationship_level'] as num?)?.toInt() ?? 1,
      intimacyScore: (m['intimacy_score'] as num?)?.toDouble() ?? 0,
      personalityTraits: (m['personality_traits'] as List?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const [],
      systemPromptOverride: m['system_prompt_override']?.toString() ?? '',
      agentId: m['agent_id']?.toString() ?? '',
      lifeEntityId: lifeEntityId,
      worldBindStatus: status,
    );
  }

  CompanionProfileData copyWith({
    String? name,
    String? emoji,
    String? avatarUrl,
    String? persona,
    String? greetingStyle,
    List<String>? personalityTraits,
    String? systemPromptOverride,
    String? agentId,
    int? lifeEntityId,
    String? worldBindStatus,
  }) {
    return CompanionProfileData(
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      persona: persona ?? this.persona,
      greetingStyle: greetingStyle ?? this.greetingStyle,
      relationshipLevel: relationshipLevel,
      intimacyScore: intimacyScore,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      systemPromptOverride: systemPromptOverride ?? this.systemPromptOverride,
      agentId: agentId ?? this.agentId,
      lifeEntityId: lifeEntityId ?? this.lifeEntityId,
      worldBindStatus: worldBindStatus ?? this.worldBindStatus,
    );
  }

  Map<String, dynamic> toRequestMap() => {
        'name': name,
        'emoji': emoji,
        'avatar_url': avatarUrl,
        'persona': persona,
        'personality_traits': personalityTraits,
        'greeting_style': greetingStyle,
        'system_prompt_override': systemPromptOverride,
        'agent_id': agentId,
        'life_entity_id': lifeEntityId,
      };
}

class CompanionProactiveSettingsData {
  final bool enabled;
  final int dailyLimit;
  final int quietStart;
  final int quietEnd;
  final int timezoneOffset;

  const CompanionProactiveSettingsData({
    this.enabled = true,
    this.dailyLimit = 1,
    this.quietStart = 1350,
    this.quietEnd = 450,
    this.timezoneOffset = 0,
  });

  factory CompanionProactiveSettingsData.fromMap(Map<String, dynamic> map) {
    return CompanionProactiveSettingsData(
      enabled: map['enabled'] != false,
      dailyLimit: (map['daily_limit'] as num?)?.toInt() ?? 1,
      quietStart: (map['quiet_start'] as num?)?.toInt() ?? 1350,
      quietEnd: (map['quiet_end'] as num?)?.toInt() ?? 450,
      timezoneOffset: (map['timezone_offset'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toRequestMap() => {
        'enabled': enabled,
        'daily_limit': dailyLimit,
        'quiet_start': quietStart,
        'quiet_end': quietEnd,
        'timezone_offset': timezoneOffset,
      };
}

/// 伙伴动态卡片（后端 `state.moments`）。
class CompanionMomentData {
  final String text;
  final String icon;
  final String timeLabel;

  const CompanionMomentData({
    this.text = '',
    this.icon = '',
    this.timeLabel = '',
  });

  factory CompanionMomentData.fromMap(Map<String, dynamic> m) {
    return CompanionMomentData(
      text: m['text']?.toString() ?? '',
      icon: m['icon']?.toString() ?? '',
      timeLabel:
          m['time_label']?.toString() ?? m['timeLabel']?.toString() ?? '',
    );
  }
}

/// 伙伴状态（从后端获取）。
class CompanionStateData {
  final String moodThought;
  final String activityLabel;
  final String greeting;
  final List<CompanionMomentData> moments;
  final double mood;
  final double hunger;
  final double energy;
  final bool entityAlive;
  final String worldBindStatus;

  const CompanionStateData({
    this.moodThought = '',
    this.activityLabel = '',
    this.greeting = '',
    this.moments = const [],
    this.mood = 0.5,
    this.hunger = 0.5,
    this.energy = 0.5,
    this.entityAlive = true,
    this.worldBindStatus = 'unbound',
  });

  CompanionStateData copyWith({
    String? moodThought,
    String? activityLabel,
    String? greeting,
    List<CompanionMomentData>? moments,
    double? mood,
    double? hunger,
    double? energy,
    bool? entityAlive,
    String? worldBindStatus,
  }) {
    return CompanionStateData(
      moodThought: moodThought ?? this.moodThought,
      activityLabel: activityLabel ?? this.activityLabel,
      greeting: greeting ?? this.greeting,
      moments: moments ?? this.moments,
      mood: mood ?? this.mood,
      hunger: hunger ?? this.hunger,
      energy: energy ?? this.energy,
      entityAlive: entityAlive ?? this.entityAlive,
      worldBindStatus: worldBindStatus ?? this.worldBindStatus,
    );
  }

  factory CompanionStateData.fromMap(Map<String, dynamic> m) {
    final rawMoments = m['moments'];
    final moments = <CompanionMomentData>[];
    if (rawMoments is List) {
      for (final item in rawMoments) {
        if (item is Map<String, dynamic>) {
          moments.add(CompanionMomentData.fromMap(item));
        } else if (item is Map) {
          moments.add(
            CompanionMomentData.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return CompanionStateData(
      moodThought: m['mood_thought']?.toString() ?? '',
      activityLabel: m['activity_label']?.toString() ?? '',
      greeting: m['greeting']?.toString() ?? '',
      moments: List<CompanionMomentData>.unmodifiable(moments),
      mood: (m['mood'] as num?)?.toDouble() ?? 0.5,
      hunger: (m['hunger'] as num?)?.toDouble() ?? 0.5,
      energy: (m['energy'] as num?)?.toDouble() ?? 0.5,
      entityAlive: m['entity_alive'] != false,
      worldBindStatus: m['world_bind_status']?.toString() ??
          m['worldBindStatus']?.toString() ??
          '',
    );
  }
}

class CompanionSnapshotData {
  final CompanionProfileData profile;
  final CompanionStateData state;

  const CompanionSnapshotData({required this.profile, required this.state});
}

class CompanionCommunityIdentityData {
  final String userId;
  final String userName;
  final String userAvatar;
  final String agentId;
  final bool authorIsBot;
  final String authorBotAgentKey;

  const CompanionCommunityIdentityData({
    this.userId = '',
    this.userName = '',
    this.userAvatar = '',
    this.agentId = '',
    this.authorIsBot = false,
    this.authorBotAgentKey = '',
  });

  factory CompanionCommunityIdentityData.fromMap(Map<String, dynamic> m) {
    return CompanionCommunityIdentityData(
      userId: m['user_id']?.toString() ?? '',
      userName: m['user_name']?.toString() ?? '',
      userAvatar: m['user_avatar']?.toString() ?? '',
      agentId: m['agent_id']?.toString() ?? '',
      authorIsBot: m['author_is_bot'] is bool
          ? m['author_is_bot'] as bool
          : (m['author_is_bot'] as num?)?.toInt() == 1,
      authorBotAgentKey: m['author_bot_agent_key']?.toString() ?? '',
    );
  }

  bool get isValid => userId.isNotEmpty;
}

class CompanionMemoryData {
  final int id;
  final String memoryType;
  final String content;
  final int importance;
  final String createdAt;
  final bool pinned;
  final bool userConfirmed;
  final String confirmedAt;
  final String memoryKey;
  final double confidence;

  const CompanionMemoryData({
    required this.id,
    required this.memoryType,
    required this.content,
    required this.importance,
    required this.createdAt,
    this.pinned = false,
    this.userConfirmed = false,
    this.confirmedAt = '',
    this.memoryKey = '',
    this.confidence = 0.5,
  });

  factory CompanionMemoryData.fromMap(Map<String, dynamic> m) {
    return CompanionMemoryData(
      id: (m['id'] as num?)?.toInt() ?? 0,
      memoryType: m['memory_type']?.toString() ?? '',
      content: m['content']?.toString() ?? '',
      importance: (m['importance'] as num?)?.toInt() ?? 0,
      createdAt: m['created_at']?.toString() ?? '',
      pinned: m['pinned'] == true,
      userConfirmed: m['user_confirmed'] == true,
      confirmedAt: m['confirmed_at']?.toString() ?? '',
      memoryKey: m['memory_key']?.toString() ?? '',
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }

  CompanionMemoryData copyWith({
    String? content,
    int? importance,
    bool? pinned,
  }) {
    return CompanionMemoryData(
      id: id,
      memoryType: memoryType,
      content: content ?? this.content,
      importance: importance ?? this.importance,
      createdAt: createdAt,
      pinned: pinned ?? this.pinned,
      userConfirmed: userConfirmed,
      confirmedAt: confirmedAt,
      memoryKey: memoryKey,
      confidence: confidence,
    );
  }
}

class CompanionChatLogData {
  final int id;
  final String role;
  final String content;
  final String createdAt;

  const CompanionChatLogData({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory CompanionChatLogData.fromMap(Map<String, dynamic> m) {
    return CompanionChatLogData(
      id: (m['id'] as num?)?.toInt() ?? 0,
      role: m['role']?.toString() ?? '',
      content: m['content']?.toString() ?? '',
      createdAt: m['created_at']?.toString() ?? '',
    );
  }
}

class CompanionRelationshipEventData {
  final int id;
  final String eventType;
  final String title;
  final String content;
  final int relationshipLevel;
  final double intimacyScore;
  final String createdAt;

  const CompanionRelationshipEventData({
    required this.id,
    required this.eventType,
    required this.title,
    required this.content,
    required this.relationshipLevel,
    required this.intimacyScore,
    required this.createdAt,
  });

  factory CompanionRelationshipEventData.fromMap(Map<String, dynamic> m) {
    return CompanionRelationshipEventData(
      id: (m['id'] as num?)?.toInt() ?? 0,
      eventType: m['event_type']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      content: m['content']?.toString() ?? '',
      relationshipLevel: (m['relationship_level'] as num?)?.toInt() ?? 1,
      intimacyScore: (m['intimacy_score'] as num?)?.toDouble() ?? 0,
      createdAt: m['created_at']?.toString() ?? '',
    );
  }
}

/// 伙伴聊天 / Profile 域服务 —— 接入后端 `/api/companion/*` 与 SSE。
///
/// 一期语义：当前登录用户的「活跃伙伴」一条（见 FeatureFlags.companionSingleActiveBondPhase1）。
/// 二期多角色：在本域扩展列表/切换，勿改走酒馆 AgentList。
/// 决策 SSOT：`docs/dev/ai-companion-formal-decisions.md`。
class CompanionService {
  CompanionService._();

  static final CompanionService _instance = CompanionService._();
  factory CompanionService() => _instance;

  http.Client? _activeStreamClient;

  void cancelStream() {
    _activeStreamClient?.close();
    _activeStreamClient = null;
  }

  static String? _requireUserId() {
    final userId = AuthService.currentUser;
    if (!ApiResponse.isValidUserId(userId)) {
      throw Exception('请先登录');
    }
    return userId;
  }

  /// 获取伙伴 Profile。
  Future<CompanionProfileData> getProfile() async {
    _requireUserId();
    final result = await ApiService.get('/api/companion/profile');
    return CompanionProfileData.fromMap(
      ApiResponse.object(result, keys: const ['profile']),
    );
  }

  /// 获取同一后端快照中的伙伴身份与状态。
  Future<CompanionSnapshotData> getSnapshot() async {
    _requireUserId();
    final result = await ApiService.get('/api/companion/state');
    return CompanionSnapshotData(
      profile: CompanionProfileData.fromMap(
        ApiResponse.object(result, keys: const ['profile']),
      ),
      state: CompanionStateData.fromMap(
        ApiResponse.object(result, keys: const ['state']),
      ),
    );
  }

  Future<CompanionCommunityIdentityData> getCommunityIdentity() async {
    _requireUserId();
    final result = await ApiService.get('/api/companion/community-identity');
    return CompanionCommunityIdentityData.fromMap(
      ApiResponse.object(result, keys: const ['identity']),
    );
  }

  /// 照料等互动后亲密度微增（聊天由后端 ChatStream 内建处理）。
  Future<void> bumpIntimacy({String reason = 'care'}) async {
    _requireUserId();
    await ApiService.post(
      '/api/companion/intimacy/bump',
      body: {'reason': reason},
    );
  }

  Future<CompanionProfileData> updateProfile(
    CompanionProfileData profile,
  ) async {
    _requireUserId();
    final result = await ApiService.post(
      '/api/companion/profile',
      body: profile.toRequestMap(),
    );
    return CompanionProfileData.fromMap(
      ApiResponse.object(result, keys: const ['profile']),
    );
  }

  Future<CompanionProactiveSettingsData> getProactiveSettings() async {
    _requireUserId();
    final result = await ApiService.get('/api/companion/proactive-settings');
    return CompanionProactiveSettingsData.fromMap(
      ApiResponse.object(result, keys: const ['settings']),
    );
  }

  Future<CompanionProactiveSettingsData> updateProactiveSettings(
    CompanionProactiveSettingsData settings,
  ) async {
    _requireUserId();
    final result = await ApiService.put(
      '/api/companion/proactive-settings',
      body: settings.toRequestMap(),
    );
    return CompanionProactiveSettingsData.fromMap(
      ApiResponse.object(result, keys: const ['settings']),
    );
  }

  Future<List<CompanionMemoryData>> listMemories({int limit = 8}) async {
    _requireUserId();
    final result = await ApiService.get('/api/companion/memories?limit=$limit');
    final items = ApiResponse.listOf(result, keys: const ['memories']);
    return items
        .whereType<Map>()
        .map((item) =>
            CompanionMemoryData.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<CompanionRelationshipEventData>> listRelationshipEvents({
    int limit = 8,
  }) async {
    _requireUserId();
    final result = await ApiService.get(
      '/api/companion/relationship-events?limit=$limit',
    );
    final items = ApiResponse.listOf(result, keys: const ['events']);
    return items
        .whereType<Map>()
        .map((item) => CompanionRelationshipEventData.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<void> deleteMemory(int memoryId) async {
    _requireUserId();
    if (memoryId <= 0) {
      throw Exception('无效的记忆');
    }
    await ApiService.delete('/api/companion/memories/$memoryId');
  }

  Future<CompanionMemoryData> setMemoryPinned({
    required int memoryId,
    required bool pinned,
  }) async {
    _requireUserId();
    if (memoryId <= 0) {
      throw Exception('无效的记忆');
    }
    final result = await ApiService.post(
      '/api/companion/memories/$memoryId/pin',
      body: {'pinned': pinned},
    );
    return CompanionMemoryData.fromMap(
      ApiResponse.object(result, keys: const ['memory']),
    );
  }

  Future<CompanionMemoryData> updateMemoryContent({
    required int memoryId,
    required String content,
  }) async {
    _requireUserId();
    if (memoryId <= 0) {
      throw Exception('无效的记忆');
    }
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('记忆内容不能为空');
    }
    final result = await ApiService.put(
      '/api/companion/memories/$memoryId',
      body: {'content': trimmed},
    );
    return CompanionMemoryData.fromMap(
      ApiResponse.object(result, keys: const ['memory']),
    );
  }

  Future<CompanionMemoryData> confirmMemory(int memoryId) async {
    _requireUserId();
    if (memoryId <= 0) {
      throw Exception('无效的记忆');
    }
    final result = await ApiService.post(
      '/api/companion/memories/$memoryId/confirm',
      body: const <String, dynamic>{},
    );
    return CompanionMemoryData.fromMap(
      ApiResponse.object(result, keys: const ['memory']),
    );
  }

  Future<List<CompanionChatLogData>> listChatHistory({int limit = 12}) async {
    _requireUserId();
    final result =
        await ApiService.get('/api/companion/chat/history?limit=$limit');
    final items =
        ApiResponse.listOf(result, keys: const ['messages', 'history']);
    return items
        .whereType<Map>()
        .map((item) =>
            CompanionChatLogData.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  String _readMarkerKey(String userId) => 'companion_chat_read_at_$userId';

  Future<DateTime?> loadChatReadAt() async {
    final userId = _requireUserId();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_readMarkerKey(userId!));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markChatRead() async {
    final userId = _requireUserId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _readMarkerKey(userId!),
      DateTime.now().toIso8601String(),
    );
  }

  /// SSE 流式聊天。
  Stream<CompanionChatEvent> chatStream(
    String message, {
    String? scene,
  }) async* {
    _requireUserId();
    final uri = Uri.parse('${ApiService.baseUrl}/api/companion/chat/stream');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      ...ApiService.tunnelBypassHeadersForUrl(ApiService.baseUrl),
    };
    final token = ApiService.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final body = <String, dynamic>{'message': message};
    if (scene != null && scene.trim().isNotEmpty) {
      body['scene'] = scene.trim();
    }
    try {
      final selectedId = await AiProviderService().readLastSelectedProfileId();
      final provider = await AiProviderService().resolveProfile(selectedId);
      if (!provider.isBuiltinBackend &&
          provider.baseUrl.trim().isNotEmpty &&
          provider.defaultModel.trim().isNotEmpty) {
        body.addAll({
          'provider_base_url': provider.baseUrl.trim(),
          'provider_api_style': provider.isBackendOllama ? 'ollama' : 'openai',
          'provider_model': provider.defaultModel.trim(),
          'provider_api_key': await AiProviderService().readApiKey(provider.id),
          'provider_timeout_seconds': 120,
        });
      }
    } catch (_) {
      // Fall back to the backend inference configuration.
    }
    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(body);

    final client = http.Client();
    _activeStreamClient = client;
    try {
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception('聊天失败 (${response.statusCode}): $body');
      }

      var dataBuffer = StringBuffer();
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        dataBuffer.write(chunk);
        var buffer = dataBuffer.toString();
        while (true) {
          final sep = buffer.indexOf('\n\n');
          if (sep < 0) break;
          final block = buffer.substring(0, sep);
          buffer = buffer.substring(sep + 2);
          final event = _parseSseBlock(block);
          if (event != null) {
            yield event;
          }
        }
        dataBuffer = StringBuffer()..write(buffer);
      }
      // 流结束时刷掉未以 \n\n 结尾的尾包，避免丢掉最后一截 delta/done。
      final trailing = dataBuffer.toString().trim();
      if (trailing.isNotEmpty) {
        final event = _parseSseBlock(trailing);
        if (event != null) {
          yield event;
        }
      }
    } finally {
      client.close();
      _activeStreamClient = null;
    }
  }

  CompanionChatEvent? _parseSseBlock(String block) {
    var eventName = 'message';
    final dataLines = <String>[];
    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
    if (dataLines.isEmpty) return null;
    final raw = dataLines.join('\n');
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      } else if (decoded is Map) {
        payload = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      payload = {'raw': raw};
    }
    final text =
        payload?['text']?.toString() ?? payload?['content']?.toString() ?? '';
    return CompanionChatEvent(type: eventName, text: text, payload: payload);
  }
}
