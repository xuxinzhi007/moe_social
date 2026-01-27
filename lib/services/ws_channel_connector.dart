import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_channel_connector_stub.dart'
    if (dart.library.io) 'ws_channel_connector_io.dart'
    if (dart.library.html) 'ws_channel_connector_web.dart';

/// 统一 WebSocket 连接入口：
/// - IO 平台（Android/iOS/macOS/Windows/Linux）：支持 headers（用于 Authorization）
/// - Web 平台：浏览器 WebSocket 不允许自定义 headers，只能退化为 query / subprotocol 等方式
WebSocketChannel connectMoeWebSocket(
  Uri uri, {
  Map<String, String>? headers,
  Iterable<String>? protocols,
}) {
  return connectMoeWebSocketImpl(uri, headers: headers, protocols: protocols);
}

