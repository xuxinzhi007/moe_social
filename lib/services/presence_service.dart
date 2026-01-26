import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

class PresenceService {
  PresenceService._();

  static final ValueNotifier<Map<String, bool>> online =
      ValueNotifier<Map<String, bool>>(<String, bool>{});

  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static bool _connecting = false;
  static Timer? _reconnectTimer;
  static DateTime? _lastMessageAt;

  static bool get isConnected => _channel != null;

  static void start() {
    _connect();
  }

  static void stop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
  }

  static Uri _buildWebSocketUri() {
    final base = ApiService.baseUrl;
    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final token = ApiService.token;
    final query = <String, String>{};
    if (token != null && token.isNotEmpty) {
      query['token'] = token;
    }
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/ws/presence',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static void _connect() {
    if (_connecting) return;
    if (_channel != null) return;

    final token = ApiService.token;
    if (token == null || token.isEmpty) {
      return;
    }

    if (kIsWeb) {
      // Web builds may work too, but avoid unexpected CORS/origin issues by default.
      // If you want web presence, remove this guard.
      return;
    }

    _connecting = true;
    try {
      final uri = _buildWebSocketUri();
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _lastMessageAt = DateTime.now();
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_) {
          _handleDisconnected();
        },
        onDone: _handleDisconnected,
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnected();
    } finally {
      _connecting = false;
    }
  }

  static void _handleDisconnected() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    _scheduleReconnect();
  }

  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connect();
    });
  }

  static void _handleMessage(dynamic data) {
    if (data is! String) return;
    _lastMessageAt = DateTime.now();

    Map<String, dynamic> map;
    try {
      final decoded = json.decode(data);
      if (decoded is! Map<String, dynamic>) return;
      map = decoded;
    } catch (_) {
      return;
    }

    final type = map['type'] as String? ?? '';
    if (type == 'presence_snapshot') {
      final list = map['online_user_ids'];
      if (list is! List) return;
      final next = <String, bool>{};
      for (final v in list) {
        if (v == null) continue;
        next[v.toString()] = true;
      }
      online.value = next;
      return;
    }
    if (type == 'presence') {
      final id = map['user_id']?.toString();
      if (id == null || id.isEmpty) return;
      final onlineValue = map['online'];
      final isOnline =
          onlineValue == true || onlineValue == 1 || onlineValue == '1';
      final next = Map<String, bool>.from(online.value);
      if (isOnline) {
        next[id] = true;
      } else {
        next[id] = false;
      }
      online.value = next;
      return;
    }
  }

  static bool isUserOnline(String userId) {
    return online.value[userId] ?? false;
  }

  static DateTime? get lastMessageAt => _lastMessageAt;
}
