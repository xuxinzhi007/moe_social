import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

// ChatPushService listens on /ws/chat to receive direct messages in real time.
// It exposes a stream of incoming messages and a per-sender unread counter.
class ChatPushService {
  ChatPushService._();

  static final ValueNotifier<Map<String, int>> unreadBySender =
      ValueNotifier<Map<String, int>>(<String, int>{});

  static final StreamController<Map<String, dynamic>> _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get incomingMessages =>
      _incomingController.stream;

  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static Timer? _reconnectTimer;
  static Timer? _heartbeatTimer;
  static bool _connecting = false;

  static bool get isConnected => _channel != null;

  static WebSocketChannel? get channel => _channel;

  static void start() {
    _connect();
  }

  static void stop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
  }

  // Ensure the current user is considered online even if they never open a DM.
  // We keep the websocket connected, but also send a lightweight ping message
  // so the server-side handler has a read loop activity.
  static void ping() {
    try {
      _channel?.sink.add(json.encode({'type': 'ping'}));
    } catch (_) {}
  }

  static Uri _buildWebSocketUri() {
    final base = ApiService.baseUrl;
    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    var token = ApiService.token?.trim();
    if (token != null && token.startsWith('Bearer ')) {
      token = token.substring('Bearer '.length).trim();
    }
    final query = <String, String>{};
    if (token != null && token.isNotEmpty) {
      query['token'] = token;
    }
    return Uri(
      scheme: scheme,
      host: uri.host,
      // 避免没有显式端口时出现 ":0"
      port: uri.hasPort ? uri.port : defaultPort,
      path: '/ws/chat',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static void _connect() {
    if (_connecting) return;
    if (_channel != null) return;

    final token = ApiService.token;
    if (token == null || token.isEmpty) {
      // Token might not be ready yet; keep retrying until auth is available.
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        _connect();
      });
      return;
    }

    // Web is supported by web_socket_channel; no special handling needed.

    _connecting = true;
    try {
      final wsUri = _buildWebSocketUri();
      final ch = WebSocketChannel.connect(wsUri);
      _channel = ch;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        ping();
      });
      _subscription = ch.stream.listen(
        _handleMessage,
        onDone: _handleDisconnected,
        onError: (_) => _handleDisconnected(),
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connect();
    });
  }

  static void _handleMessage(dynamic data) {
    if (data is! String) return;

    Map<String, dynamic> map;
    try {
      final decoded = json.decode(data);
      if (decoded is! Map<String, dynamic>) return;
      map = decoded;
    } catch (_) {
      return;
    }

    final from = map['from']?.toString();
    final content = map['content']?.toString();
    if (from == null || from.isEmpty || content == null) {
      return;
    }

    // Broadcast message to listeners
    _incomingController.add(map);

    // Increment unread counter by sender
    final next = Map<String, int>.from(unreadBySender.value);
    next[from] = (next[from] ?? 0) + 1;
    unreadBySender.value = next;
  }

  static void markSenderRead(String senderId) {
    if (senderId.isEmpty) return;
    final next = Map<String, int>.from(unreadBySender.value);
    if (!next.containsKey(senderId)) return;
    next.remove(senderId);
    unreadBySender.value = next;
  }
}
