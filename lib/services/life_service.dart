import 'api_service.dart';

export 'api_service.dart' show ApiException, LifeActionCooldownException;

/// 数字生命 REST 操作（WebSocket 仍由 [LifeWsService] 负责）。
class LifeService {
  static Future<Map<String, dynamic>> postLifeAction(
    String action,
    int entityId, [
    Map<String, dynamic>? params,
  ]) =>
      ApiService.postLifeAction(action, entityId, params);
}
