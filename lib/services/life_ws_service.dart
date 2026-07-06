import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';
import 'ws_channel_connector.dart';
import '../models/life_state.dart';

/// 数字生命 WebSocket 服务
///
/// 连接 /ws/life，接收实时世界状态更新。
/// 连接管理模式（指数退避、心跳、消息分发）严格参照 [ChatPushService]。
class LifeWsService {
  static const String _wsPath = '/ws/life';

  // ── 连接状态 ──────────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connecting = false;
  bool _disposed = false;

  // ── 重连 ────────────────────────────────────────────────────────────────────
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _baseReconnectDelay = 3;
  static const int _maxReconnectDelay = 10;

  // ── 心跳 ────────────────────────────────────────────────────────────────────
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 20);

  // ── 消息回调 ────────────────────────────────────────────────────────────────
  void Function(LifeStateUpdate)? onStateUpdate;
  void Function()? onConnected;
  void Function()? onDisconnected;

  bool get connected => _channel != null;

  // ── URI 构建 ────────────────────────────────────────────────────────────────

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

  // ── 连接 / 断开 ────────────────────────────────────────────────────────────

  /// 建立连接
  void connect() {
    if (_disposed) return;
    if (_connecting) return;
    if (_channel != null) return;

    final rawToken = _rawToken();
    if (rawToken == null || rawToken.isEmpty) {
      // Token 未就绪，稍后重试
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        connect();
      });
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

      // 连接成功后，发送 subscribe 消息
      try {
        _channel?.sink.add(jsonEncode({'type': 'subscribe', 'world': 'default'}));
        debugPrint('LifeWsService: 已发送 subscribe 消息');
      } catch (e) {
        debugPrint('LifeWsService: 发送 subscribe 失败: $e');
      }

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
        _sendHeartbeat();
      });

      _subscription = ch.stream.listen(
        _handleRawMessage,
        onDone: _handleDisconnected,
        onError: (error) {
          if (error.toString().contains('401')) {
            if (kDebugMode) {
              debugPrint('LifeWsService: 401 Unauthorized，停止重连。');
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
        debugPrint('LifeWsService: 连接异常: $e');
      }
      _handleDisconnected();
    } finally {
      _connecting = false;
    }
  }

  /// 断开连接（不触发重连）
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
    _reconnectAttempts = 0;
  }

  // ── 心跳 ────────────────────────────────────────────────────────────────────

  void _sendHeartbeat() {
    try {
      _channel?.sink.add(json.encode({'type': 'ping'}));
    } catch (_) {}
  }

  // ── 消息处理 ────────────────────────────────────────────────────────────────

  void _handleRawMessage(dynamic data) {
    if (data is! String) return;
    // 收到真实消息说明 WS 健康，重置退避计数。
    _reconnectAttempts = 0;

    // 首次收到消息视为连接成功
    if (!_connecting) {
      onConnected?.call();
    }

    final Map<String, dynamic> map;
    try {
      final decoded = json.decode(data);
      if (decoded is! Map) return;
      map = Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LifeWsService: 消息解析失败: $e');
      }
      return;
    }

    final type = map['type']?.toString();
    if (type == 'pong') return;

    if (type == 'state_snapshot') {
      // state_snapshot 包含完整实体列表，当作全量 state update 处理
      try {
        final entities = (map['entities'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
        onStateUpdate?.call(LifeStateUpdate(
          worldId: map['world_id']?.toString() ?? 'default',
          tick: map['tick'] is int ? map['tick'] as int : 0,
          entityChanges: entities,
          events: const [],
        ));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LifeWsService: state_snapshot 解析失败: $e');
        }
      }
      return;
    }

    if (type == 'life_state') {
      try {
        final update = LifeStateUpdate.fromJson(map);
        onStateUpdate?.call(update);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LifeWsService: LifeStateUpdate 解析失败: $e');
        }
      }
    }
  }

  // ── 断线重连 ────────────────────────────────────────────────────────────────

  void _handleDisconnected() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    onDisconnected?.call();

    if (_disposed) return;

    // 指数退避：3s → 6s → 12s → … → 10s（上限）
    _reconnectTimer?.cancel();
    final attempts = _reconnectAttempts.clamp(0, 5);
    final delay = _baseReconnectDelay * (1 << attempts);
    final clampedDelay = delay.clamp(_baseReconnectDelay, _maxReconnectDelay);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: clampedDelay), () {
      connect();
    });
  }

  // ── 释放 ────────────────────────────────────────────────────────────────────

  void dispose() {
    _disposed = true;
    disconnect();
  }
}
