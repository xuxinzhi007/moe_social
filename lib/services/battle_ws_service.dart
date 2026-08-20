import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../auth_service.dart';
import 'api_service.dart';
import 'ws_channel_connector.dart';

class BattleWsService {
  StreamSubscription? _subscription;
  WebSocketChannel? _channel;
  Timer? _retry;
  int _attempt = 0;
  bool _stopped = false;
  void Function(Map<String, dynamic>)? onMessage;
  void Function(bool)? onConnection;
  void connect(String roomId) {
    _stopped = false;
    _open(roomId);
  }

  void disconnect() {
    _stopped = true;
    _retry?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    onConnection?.call(false);
  }

  void _open(String roomId) {
    if (_stopped || _channel != null) return;
    final token = AuthService.token?.replaceFirst('Bearer ', '').trim();
    if (token == null || token.isEmpty) return;
    final base = Uri.parse(ApiService.baseUrl);
    final uri = Uri(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        host: base.host,
        port: base.hasPort ? base.port : (base.scheme == 'https' ? 443 : 80),
        path: '/ws/battle',
        queryParameters: {'room_id': roomId, 'token': token});
    _channel =
        connectMoeWebSocket(uri, headers: {'Authorization': 'Bearer $token'});
    onConnection?.call(true);
    _subscription = _channel!.stream.listen((raw) {
      _attempt = 0;
      final value = jsonDecode(raw.toString());
      if (value is Map) onMessage?.call(Map<String, dynamic>.from(value));
    },
        onDone: () => _lost(roomId),
        onError: (_) => _lost(roomId),
        cancelOnError: true);
  }

  void _lost(String roomId) {
    _channel = null;
    onConnection?.call(false);
    if (_stopped) return;
    final seconds = (1 << _attempt.clamp(0, 4)).clamp(1, 12);
    _attempt++;
    _retry = Timer(Duration(seconds: seconds), () => _open(roomId));
  }
}
