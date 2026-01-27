import 'package:web_socket_channel/web_socket_channel.dart';

/// Web 平台实现：浏览器 WebSocket 不允许自定义 headers。
WebSocketChannel connectMoeWebSocketImpl(
  Uri uri, {
  Map<String, String>? headers,
  Iterable<String>? protocols,
}) {
  return WebSocketChannel.connect(uri, protocols: protocols);
}

