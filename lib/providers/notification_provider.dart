import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/notification_service.dart';
import '../models/notification.dart';
import '../auth_service.dart';
import '../services/chat_push_service.dart';
import '../services/presence_service.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  Map<String, int> _unreadDmBySender = {};
  bool _isLoading = false;
  Timer? _pollingTimer;
  bool _pushListening = false;
  bool _lifecycleListening = false;
  DateTime? _lastResumeSyncAt;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  Map<String, int> get unreadDmBySender => _unreadDmBySender;
  bool get isLoading => _isLoading;

  // 初始化：启动轮询
  void init() {
    if (!AuthService.isLoggedIn) return;

    // One-time sync at startup
    _refreshUnreadState();

    // Prefer push-based unread updates via /ws/chat
    if (!_pushListening) {
      _pushListening = true;
      ChatPushService.start();
      ChatPushService.ping();
      ChatPushService.unreadBySender.addListener(_onPushUnreadUpdated);
    }

    // Presence websocket keeps our online status when app is open.
    PresenceService.start();

    if (!_lifecycleListening) {
      _lifecycleListening = true;
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    if (_pushListening) {
      ChatPushService.unreadBySender.removeListener(_onPushUnreadUpdated);
    }
    if (_lifecycleListening) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AuthService.isLoggedIn) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      // When resuming, websocket may have been disconnected and messages could have arrived.
      // Do a lightweight one-time sync to align unread state.
      final now = DateTime.now();
      if (_lastResumeSyncAt != null &&
          now.difference(_lastResumeSyncAt!).inSeconds < 3) {
        return;
      }
      _lastResumeSyncAt = now;
      ChatPushService.start();
      PresenceService.start();
      _refreshUnreadState();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Web 端很容易在切换路由/弹窗/页面可见性变化时触发 inactive，
      // 如果在这里 stop 会导致“切个页面就离线/掉消息”。
      // 移动端如需省电，可在后续按平台/配置再做更细分策略。
      if (kIsWeb) return;
      ChatPushService.stop();
      PresenceService.stop();
    }
  }

  void _onPushUnreadUpdated() {
    // Only handle direct messages (comment/like not implemented for now)
    final next = ChatPushService.unreadBySender.value;
    _unreadDmBySender = next;
    _unreadCount = next.values.fold<int>(0, (sum, v) => sum + v);
    notifyListeners();
  }

  // 刷新未读数 + 私信分组未读
  Future<void> _refreshUnreadState() async {
    try {
      // Only sync direct-message unread (comment/like not implemented for now)
      final list =
          await NotificationService.getNotifications(page: 1, pageSize: 50);
      final dmUnread = <String, int>{};
      for (final n in list) {
        if (n.type != NotificationModel.directMessage || n.isRead) continue;
        final senderId = n.senderId;
        if (senderId == null || senderId.isEmpty) continue;
        dmUnread[senderId] = (dmUnread[senderId] ?? 0) + 1;
      }

      final changed = !_mapEquals(_unreadDmBySender, dmUnread);
      _unreadDmBySender = dmUnread;
      _unreadCount = dmUnread.values.fold<int>(0, (sum, v) => sum + v);
      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      print('Failed to fetch unread count: $e');
    }
  }

  // 获取通知列表
  Future<void> fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final list = await NotificationService.getNotifications(page: 1);
      _notifications = list;
      // 暂时仅实现私信未读，通知列表本身仍可展示
      _refreshUnreadState();
    } catch (e) {
      print('Failed to fetch notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 标记与某个发送者相关的私信通知为已读
  Future<void> markDirectMessagesAsRead(String senderId) async {
    if (senderId.isEmpty) return;
    if (!AuthService.isLoggedIn) return;

    // 只扫前几页，避免请求过多；通常未读私信都在最新页
    const pageSize = 50;
    const maxPages = 5;
    try {
      for (var page = 1; page <= maxPages; page++) {
        final list = await NotificationService.getNotifications(
            page: page, pageSize: pageSize);
        if (list.isEmpty) {
          break;
        }
        final targets = list.where((n) {
          return n.type == NotificationModel.directMessage &&
              !n.isRead &&
              (n.senderId ?? '') == senderId;
        });
        var foundAny = false;
        for (final n in targets) {
          foundAny = true;
          await NotificationService.markAsRead(n.id);
        }
        if (!foundAny) {
          // 如果这一页没有未读私信，基本说明已清完（列表是按时间倒序）
          break;
        }
      }
    } catch (e) {
      print('Failed to mark direct messages as read: $e');
    } finally {
      await _refreshUnreadState();
    }
  }

  // 标记所有已读
  Future<void> markAllAsRead() async {
    try {
      // 乐观更新 UI
      _unreadCount = 0;
      for (var n in _notifications) {
        n.isRead = true;
      }
      notifyListeners();

      await NotificationService.markAllAsRead();
    } catch (e) {
      // 回滚？通常不需要，只要下次轮询纠正即可
      print('Failed to mark all as read: $e');
    }
  }

  bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
