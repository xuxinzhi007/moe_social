import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/game_network_service.dart';

/// 异地联机实验页的状态模型。
class GameNetworkProvider extends ChangeNotifier {
  GameNetworkProvider({GameNetworkService? service})
      : _service = service ?? GameNetworkService() {
    _subscription = _service.events.listen(_applyEvent);
  }

  final GameNetworkService _service;
  late final StreamSubscription<GameNetworkEvent> _subscription;

  GameNetworkState _state = GameNetworkState.idle;
  String _message = '尚未连接';
  int _peerCount = 0;
  int _sentPackets = 0;
  int _receivedPackets = 0;

  GameNetworkState get state => _state;
  String get message => _message;
  int get peerCount => _peerCount;
  int get sentPackets => _sentPackets;
  int get receivedPackets => _receivedPackets;

  bool get isRunning => _state == GameNetworkState.running;

  bool get isBusy => _state == GameNetworkState.connecting;

  bool get isLocked =>
      isBusy ||
      _state == GameNetworkState.waitingVpnPermission ||
      _state == GameNetworkState.running;

  Future<void> start({
    required String roomId,
    required String role,
  }) async {
    try {
      await _service.start(roomId: roomId, role: role);
    } catch (error) {
      _state = GameNetworkState.error;
      _message = error.toString();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _service.stop();
  }

  void onAppResumed() {
    _service.onAppResumed();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_service.stop());
    _service.dispose();
    super.dispose();
  }

  void _applyEvent(GameNetworkEvent event) {
    _state = event.state;
    _message = event.message;
    _peerCount = event.peerCount;
    _sentPackets = event.sentPackets;
    _receivedPackets = event.receivedPackets;
    notifyListeners();
  }
}
