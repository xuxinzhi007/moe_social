import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/life_state.dart';
import '../services/life_cache_service.dart';
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
  List<LifeEntity> _entitiesList = const [];
  List<LifeEvent> _recentEvents = [];
  final List<LifeRelationship> _relationships = [];
  final List<WorldEventDiff> _worldEvents = [];
  int _tickCount = 0;
  bool _connected = false;
  bool _isInitialized = false;
  bool _isOfflineMode = false;

  /// 缓存写入 debounce Timer（30 秒）
  Timer? _cacheDebounceTimer;
  String _worldId = 'default';
  LifeWorldSummary _summary = LifeWorldSummary.empty;

  // 背包道具状态
  List<LifeInventoryItem> _inventory = [];
  List<LifeItem> _allItems = [];
  bool _inventoryLoading = false;
  bool _claimedToday = false;

  /// 最近一次操作失败的错误信息（null 表示无错误）。
  String? _lastActionError;

  /// 最近一次操作失败是否为冷却限制（区别于真正的错误）。
  bool _lastActionIsCooldown = false;

  LifeProvider() {
    _wsService.onStateUpdate = _onStateUpdate;
    _wsService.onConnected = () {
      if (_disposed) return;
      _connected = true;
      _isOfflineMode = false;
      notifyListeners();
    };
    _wsService.onDisconnected = () {
      if (_disposed) return;
      _connected = false;
      // 断连时进入离线模式，保留内存中现有数据
      _isOfflineMode = true;
      notifyListeners();
    };
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

  List<LifeEntity> get entities => _entitiesList;
  List<LifeEvent> get recentEvents => List.unmodifiable(_recentEvents);
  List<LifeRelationship> get relationships => List.unmodifiable(_relationships);
  List<WorldEventDiff> get worldEvents => List.unmodifiable(_worldEvents);
  int get tickCount => _tickCount;
  bool get connected => _connected;
  bool get isInitialized => _isInitialized;

  /// 是否处于离线降级模式（显示缓存数据）。
  bool get isOfflineMode => _isOfflineMode;
  String get worldId => _worldId;
  LifeWorldSummary get summary => _summary;

  /// 背包道具列表
  List<LifeInventoryItem> get inventory => List.unmodifiable(_inventory);

  /// 今日是否已签到领取背包补给
  bool get claimedToday => _claimedToday;

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

  /// 获取指定实体的最近事件（已按时间倒序）。
  List<LifeEvent> getEventsForEntity(int entityId) {
    return _recentEvents
        .where((e) => e.entityId == entityId)
        .toList()
        .reversed
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
      // 尝试从缓存恢复离线模式
      await _tryLoadOfflineCache();
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
    _entitiesList = List.unmodifiable(_entities.values);
    _isInitialized = true;
    notifyListeners();
  }

  /// 尝试从本地缓存加载离线数据。
  Future<void> _tryLoadOfflineCache() async {
    final cached = await LifeCacheService.loadState();
    if (cached == null || _disposed) return;

    _entities
      ..clear()
      ..addEntries(cached.entities.map((e) => MapEntry(e.id, e)));
    _entitiesList = List.unmodifiable(_entities.values);
    _tickCount = cached.tick;
    _summary = LifeWorldSummary.fromJson(cached.summary);
    _isOfflineMode = true;
    _isInitialized = true;
    notifyListeners();
    debugPrint('LifeProvider: 已从缓存加载离线数据，tick=${cached.tick}');
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

    _entitiesList = List.unmodifiable(_entities.values);
    _tickCount = update.tick;
    _worldId = update.worldId;
    _summary = update.summary;
    if (!_isInitialized) {
      _isInitialized = true;
    }
    notifyListeners();

    // debounce 缓存写入（30 秒内无新更新才写入）
    _cacheDebounceTimer?.cancel();
    _cacheDebounceTimer = Timer(const Duration(seconds: 30), () {
      if (!_disposed) {
        LifeCacheService.saveState(
          entities: _entitiesList,
          summary: _summary.toJson(),
          tick: _tickCount,
        );
      }
    });
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
    _entitiesList = List.unmodifiable(_entities.values);
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
      _entitiesList = List.unmodifiable(_entities.values);
      // 文案留给页面用角色气泡展示；此处仅保留标记与秒数语义。
      _lastActionError = 'care_cooldown:${e.retryAfter}';
      _lastActionIsCooldown = true;
      notifyListeners();
      return false;
    } catch (e) {
      // 回滚乐观更新
      _entities[entityId] = previousEntity;
      _entitiesList = List.unmodifiable(_entities.values);
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
        LifeService.getLifeClaimStatus(),
      ]);
      if (_disposed) return;
      _inventory = results[0] as List<LifeInventoryItem>;
      _allItems = results[1] as List<LifeItem>;
      final status = results[2] as ({bool claimedToday, String claimDate});
      _claimedToday = status.claimedToday;
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
    _entitiesList = List.unmodifiable(_entities.values);
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

  /// 签到领取每日道具。成功或「今日已领」都返回结果对象。
  Future<LifeClaimResult?> claimItems() async {
    try {
      final result = await LifeService.claimLifeItems();
      if (_disposed) return result;
      _claimedToday = result.claimedToday || result.alreadyClaimed;
      _lastActionError = null;
      notifyListeners();
      // 放行可能尚未结束的首屏加载，确保签到后背包能刷新。
      _inventoryLoading = false;
      await fetchInventory();
      return result;
    } catch (e) {
      debugPrint('claimItems error: $e');
      _lastActionError = e.toString().replaceFirst('Exception: ', '');
      _lastActionIsCooldown = false;
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cacheDebounceTimer?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}
