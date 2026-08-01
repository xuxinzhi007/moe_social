import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';
import 'ws_channel_connector.dart';

/// Companion `/ws/companion` 推送的存在感事件。
class CompanionPresenceEvent {
  const CompanionPresenceEvent({
    required this.type,
    this.greeting = '',
    this.moodThought = '',
    this.activityLabel = '',
  });

  /// `state_snapshot` | `greeting` | `proactive`
  final String type;
  final String greeting;
  final String moodThought;
  final String activityLabel;
}

/// 伙伴 WebSocket：连接 / 心跳 / 指数退避重连（模式对齐 [LifeWsService]）。
class CompanionWsService {
  static const String _wsPath = '/ws/companion';
  static const int _baseReconnectDelay = 3;
  static const int _maxReconnectDelay = 10;
  static const Duration _heartbeatInterval = Duration(seconds: 20);

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _connecting = false;
  bool _disposed = false;
  bool _notifiedConnected = false;
  int _reconnectAttempts = 0;

  void Function(CompanionPresenceEvent event)? onPresence;
  void Function()? onConnected;
  void Function()? onDisconnected;

  bool get connected => _channel != null;

  static String? _rawToken() {
    var token = ApiService.token?.trim();
    if (token == null || token.isEmpty) return null;
    if (token.startsWith('Bearer ')) {
      token = token.substring('Bearer '.length).trim();
    }
    return token.isEmpty ? null : token;
  }

  static Uri _buildWebSocketUri({String? token}) {
    final base = ApiService.baseUrl;
    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    final query = <String, String>{};
    if (token != null && token.isNotEmpty) {
      query['token'] = token;
    }
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : defaultPort,
      path: _wsPath,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  void connect() {
    if (_disposed) return;
    if (_connecting || _channel != null) return;

    final rawToken = _rawToken();
    if (rawToken == null || rawToken.isEmpty) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), connect);
      return;
    }

    _connecting = true;
    try {
      final wsUri = _buildWebSocketUri(token: rawToken);
      final headers = <String, String>{
        ...ApiService.tunnelBypassHeadersForUrl(ApiService.baseUrl),
      };
      if (!kIsWeb) {
        headers['Authorization'] = 'Bearer $rawToken';
      }

      final ch = connectMoeWebSocket(wsUri, headers: headers);
      _channel = ch;

      try {
        _channel?.sink.add(jsonEncode({'type': 'subscribe'}));
      } catch (_) {}

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });

      _subscription = ch.stream.listen(
        _handleRawMessage,
        onDone: _handleDisconnected,
        onError: (error) {
          if (error.toString().contains('401')) {
            if (kDebugMode) {
              debugPrint('CompanionWsService: 401，停止重连');
            }
            disconnect();
            return;
          }
          _handleDisconnected();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CompanionWsService: 连接异常: $e');
      }
      _handleDisconnected();
    } finally {
      _connecting = false;
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
    _notifiedConnected = false;
    _reconnectAttempts = 0;
  }

  void _handleRawMessage(dynamic data) {
    if (data is! String) return;
    _reconnectAttempts = 0;

    if (!_notifiedConnected) {
      _notifiedConnected = true;
      onConnected?.call();
    }

    final Map<String, dynamic> map;
    try {
      final decoded = json.decode(data);
      if (decoded is! Map) return;
      map = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    final type = map['type']?.toString() ?? '';
    if (type == 'pong') return;

    if (type == 'state_snapshot' || type == 'greeting' || type == 'proactive') {
      onPresence?.call(
        CompanionPresenceEvent(
          type: type,
          greeting: map['greeting']?.toString() ?? '',
          moodThought: map['mood']?.toString() ?? '',
          activityLabel: map['activity']?.toString() ?? '',
        ),
      );
    }
  }

  void _handleDisconnected() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _notifiedConnected = false;
    onDisconnected?.call();

    if (_disposed) return;

    _reconnectTimer?.cancel();
    final attempts = _reconnectAttempts.clamp(0, 5);
    final delay = (_baseReconnectDelay * (1 << attempts))
        .clamp(_baseReconnectDelay, _maxReconnectDelay);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delay), connect);
  }

  void dispose() {
    _disposed = true;
    disconnect();
  }
}
