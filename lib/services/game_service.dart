import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth_service.dart';
import '../models/game_state.dart';
import 'api_response.dart';
import 'api_service.dart';

class GameActStreamEvent {
  final String type;
  final String text;
  final Map<String, dynamic>? payload;

  const GameActStreamEvent({
    required this.type,
    this.text = '',
    this.payload,
  });
}

class GameService {
  GameService._();

  static final GameService _instance = GameService._();
  factory GameService() => _instance;

  http.Client? _activeStreamClient;

  void cancelStream() {
    _activeStreamClient?.close();
    _activeStreamClient = null;
  }

  static String? _requireUserId() {
    final userId = AuthService.currentUser;
    if (!ApiResponse.isValidUserId(userId)) {
      throw Exception('请先登录后再进入游戏世界');
    }
    return userId;
  }

  Future<GameSessionState> initSession({bool forceNew = false}) async {
    final userId = _requireUserId()!;
    final result = await ApiService.post('/api/user/$userId/game/init', body: {
      'user_id': userId,
      'force_new': forceNew,
    });
    if (!ApiResponse.isSuccess(result)) {
      throw Exception(result['message']?.toString() ?? '初始化游戏失败');
    }
    final state = GameSessionState.fromMap(ApiResponse.payload(result));
    if (state.visitedScenes.isEmpty && state.scene.name.isNotEmpty) {
      return state.copyWith(visitedScenes: [state.scene.name]);
    }
    return state;
  }

  Future<GameActResult> act({
    required int sessionId,
    required String action,
  }) async {
    final userId = _requireUserId()!;
    final result = await ApiService.post('/api/user/$userId/game/act', body: {
      'user_id': userId,
      'session_id': sessionId,
      'action': action,
    });
    if (!ApiResponse.isSuccess(result)) {
      throw Exception(result['message']?.toString() ?? '行动失败');
    }
    return GameActResult.fromMap(ApiResponse.payload(result));
  }

  /// P3：SSE 流式行动，在线时逐字推送 narrative。
  Stream<GameActStreamEvent> actStream({
    required int sessionId,
    required String action,
  }) async* {
    final userId = _requireUserId()!;
    final uri =
        Uri.parse('${ApiService.baseUrl}/api/user/$userId/game/act/stream');
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
      ..body = jsonEncode({
        'user_id': userId,
        'session_id': sessionId,
        'action': action,
      });

    final client = http.Client();
    _activeStreamClient = client;
    try {
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception('流式行动失败 (${response.statusCode}): $body');
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

  GameActStreamEvent? _parseSseBlock(String block) {
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
    final text = payload?['text']?.toString() ?? '';
    return GameActStreamEvent(type: eventName, text: text, payload: payload);
  }

  Future<GameSessionState> getState({required int sessionId}) async {
    final userId = _requireUserId()!;
    final result = await ApiService.get(
      '/api/user/$userId/game/state?session_id=$sessionId',
    );
    if (!ApiResponse.isSuccess(result)) {
      throw Exception(result['message']?.toString() ?? '获取状态失败');
    }
    return GameSessionState.fromMap(ApiResponse.payload(result));
  }
}
