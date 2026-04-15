import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../providers/notification_provider.dart';
import '../services/notification_popup_preferences.dart';
import 'moe_notification_popup.dart';

/// 在 [MaterialApp] 的 `builder` 内包裹子树，于有未读且通过冷却策略时弹出统一提示。
class NotificationPopupHost extends StatefulWidget {
  const NotificationPopupHost({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationPopupHost> createState() => _NotificationPopupHostState();
}

class _NotificationPopupHostState extends State<NotificationPopupHost>
    with WidgetsBindingObserver {
  static bool _dialogOpen = false;
  DateTime? _lastTryAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryShow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryShow());
    }
  }

  Future<void> _tryShow() async {
    if (_dialogOpen) return;
    if (!mounted) return;
    if (!AuthService.isLoggedIn) return;

    final now = DateTime.now();
    if (_lastTryAt != null && now.difference(_lastTryAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastTryAt = now;

    final unread = context.read<NotificationProvider>().unreadCount;
    if (unread <= 0) return;
    if (!await NotificationPopupPreferences.canShowAutoPopup()) return;
    if (!mounted) return;

    _dialogOpen = true;
    try {
      await showMoeNotificationPopup(
        context: context,
        unreadCount: unread,
        onView: () async {
          await NotificationPopupPreferences.markDismissed();
          final navCtx = AuthService.navigatorKey.currentContext;
          if (navCtx != null && navCtx.mounted) {
            Navigator.of(navCtx).pushNamed('/notifications');
          }
        },
        onLater: () async {
          await NotificationPopupPreferences.markDismissed();
        },
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread =
        context.select<NotificationProvider, int>((p) => p.unreadCount);
    if (unread > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryShow());
    }
    return widget.child;
  }
}
