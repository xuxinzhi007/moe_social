import 'package:web_socket_channel/web_socket_channel.dart';

/// 默认实现（用于不支持 dart:io 的平台）：忽略 headers。
WebSocketChannel connectMoeWebSocketImpl(
  Uri uri, {
  Map<String, String>? headers,
  Iterable<String>? protocols,
}) {
  return WebSocketChannel.connect(uri, protocols: protocols);
}

