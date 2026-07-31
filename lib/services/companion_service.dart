import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_response.dart';
import 'api_service.dart';
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
class CompanionProfileData {
  final String name;
  final String emoji;
  final String persona;
  final String greetingStyle;
  final int relationshipLevel;
  final double intimacyScore;
  final List<String> personalityTraits;
  final String systemPromptOverride;
  final String agentId;
  final int lifeEntityId;

  const CompanionProfileData({
    this.name = '',
    this.emoji = '🐾',
    this.persona = '',
    this.greetingStyle = 'warm',
    this.relationshipLevel = 1,
    this.intimacyScore = 0,
    this.personalityTraits = const [],
    this.systemPromptOverride = '',
    this.agentId = '',
    this.lifeEntityId = 0,
  });

  factory CompanionProfileData.fromMap(Map<String, dynamic> m) {
    return CompanionProfileData(
      name: m['name']?.toString() ?? '',
      emoji: m['emoji']?.toString() ?? '🐾',
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
      lifeEntityId: (m['life_entity_id'] as num?)?.toInt() ?? 0,
    );
  }

  CompanionProfileData copyWith({
    String? name,
    String? emoji,
    String? persona,
    String? greetingStyle,
    List<String>? personalityTraits,
    String? systemPromptOverride,
    String? agentId,
    int? lifeEntityId,
  }) {
    return CompanionProfileData(
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      persona: persona ?? this.persona,
      greetingStyle: greetingStyle ?? this.greetingStyle,
      relationshipLevel: relationshipLevel,
      intimacyScore: intimacyScore,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      systemPromptOverride: systemPromptOverride ?? this.systemPromptOverride,
      agentId: agentId ?? this.agentId,
      lifeEntityId: lifeEntityId ?? this.lifeEntityId,
    );
  }

  Map<String, dynamic> toRequestMap() => {
        'name': name,
        'emoji': emoji,
        'persona': persona,
        'personality_traits': personalityTraits,
        'greeting_style': greetingStyle,
        'system_prompt_override': systemPromptOverride,
        'agent_id': agentId,
        'life_entity_id': lifeEntityId,
      };
}

/// 伙伴状态（从后端获取）。
class CompanionStateData {
  final String moodThought;
  final String activityLabel;
  final String greeting;
  final double mood;
  final double hunger;
  final double energy;

  const CompanionStateData({
    this.moodThought = '',
    this.activityLabel = '',
    this.greeting = '',
    this.mood = 0.5,
    this.hunger = 0.5,
    this.energy = 0.5,
  });

  factory CompanionStateData.fromMap(Map<String, dynamic> m) {
    return CompanionStateData(
      moodThought: m['mood_thought']?.toString() ?? '',
      activityLabel: m['activity_label']?.toString() ?? '',
      greeting: m['greeting']?.toString() ?? '',
      mood: (m['mood'] as num?)?.toDouble() ?? 0.5,
      hunger: (m['hunger'] as num?)?.toDouble() ?? 0.5,
      energy: (m['energy'] as num?)?.toDouble() ?? 0.5,
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

  const CompanionMemoryData({
    required this.id,
    required this.memoryType,
    required this.content,
    required this.importance,
    required this.createdAt,
  });

  factory CompanionMemoryData.fromMap(Map<String, dynamic> m) {
    return CompanionMemoryData(
      id: (m['id'] as num?)?.toInt() ?? 0,
      memoryType: m['memory_type']?.toString() ?? '',
      content: m['content']?.toString() ?? '',
      importance: (m['importance'] as num?)?.toInt() ?? 0,
      createdAt: m['created_at']?.toString() ?? '',
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
  Stream<CompanionChatEvent> chatStream(String message) async* {
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
    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode({'message': message});

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
