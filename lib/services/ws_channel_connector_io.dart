import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// IO 平台实现：支持 headers（用于 Authorization）。
WebSocketChannel connectMoeWebSocketImpl(
  Uri uri, {
  Map<String, String>? headers,
  Iterable<String>? protocols,
}) {
  return IOWebSocketChannel.connect(uri, headers: headers, protocols: protocols);
}

