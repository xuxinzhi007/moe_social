import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import 'api_service.dart';

const String _gameNetworkChannelName = 'com.moe_social/game_network';
const String _gameNetworkPath = '/ws/game-network';
const String _roleHost = 'host';
const String _roleGuest = 'guest';
const String _hostVirtualIp = '10.66.0.1';
const String _guestVirtualIp = '10.66.0.2';
const Duration _statusPollInterval = Duration(seconds: 1);
const Duration _nativeStartupTimeout = Duration(seconds: 10);

/// Android 异地联机实验的连接状态。
enum GameNetworkState {
  idle,
  connecting,
  waitingVpnPermission,
  running,
  stopped,
  error,
}

/// Android 异地联机实验的状态事件。
class GameNetworkEvent {
  const GameNetworkEvent({
    required this.state,
    required this.message,
    required this.peerCount,
    required this.sentPackets,
    required this.receivedPackets,
  });

  final GameNetworkState state;
  final String message;
  final int peerCount;
  final int sentPackets;
  final int receivedPackets;
}

/// 管理 Flutter UI 与 Android 原生后台联机服务之间的状态同步。
class GameNetworkService {
  GameNetworkService();

  static const String hostVirtualIp = _hostVirtualIp;
  static const String guestVirtualIp = _guestVirtualIp;
  static const String hostRole = _roleHost;
  static const String guestRole = _roleGuest;

  static const MethodChannel _methodChannel =
      MethodChannel(_gameNetworkChannelName);

  final StreamController<GameNetworkEvent> _events =
      StreamController<GameNetworkEvent>.broadcast();

  Timer? _statusPoller;
  GameNetworkState _state = GameNetworkState.idle;
  String _message = '尚未连接';
  String? _roomId;
  String? _role;
  int _peerCount = 0;
  int _sentPackets = 0;
  int _receivedPackets = 0;
  bool _nativeStarted = false;
  bool _stopping = false;
  bool _disposed = false;
  DateTime? _nativeStartupDeadline;

  Stream<GameNetworkEvent> get events => _events.stream;

  GameNetworkState get state => _state;

  String get localVirtualIp =>
      _role == _roleGuest ? _guestVirtualIp : _hostVirtualIp;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 启动 Android 原生 VPN 与后台 WebSocket 中继。
  Future<void> start({
    required String roomId,
    required String role,
  }) async {
    if (_disposed) {
      _setState(GameNetworkState.error, '连接服务已释放');
      return;
    }
    if (!isSupported) {
      _setState(GameNetworkState.error, '当前实验只支持 Android');
      return;
    }

    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', '房间号不能为空');
    }
    if (role != _roleHost && role != _roleGuest) {
      throw ArgumentError.value(role, 'role', '角色必须是 host 或 guest');
    }

    if (_nativeStarted && (_roomId != normalizedRoomId || _role != role)) {
      await stop();
    }

    _stopping = false;
    _roomId = normalizedRoomId;
    _role = role;
    _peerCount = 0;
    _sentPackets = 0;
    _receivedPackets = 0;
    _setState(GameNetworkState.connecting, '正在连接房间中继');

    final prepared = await _methodChannel.invokeMethod<bool>(
          'prepareGameNetworkVpn',
        ) ??
        false;
    if (!prepared) {
      _setState(
        GameNetworkState.waitingVpnPermission,
        '请在系统弹窗中允许 VPN，然后再次点击启动',
      );
      return;
    }

    final token = _rawToken();
    final started = await _methodChannel.invokeMethod<bool>(
          'startGameNetworkVpn',
          <String, dynamic>{
            'role': role,
            'roomId': normalizedRoomId,
            'relayUrl': _relayBaseUrl(),
            'token': token,
          },
        ) ??
        false;
    if (!started) {
      throw StateError('Android VPN 服务启动失败');
    }

