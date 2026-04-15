import 'package:shared_preferences/shared_preferences.dart';

/// 控制「未读通知摘要弹窗」展示频率，避免打扰。
class NotificationPopupPreferences {
  static const _kLastDismissedMs = 'notification_popup_last_dismiss_ms';

  /// 点「稍后」或「查看」后，一段时间内不再自动弹出。
  static const Duration cooldown = Duration(hours: 4);

  static Future<bool> canShowAutoPopup() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_kLastDismissedMs);
    if (ms == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(last) >= cooldown;
  }

  static Future<void> markDismissed() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastDismissedMs, DateTime.now().millisecondsSinceEpoch);
  }
}
