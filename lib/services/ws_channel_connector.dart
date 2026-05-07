import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_channel_connector_stub.dart'
    if (dart.library.io) 'ws_channel_connector_io.dart'
    if (dart.library.html) 'ws_channel_connector_web.dart';

/// 统一 WebSocket 连接入口：
/// - IO 平台（Android/iOS/macOS/Windows/Linux）：支持 headers（用于 Authorization）
/// - Web 平台：浏览器 WebSocket 不允许自定义 headers，只能退化为 query / subprotocol 等方式
///
/// 注意：`web_socket_channel 2.x` 在底层 `IOWebSocketChannel.connect` 失败时，
/// 既会通过 stream 抛 `WebSocketChannelException`，又会调用
/// `channel._readyCompleter.completeError(...)`。如果调用方只 listen 了 stream
/// 而没有 await `channel.ready`，那个 ready Future 上的错误就会成为
/// "unhandled async error"，被 `runZonedGuarded` 兜底打印为
/// `Uncaught Error: WebSocketChannelException: WebSocket connection failed.`，
/// 而且会在每一次重连失败时重复刷屏。
/// 这里在统一入口处主动消费一次 `ready`，把这条意外路径吞掉，
/// 真实的连接失败仍然会通过 stream 的 `onError` 抛给调用方处理。
WebSocketChannel connectMoeWebSocket(
  Uri uri, {
  Map<String, String>? headers,
  Iterable<String>? protocols,
}) {
  final channel =
      connectMoeWebSocketImpl(uri, headers: headers, protocols: protocols);
  unawaited(channel.ready.catchError((Object _) {}));
  return channel;
}

