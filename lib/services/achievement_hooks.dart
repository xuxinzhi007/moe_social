import '../auth_service.dart';
import '../models/achievement_badge.dart';
import '../widgets/moe_toast.dart';
import 'achievement_service.dart';

/// 将成就系统接入业务入口（登录、发帖、评论、签到、VIP）。
class AchievementHooks {
  AchievementHooks._();

  static final AchievementService _svc = AchievementService();

  /// 从本地恢复进度表（冷启动、登录成功后调用）。
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
      MoeToast.success(ctx, '解锁成就 ${b.emoji} ${b.name}');
      return;
    }
    final preview = unlocked.take(4).map((b) => b.emoji).join(' ');
    MoeToast.success(ctx, '解锁 ${unlocked.length} 个成就 $preview');
  }

  /// 发布动态成功后调用（含图片张数、正文字数）。
  static Future<void> recordPostPublished(
    String userId, {
    required int imageCount,
    required int contentLength,
  }) async {
    if (userId.isEmpty) return;
    final merged = <AchievementBadge>[];
    merged.addAll(
      await _svc.triggerAction(
        userId,
        AchievementAction.postCreated,
        params: {
          'hasImages': imageCount > 0,
          'imageCount': imageCount,
          'contentLength': contentLength,
        },
      ),
    );
    final h = DateTime.now().hour;
    if (h < 8) {
      merged.addAll(
        await _svc.triggerAction(userId, AchievementAction.earlyPost),
      );
    }
    if (h >= 23) {
      merged.addAll(
        await _svc.triggerAction(userId, AchievementAction.latePost),
      );
    }
    _toastUnlocks(merged);
  }

  static Future<void> recordComment(String userId) async {
    if (userId.isEmpty) return;
    final list = await _svc.triggerAction(
      userId,
      AchievementAction.commentCreated,
    );
    _toastUnlocks(list);
  }

  /// 与「忠实用户」等每日行为挂钩（在签到成功时调用）。
  static Future<void> recordDailyEngagement(String userId) async {
    if (userId.isEmpty) return;
    final list = await _svc.triggerAction(
      userId,
      AchievementAction.loginDaily,
    );
    _toastUnlocks(list);
  }

  static Future<void> recordVipPurchased(String userId) async {
    if (userId.isEmpty) return;
    final list = await _svc.triggerAction(
      userId,
      AchievementAction.vipPurchased,
    );
    _toastUnlocks(list);
  }
}
