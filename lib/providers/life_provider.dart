import 'package:flutter/foundation.dart';

import '../models/life_state.dart';
import '../services/life_ws_service.dart';

/// 数字生命状态管理 Provider
///
/// 持有 [LifeWsService] 实例，维护实体 Map、最近事件列表和 Tick 计数。
/// 由页面在 initState 中调用 [startListening] 建立连接。
class LifeProvider extends ChangeNotifier {
  final LifeWsService _wsService = LifeWsService();

  bool _disposed = false;
  final Map<int, LifeEntity> _entities = {};
  List<LifeEvent> _recentEvents = [];
  int _tickCount = 0;
  bool _connected = false;
  String _worldId = 'default';

  LifeProvider() {
    _wsService.onStateUpdate = _onStateUpdate;
    _wsService.onConnected = () {
      if (_disposed) return;
      _connected = true;
      notifyListeners();
    };
    _wsService.onDisconnected = () {
      if (_disposed) return;
      _connected = false;
      notifyListeners();
    };
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

  List<LifeEntity> get entities => _entities.values.toList();
  List<LifeEvent> get recentEvents => List.unmodifiable(_recentEvents);
  int get tickCount => _tickCount;
  bool get connected => _connected;
  String get worldId => _worldId;

  /// 连接 WebSocket，开始接收世界状态推送。
  void startListening() {
    _wsService.connect();
  }

  /// 断开 WebSocket，停止监听。
  void stopListening() {
    _wsService.disconnect();
  }

  /// 处理 Tick 广播更新
  void _onStateUpdate(LifeStateUpdate update) {
    if (_disposed) return;

    // 合并 entity 增量
    for (final change in update.entityChanges) {
      final rawId = change['id'];
      final id = rawId is int
          ? rawId
          : rawId is num
              ? rawId.toInt()
              : int.tryParse(rawId?.toString() ?? '');
      if (id == null) continue;

      final existing = _entities[id];
      if (existing != null) {
        _entities[id] = existing.mergeFromJson(change);
      } else {
        _entities[id] = LifeEntity.fromJson(change);
      }
    }

    // 追加事件，保留最近 50 条
    _recentEvents.addAll(update.events);
    if (_recentEvents.length > 50) {
      _recentEvents = _recentEvents.sublist(_recentEvents.length - 50);
    }

    _tickCount = update.tick;
    _worldId = update.worldId;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wsService.dispose();
    super.dispose();
  }
}
