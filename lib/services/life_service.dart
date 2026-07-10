import 'api_service.dart';
import '../models/life_state.dart';

export 'api_service.dart' show ApiException, LifeActionCooldownException;

class LifeInitialState {
  final String worldId;
  final int tick;
  final LifeWorldSummary summary;
  final List<LifeEntity> entities;
  final List<LifeRelationship> relationships;
  final List<LifeEvent> events;

  const LifeInitialState({
    required this.worldId,
    required this.tick,
    required this.summary,
    this.entities = const [],
    this.relationships = const [],
    this.events = const [],
  });
}

/// 数字生命 REST 操作（WebSocket 仍由 [LifeWsService] 负责）。
class LifeService {
  static Future<Map<String, dynamic>> postLifeAction(
    String action,
    int entityId, [
    Map<String, dynamic>? params,
  ]) =>
      ApiService.postLifeAction(action, entityId, params);

  /// 获取道具定义列表。
  static Future<List<LifeItem>> getLifeItems() => ApiService.getLifeItems();

  /// 获取背包道具列表。
  static Future<List<LifeInventoryItem>> getLifeInventory() =>
      ApiService.getLifeInventory();

  /// 对指定实体使用道具。
  static Future<bool> useLifeItem(int entityId, int itemId) =>
      ApiService.useLifeItem(entityId, itemId);

  /// 签到领取每日道具。
  static Future<bool> claimLifeItems() => ApiService.claimLifeItems();

  static Future<LifeInitialState> getInitialState() async {
    final results = await Future.wait([
      ApiService.getLifeWorld(),
      ApiService.getLifeEntities(),
      ApiService.getLifeRelationships(),
      ApiService.getLifeEvents(),
    ]);

    final world = results[0] as Map<String, dynamic>;
    final entityMaps = results[1] as List<Map<String, dynamic>>;
    final relationships = results[2] as List<LifeRelationship>;
    final events = results[3] as List<LifeEvent>;

    return LifeInitialState(
      worldId: world['world_id']?.toString() ?? 'default',
      tick: world['tick'] is int
          ? world['tick'] as int
          : int.tryParse(world['tick']?.toString() ?? '') ?? 0,
      summary: world['summary'] is Map<String, dynamic>
          ? LifeWorldSummary.fromJson(world['summary'] as Map<String, dynamic>)
          : world['summary'] is Map
              ? LifeWorldSummary.fromJson(
                  Map<String, dynamic>.from(world['summary'] as Map),
                )
              : LifeWorldSummary.empty,
      entities: entityMaps.map(LifeEntity.fromJson).toList(),
      relationships: relationships,
      events: events,
    );
  }
}
