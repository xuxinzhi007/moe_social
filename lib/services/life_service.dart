import 'api_service.dart';
import '../models/life_state.dart';

export 'api_service.dart' show ApiException, LifeActionCooldownException;

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
}
