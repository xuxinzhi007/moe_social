import '../models/achievement_unlock.dart';
import '../models/user.dart';
import '../models/vip_order.dart';
import '../models/vip_plan.dart';
import '../models/vip_record.dart';
import 'api_service.dart';
import 'user_service.dart';

class CommerceService {
  static Future<List<VipPlan>> getVipPlans() => ApiService.getVipPlans();

  static Future<Map<String, dynamic>> getUserVipStatus(String userId) =>
      ApiService.getUserVipStatus(userId);

  static Future<VipRecord> getUserActiveVipRecord(String userId) =>
      ApiService.getUserActiveVipRecord(userId);

  static Future<void> updateAutoRenew(String userId, bool autoRenew) =>
      ApiService.updateAutoRenew(userId, autoRenew);

  static Future<({VipOrder order, List<AchievementUnlock> newAchievements})>
      createVipOrderWithUnlocks(String userId, String planId) =>
          ApiService.createVipOrderWithUnlocks(userId, planId);

  static Future<Map<String, dynamic>> syncUserVipStatus(String userId) =>
      ApiService.syncUserVipStatus(userId);

  static Future<Map<String, dynamic>> getVipOrders(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) =>
      ApiService.getVipOrders(userId, page: page, pageSize: pageSize);

  static Future<Map<String, dynamic>> getVipHistory(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) =>
      ApiService.getVipHistory(userId, page: page, pageSize: pageSize);

  static Future<Map<String, dynamic>> getGiftPurchaseOrders(
    String userId, {
    int page = 1,
    int pageSize = 20,
  }) =>
      ApiService.getGiftPurchaseOrders(userId, page: page, pageSize: pageSize);

  static Future<Map<String, dynamic>> getTransactions(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) =>
      ApiService.getTransactions(userId, page: page, pageSize: pageSize);

  static Future<Map<String, dynamic>> recharge(
    String userId,
    double amount,
    String description,
  ) =>
      ApiService.recharge(userId, amount, description);

  static Future<User> getUserInfo(String userId) =>
      UserService.getUserInfo(userId);
}
