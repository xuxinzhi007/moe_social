import '../auth_service.dart';
import '../models/achievement_badge.dart';
import '../widgets/moe_toast.dart';
import 'achievement_service.dart';

/// 将成就系统接入业务入口（登录拉取云端；操作后用接口返回的解锁 id 提示）。
class AchievementHooks {
  AchievementHooks._();

  static final AchievementService _svc = AchievementService();

  static Future<void> ensureReady(String userId) async {
    if (userId.isEmpty) return;
    await _svc.initializeUserBadges(userId);
  }

  static void _toastUnlocks(List<AchievementBadge> unlocked) {
    if (unlocked.isEmpty) return;
    final ctx = AuthService.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    if (unlocked.length == 1) {
      final b = unlocked.first;
      MoeToast.success(ctx, '解锁成就「${b.name}」');
      return;
    }
    final names = unlocked.take(3).map((b) => b.name).join('、');
    final more = unlocked.length > 3 ? '…' : '';
    MoeToast.success(ctx, '解锁 ${unlocked.length} 个成就：$names$more');
  }

  static Future<void> onServerNewUnlocks(
    String userId,
    List<String> badgeIds,
  ) async {
    if (userId.isEmpty || badgeIds.isEmpty) return;
    await _svc.applyServerNewUnlocks(userId, badgeIds);
    final badges = badgeIds
        .map(AchievementBadge.findById)
        .whereType<AchievementBadge>()
        .map((b) => b.copyWith(isUnlocked: true))
        .toList();
    _toastUnlocks(badges);
  }

  /// 礼物、话题等仍仅本地推进时调用
  static Future<void> triggerLocal(
    String userId,
    AchievementAction action, {
    Map<String, dynamic>? params,
  }) async {
    if (userId.isEmpty) return;
    final list =
        await _svc.triggerAction(userId, action, params: params);
    _toastUnlocks(list);
  }
}
