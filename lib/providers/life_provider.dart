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
  bool _isBootstrapping = false;
  final Map<int, LifeEntity> _entities = {};
  List<LifeEvent> _recentEvents = [];
  final List<LifeRelationship> _relationships = [];
  final List<WorldEventDiff> _worldEvents = [];
  int _tickCount = 0;
  bool _connected = false;
  bool _isInitialized = false;
  String _worldId = 'default';
  LifeWorldSummary _summary = LifeWorldSummary.empty;

  // 背包道具状态
  List<LifeInventoryItem> _inventory = [];
  List<LifeItem> _allItems = [];
  bool _inventoryLoading = false;

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
  List<WorldEventDiff> get worldEvents => List.unmodifiable(_worldEvents);
  int get tickCount => _tickCount;
  bool get connected => _connected;
  bool get isInitialized => _isInitialized;
  String get worldId => _worldId;
  LifeWorldSummary get summary => _summary;

  /// 背包道具列表
  List<LifeInventoryItem> get inventory => List.unmodifiable(_inventory);

  /// 所有道具定义
  List<LifeItem> get allItems => List.unmodifiable(_allItems);

  /// 背包加载中
  bool get inventoryLoading => _inventoryLoading;

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
    if (_isBootstrapping) return;
    if (_isInitialized) {
      _wsService.connect();
      return;
    }
    _bootstrapAndConnect();
  }

  /// 断开 WebSocket，停止监听。
  void stopListening() {
    _wsService.disconnect();
  }

  Future<void> _bootstrapAndConnect() async {
    _isBootstrapping = true;
    try {
      final snapshot = await LifeService.getInitialState();
      if (_disposed) return;
      _applyInitialState(snapshot);
    } catch (e) {
      debugPrint('LifeProvider bootstrap failed: $e');
    } finally {
      _isBootstrapping = false;
      if (!_disposed) {
        _wsService.connect();
      }
    }
  }

  void _applyInitialState(LifeInitialState snapshot) {
    _entities
      ..clear()
      ..addEntries(snapshot.entities.map((e) => MapEntry(e.id, e)));
    _relationships
      ..clear()
      ..addAll(snapshot.relationships);
    _recentEvents = List<LifeEvent>.from(snapshot.events);
    _worldEvents.clear();
    _tickCount = snapshot.tick;
    _worldId = snapshot.worldId;
    _summary = snapshot.summary;
    _isInitialized = true;
    notifyListeners();
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

    // 合并世界事件增量
    for (final we in update.worldEvents) {
      final idx = _worldEvents.indexWhere((e) => e.type == we.type);
      if (idx >= 0) {
        _worldEvents[idx] = we;
      } else {
        _worldEvents.add(we);
      }
    }
    // 移除已停用的世界事件
    _worldEvents.removeWhere((e) => !e.active);

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
        activeEffects: entity.activeEffects,
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
        activeEffects: entity.activeEffects,
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

  // ── 背包道具操作 ──────────────────────────────────────────────────────────

  /// 加载背包和道具定义。
  Future<void> fetchInventory() async {
    if (_inventoryLoading) return;
    _inventoryLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        LifeService.getLifeInventory(),
        LifeService.getLifeItems(),
      ]);
      if (_disposed) return;
      _inventory = results[0] as List<LifeInventoryItem>;
      _allItems = results[1] as List<LifeItem>;
    } catch (e) {
      debugPrint('fetchInventory error: $e');
    } finally {
      _inventoryLoading = false;
      notifyListeners();
    }
  }

  /// 对指定实体使用道具（带乐观更新）。
  Future<bool> useItem(int entityId, int itemId) async {
    final entity = _entities[entityId];
    if (entity == null) return false;

    // 找到背包中对应道具
    final invIdx = _inventory.indexWhere((i) => i.itemId == itemId);
    if (invIdx < 0) return false;
    final invItem = _inventory[invIdx];
    if (invItem.quantity <= 0) return false;

    // 快照用于回滚
    final previousInventory = List<LifeInventoryItem>.from(_inventory);

    // 乐观更新：本地 quantity - 1
    _inventory[invIdx] = LifeInventoryItem(
      itemId: invItem.itemId,
      quantity: invItem.quantity - 1,
      item: invItem.item,
    );
    notifyListeners();

    try {
      final ok = await LifeService.useLifeItem(entityId, itemId);
      if (!ok) throw Exception('使用道具失败');

      // 插入本地临时事件
      final itemName = invItem.displayName;
      final localEvent = LifeEvent(
        entityId: entityId,
        entityType: entity.emoji,
        type: 'user_use_item',
        desc: '你对${entity.name}使用了 $itemName',
        x: entity.x,
        y: entity.y,
        timestamp: DateTime.now(),
      );
      _recentEvents.insert(0, localEvent);
      if (_recentEvents.length > 50) _recentEvents.removeLast();
      notifyListeners();
      return true;
    } catch (e) {
      // 回滚乐观更新
      _inventory = previousInventory;
      _lastActionError = e.toString();
      _lastActionIsCooldown = false;
      notifyListeners();
      return false;
    }
  }

  /// 签到领取每日道具。
  Future<bool> claimItems() async {
    try {
      final ok = await LifeService.claimLifeItems();
      if (ok) {
        // 重新拉取背包
        await fetchInventory();
      }
      return ok;
    } catch (e) {
      debugPrint('claimItems error: $e');
      _lastActionError = e.toString();
      _lastActionIsCooldown = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _wsService.dispose();
    super.dispose();
  }
}
