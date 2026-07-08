import 'package:flutter/material.dart';

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
    if (Overlay.maybeOf(ctx) == null) return;
    if (uniqueUnlocked.length == 1) {
      final b = uniqueUnlocked.first;
      final expNote = _expNoteForUnlocks(uniqueUnlocked);
      try {
        AchievementNotificationManager.showUnlockNotification(
          ctx,
          b,
          onView: _openAchievementsCenter,
        );
      } catch (_) {}
      MoeToast.success(ctx, '解锁成就「${b.name}」$expNote');
      return;
    }
    final names = uniqueUnlocked.take(3).map((b) => b.name).join('、');
    final more = uniqueUnlocked.length > 3 ? '…' : '';
    final expNote = _expNoteForUnlocks(uniqueUnlocked);
    try {
      AchievementNotificationManager.showUnlockNotification(
        ctx,
        uniqueUnlocked.first,
        onView: _openAchievementsCenter,
      );
    } catch (_) {}
    try {
      AchievementNotificationManager.showBottomGuideSheet(
        ctx,
        unlockedCount: uniqueUnlocked.length,
        onViewAchievements: _openAchievementsCenter,
      );
    } catch (_) {}
    MoeToast.success(
        ctx, '解锁 ${uniqueUnlocked.length} 个成就：$names$more$expNote');
  }

  static String _expNoteForUnlocks(List<AchievementBadge> badges) {
    return '';
  }

  /// 延后展示成就（下一帧 + 短延迟），避免与 AlertDialog / BottomSheet / 页面转场抢 Navigator。
  static void scheduleServerUnlocks(
    String userId,
    List<AchievementUnlock> unlocks,
  ) {
    if (userId.isEmpty || unlocks.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 320));
      final ctx = AuthService.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted && !_routeAllowsAchievementUi(ctx)) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
      await handleServerUnlocks(userId, unlocks);
    });
  }

  static bool _routeAllowsAchievementUi(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null) return false;
    return route.isCurrent;
  }

  /// 处理业务接口返回的解锁列表（含经验提示）。失败不向外抛，避免影响支付/发帖主流程。
  static Future<void> handleServerUnlocks(
    String userId,
    List<AchievementUnlock> unlocks,
  ) async {
    if (userId.isEmpty || unlocks.isEmpty) return;
    try {
      try {
        await _svc.refreshFromServer(userId);
      } catch (e) {
        debugPrint('成就缓存刷新失败（忽略）: $e');
      }
      final badges = unlocks.map((u) => u.toDisplayBadge()).toList();
      final ctx = AuthService.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        final totalExp = unlocks.fold<int>(0, (sum, u) => sum + u.expGranted);
        if (totalExp > 0) {
          try {
            MoeToast.success(ctx, '获得 $totalExp 经验');
          } catch (_) {}
        }
      }
      if (ctx != null && ctx.mounted && _routeAllowsAchievementUi(ctx)) {
        _toastUnlocks(badges);
      }
    } catch (e, st) {
      debugPrint('成就解锁展示失败（忽略）: $e\n$st');
    }
  }
}
