import 'api_service.dart';
import '../models/life_state.dart';

export 'api_service.dart' show ApiException, LifeActionCooldownException;

class LifeClaimResult {
  final bool success;
  final bool alreadyClaimed;
  final bool claimedToday;
  final String message;
  final List<LifeInventoryItem> items;
  final int count;

  const LifeClaimResult({
    required this.success,
    required this.alreadyClaimed,
    required this.claimedToday,
    required this.message,
    this.items = const [],
    this.count = 0,
  });
}

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

  /// 背包每日签到状态。
  static Future<({bool claimedToday, String claimDate})>
      getLifeClaimStatus() async {
    final raw = await ApiService.getLifeClaimStatus();
    return (
      claimedToday: raw['claimed_today'] == true,
      claimDate: raw['claim_date']?.toString() ?? '',
    );
  }

  /// 签到领取每日道具。
  static Future<LifeClaimResult> claimLifeItems() async {
    final raw = await ApiService.claimLifeItems();
    if (raw['error'] != null) {
      throw Exception(raw['error'].toString());
    }
    final itemsRaw = raw['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map(
                (e) => LifeInventoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <LifeInventoryItem>[];
    return LifeClaimResult(
      success: raw['success'] != false,
      alreadyClaimed: raw['already_claimed'] == true,
      claimedToday: raw['claimed_today'] == true,
      message: raw['message']?.toString() ?? '',
      items: items,
      count: (raw['count'] as num?)?.toInt() ?? items.length,
    );
  }

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
