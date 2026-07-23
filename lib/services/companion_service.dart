import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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

  const CompanionProfileData({
    this.name = '',
    this.emoji = '🐾',
    this.persona = '',
    this.greetingStyle = 'warm',
    this.relationshipLevel = 1,
    this.intimacyScore = 0,
  });

  factory CompanionProfileData.fromMap(Map<String, dynamic> m) {
    return CompanionProfileData(
      name: m['name']?.toString() ?? '',
      emoji: m['emoji']?.toString() ?? '🐾',
      persona: m['persona']?.toString() ?? '',
      greetingStyle: m['greeting_style']?.toString() ?? 'warm',
      relationshipLevel: (m['relationship_level'] as num?)?.toInt() ?? 1,
      intimacyScore: (m['intimacy_score'] as num?)?.toDouble() ?? 0,
    );
  }
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

/// 伙伴聊天服务 —— 接入后端 SSE 流式聊天。
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
    return CompanionProfileData.fromMap(ApiResponse.payload(result));
  }

  /// 获取伙伴状态。
  Future<CompanionStateData> getState() async {
    _requireUserId();
    final result = await ApiService.get('/api/companion/state');
    return CompanionStateData.fromMap(ApiResponse.payload(result));
  }

  /// SSE 流式聊天。
  Stream<CompanionChatEvent> chatStream(String message) async* {
    _requireUserId();
    final uri =
        Uri.parse('${ApiService.baseUrl}/api/companion/chat/stream');
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
    final text = payload?['text']?.toString() ??
        payload?['content']?.toString() ??
        '';
    return CompanionChatEvent(type: eventName, text: text, payload: payload);
  }
}