    _nativeStarted = true;
    _nativeStartupDeadline = DateTime.now().add(_nativeStartupTimeout);
    _startStatusPolling();
    _setState(GameNetworkState.connecting, '正在启动后台联机服务');
    unawaited(_refreshNativeStatus());
  }

  /// 停止 Android 原生 VPN 与后台中继。
  Future<void> stop() async {
    _stopping = true;
    _nativeStarted = false;
    _nativeStartupDeadline = null;
    _statusPoller?.cancel();
    _statusPoller = null;
    if (isSupported) {
      try {
        await _methodChannel.invokeMethod<void>('stopGameNetworkVpn');
      } catch (_) {
        // 服务可能已经被系统回收，仍然继续复位本地状态。
      }
    }
    _peerCount = 0;
    _setState(GameNetworkState.stopped, '已停止');
  }

  /// 释放实验服务资源。
  void dispose() {
    _disposed = true;
    _stopping = true;
    _statusPoller?.cancel();
    _statusPoller = null;
    unawaited(_events.close());
  }

  /// 回到前台时刷新原生服务状态。
  void onAppResumed() {
    if (_nativeStarted && !_stopping && !_disposed) {
      unawaited(_refreshNativeStatus());
    }
  }

  void _startStatusPolling() {
    _statusPoller?.cancel();
    _statusPoller = Timer.periodic(_statusPollInterval, (_) {
      unawaited(_refreshNativeStatus());
    });
  }

  Future<void> _refreshNativeStatus() async {
    if (!_nativeStarted || _stopping || _disposed) {
      return;
    }
    try {
      final snapshot = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'gameNetworkStatus',
      );
      if (snapshot == null || !_nativeStarted || _stopping || _disposed) {
        return;
      }

      _peerCount = _asInt(snapshot['peerCount']) ?? 0;
      _sentPackets = _asInt(snapshot['sentPackets']) ?? 0;
      _receivedPackets = _asInt(snapshot['receivedPackets']) ?? 0;

      final running = snapshot['running'] == true;
      final relayConnected = snapshot['relayConnected'] == true;
      final nativeMessage = snapshot['status']?.toString() ?? '';
      if (!running) {
        final deadline = _nativeStartupDeadline;
        if (deadline != null && DateTime.now().isBefore(deadline)) {
          _setState(GameNetworkState.connecting, '正在启动 VPN 服务');
        } else {
          _setState(
            GameNetworkState.error,
            nativeMessage.isEmpty ? 'VPN 服务已停止' : nativeMessage,
          );
        }
        return;
      }

      _nativeStartupDeadline = null;
      if (!relayConnected) {
        _setState(
          GameNetworkState.connecting,
          nativeMessage.isEmpty ? '正在连接房间中继' : nativeMessage,
        );
        return;
      }

      _setState(
        GameNetworkState.running,
        _peerCount >= 2 ? '两端已连接' : '等待另一端加入',
      );
    } catch (error) {
      if (!_stopping && !_disposed) {
        _setState(GameNetworkState.error, '读取后台联机状态失败：$error');
      }
    }
  }

  String _relayBaseUrl() {
    final baseUri = Uri.parse(ApiService.baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final defaultPort = baseUri.scheme == 'https' ? 443 : 80;
    return Uri(
      scheme: scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : defaultPort,
      path: _gameNetworkPath,
    ).toString();
  }

  String? _rawToken() {
    var token = ApiService.token?.trim();
    token ??= AuthService.token?.trim();
    if (token == null || token.isEmpty) {
      return null;
    }
    if (token.startsWith('Bearer ')) {
      token = token.substring('Bearer '.length).trim();
    }
    return token.isEmpty ? null : token;
  }

  void _setState(GameNetworkState state, String message) {
    _state = state;
    _message = message;
    _publish();
  }

  void _publish() {
    if (_events.isClosed) {
      return;
    }
    _events.add(
      GameNetworkEvent(
        state: _state,
        message: _message,
        peerCount: _peerCount,
        sentPackets: _sentPackets,
        receivedPackets: _receivedPackets,
      ),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
