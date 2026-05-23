import '../auth_service.dart';
import '../models/achievement_badge.dart';
import '../models/achievement_unlock.dart';
import '../widgets/moe_toast.dart';
import '../widgets/achievement/achievement_unlock_notification.dart';
import 'achievement_service.dart';

/// 成就系统 UI 钩子（进度由服务端维护）。
class AchievementHooks {
  AchievementHooks._();

  static final AchievementService _svc = AchievementService();

  static Future<void> ensureReady(String userId) async {
    if (userId.isEmpty) return;
    await _svc.initializeUserBadges(userId);
  }

  static void _openAchievementsCenter() {
    AuthService.navigatorKey.currentState?.pushNamed('/achievements');
  }

  static void _toastUnlocks(List<AchievementBadge> unlocked) {
    if (unlocked.isEmpty) return;
    final seenIds = <String>{};
    final uniqueUnlocked = unlocked
        .where((badge) => seenIds.add(badge.id))
        .toList(growable: false);
    final ctx = AuthService.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    if (uniqueUnlocked.length == 1) {
      final b = uniqueUnlocked.first;
      final expNote = _expNoteForUnlocks(uniqueUnlocked);
      AchievementNotificationManager.showUnlockNotification(
        ctx,
        b,
        onView: _openAchievementsCenter,
      );
      MoeToast.success(ctx, '解锁成就「${b.name}」$expNote');
      return;
    }
    final names = uniqueUnlocked.take(3).map((b) => b.name).join('、');
    final more = uniqueUnlocked.length > 3 ? '…' : '';
    final expNote = _expNoteForUnlocks(uniqueUnlocked);
    AchievementNotificationManager.showUnlockNotification(
      ctx,
      uniqueUnlocked.first,
      onView: _openAchievementsCenter,
    );
    AchievementNotificationManager.showBottomGuideSheet(
      ctx,
      unlockedCount: uniqueUnlocked.length,
      onViewAchievements: _openAchievementsCenter,
    );
    MoeToast.success(ctx, '解锁 ${uniqueUnlocked.length} 个成就：$names$more$expNote');
  }

  static String _expNoteForUnlocks(List<AchievementBadge> badges) {
    return '';
  }

  /// 处理业务接口返回的解锁列表（含经验提示）。
  static Future<void> handleServerUnlocks(
    String userId,
    List<AchievementUnlock> unlocks,
  ) async {
    if (userId.isEmpty || unlocks.isEmpty) return;
    await _svc.refreshFromServer(userId);
    final badges = unlocks.map((u) => u.toDisplayBadge()).toList();
    final ctx = AuthService.navigatorKey.currentContext;
    if (ctx != null && ctx.mounted && unlocks.isNotEmpty) {
      final totalExp =
          unlocks.fold<int>(0, (sum, u) => sum + u.expGranted);
      if (totalExp > 0) {
        MoeToast.success(ctx, '获得 $totalExp 经验');
      }
    }
    _toastUnlocks(badges);
  }
}
