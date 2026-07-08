import 'package:flutter/foundation.dart';

import '../models/life_state.dart';
import '../services/life_service.dart';
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
  final List<LifeRelationship> _relationships = [];
  int _tickCount = 0;
  bool _connected = false;
  bool _isInitialized = false;
  String _worldId = 'default';
  LifeWorldSummary _summary = LifeWorldSummary.empty;

  /// 最近一次操作失败的错误信息（null 表示无错误）。
  String? _lastActionError;

  /// 最近一次操作失败是否为冷却限制（区别于真正的错误）。
  bool _lastActionIsCooldown = false;

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
  List<LifeRelationship> get relationships => List.unmodifiable(_relationships);
  int get tickCount => _tickCount;
  bool get connected => _connected;
  bool get isInitialized => _isInitialized;
  String get worldId => _worldId;
  LifeWorldSummary get summary => _summary;

  /// 最近一次操作失败的错误信息，null 表示无错误。
  String? get lastActionError => _lastActionError;

  /// 最近一次失败是否为冷却限制（`true` 时 UI 应展示温和提示而非红色错误）。
  bool get lastActionIsCooldown => _lastActionIsCooldown;

  /// 清除操作错误信息。
  void clearActionError() {
    _lastActionError = null;
    _lastActionIsCooldown = false;
    notifyListeners();
  }

  /// 获取指定实体的所有关系。
  List<LifeRelationship> getRelationshipsForEntity(int entityId) {
    return _relationships
        .where((r) => r.entityId == entityId || r.targetId == entityId)
        .toList();
  }

  /// 关系统计
  int get friendCount =>
      _relationships.where((r) => r.relationType == 'friend').length;
  int get mateCount =>
      _relationships.where((r) => r.relationType == 'mate').length;
  int get rivalCount =>
      _relationships.where((r) => r.relationType == 'rival').length;

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

    // 移除已死亡的实体
    for (final removedId in update.removedEntityIds) {
      if (_entities.remove(removedId) != null) {
        debugPrint('LifeProvider: 移除已死亡实体 id=$removedId');
      }
    }

    // 合并 relationship 增量更新
    for (final rel in update.relationshipChanges) {
      final idx = _relationships.indexWhere(
        (r) => r.entityId == rel.entityId && r.targetId == rel.targetId,
      );
      if (idx >= 0) {
        _relationships[idx] = rel;
      } else {
        _relationships.add(rel);
      }
    }
    // 移除已解除的关系
    for (final removed in update.removedRelationships) {
      _relationships.removeWhere(
        (r) =>
            r.entityId == removed['entity_id'] &&
            r.targetId == removed['target_id'],
      );
    }

    // 追加事件，保留最近 50 条
    _recentEvents.addAll(update.events);
    if (_recentEvents.length > 50) {
      _recentEvents = _recentEvents.sublist(_recentEvents.length - 50);
    }

    _tickCount = update.tick;
    _worldId = update.worldId;
    _summary = update.summary;
    if (!_isInitialized) {
      _isInitialized = true;
    }
    notifyListeners();
  }

  // ── 操作方法 ──────────────────────────────────────────────────────────────────

  /// 执行操作（喂食、抚摸等），带乐观更新。
  ///
  /// 返回 `true` 表示 API 调用成功，`false` 表示失败（可查看 [lastActionError]）。
  Future<bool> performAction(String action, int entityId) async {
    final entity = _entities[entityId];
    if (entity == null) return false;

    // 快照用于回滚（LifeEntity 不可变，保存旧实例即可）
    final previousEntity = entity;

    // 乐观更新本地属性
    if (action == 'feed') {
      _entities[entityId] = LifeEntity(
        id: entity.id,
        name: entity.name,
        emoji: entity.emoji,
        hunger: (entity.hunger + 20).clamp(0, 100).toDouble(),
        energy: entity.energy,
        mood: (entity.mood + 5).clamp(0, 100).toDouble(),
        action: entity.action,
        x: entity.x,
        y: entity.y,
        growthStage: entity.growthStage,
        experience: entity.experience,
        age: entity.age,
      );
    } else if (action == 'pet') {
      _entities[entityId] = LifeEntity(
        id: entity.id,
        name: entity.name,
        emoji: entity.emoji,
        hunger: entity.hunger,
        energy: entity.energy,
        mood: (entity.mood + 15).clamp(0, 100).toDouble(),
        action: entity.action,
        x: entity.x,
        y: entity.y,
        growthStage: entity.growthStage,
        experience: entity.experience,
        age: entity.age,
      );
    }
    notifyListeners();

    try {
      await LifeService.postLifeAction(action, entityId);

      // 插入本地临时事件（即时反馈）
      final String eventName;
      final String eventDesc;
      switch (action) {
        case 'feed':
          eventName = 'user_feed';
          eventDesc = '你喂了${entity.name}';
          break;
        case 'pet':
          eventName = 'user_pet';
          eventDesc = '你抚摸了${entity.name}';
          break;
        default:
          eventName = 'user_action';
          eventDesc = '你对${entity.name}执行了操作';
      }
      final localEvent = LifeEvent(
        entityId: entityId,
        entityType: entity.emoji,
        type: eventName,
        desc: eventDesc,
        x: entity.x,
        y: entity.y,
        timestamp: DateTime.now(),
      );
      _recentEvents.insert(0, localEvent);
      if (_recentEvents.length > 50) _recentEvents.removeLast();
      notifyListeners();
      return true;
    } on LifeActionCooldownException catch (e) {
      // 回滚乐观更新
      _entities[entityId] = previousEntity;
      _lastActionError = '稍等一下，${e.retryAfter}秒后再试试吧~';
      _lastActionIsCooldown = true;
      notifyListeners();
      return false;
    } catch (e) {
      // 回滚乐观更新
      _entities[entityId] = previousEntity;
      _lastActionError = e.toString();
      _lastActionIsCooldown = false;
      notifyListeners();
      return false;
    }
  }

  /// 喂食指定实体。
  Future<bool> feedEntity(int entityId) => performAction('feed', entityId);

  /// 抚摸指定实体。
  Future<bool> petEntity(int entityId) => performAction('pet', entityId);

  @override
  void dispose() {
    _disposed = true;
    _wsService.dispose();
    super.dispose();
  }
}
