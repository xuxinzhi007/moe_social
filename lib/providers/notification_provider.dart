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
  int _activityUnreadCount = 0;
  Map<String, int> _unreadDmBySender = {};
  bool _isLoading = false;
  Timer? _pollingTimer;
  bool _pushListening = false;
  bool _lifecycleListening = false;
  bool _isRefreshingUnread = false;
  DateTime? _lastResumeSyncAt;

  List<NotificationItem> get notifications => _notifications;
  List<NotificationItem> get activityNotifications => _notifications
      .where((n) => n.type != NotificationModel.directMessage)
      .toList(growable: false);
  int get unreadCount => _unreadCount;
  int get activityUnreadCount => _activityUnreadCount;
  Map<String, int> get unreadDmBySender => _unreadDmBySender;
  int get directMessageUnreadCount =>
      _unreadDmBySender.values.fold<int>(0, (sum, value) => sum + value);
  bool get isLoading => _isLoading;

  void init() {
    if (!AuthService.isLoggedIn) return;

    NotificationService.onRealtimeRefresh = refreshUnreadState;
    refreshUnreadState();

    if (!_pushListening) {
      _pushListening = true;
      ChatPushService.start();
      ChatPushService.ping();
      ChatPushService.unreadBySender.addListener(_onPushUnreadUpdated);
    }

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
      final now = DateTime.now();
      if (_lastResumeSyncAt != null &&
          now.difference(_lastResumeSyncAt!).inSeconds < 3) {
        return;
      }
      _lastResumeSyncAt = now;
      ChatPushService.start();
      PresenceService.start();
      refreshUnreadState();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (kIsWeb) return;
      ChatPushService.stop();
      PresenceService.stop();
    }
  }

  void _onPushUnreadUpdated() {
    final nextDmBySender = _mergeDmUnreadBySender(_notifications);
    final nextDmUnread =
        nextDmBySender.values.fold<int>(0, (sum, v) => sum + v);
    final nextUnreadTotal = _activityUnreadCount + nextDmUnread;
    final changed = !_mapEquals(_unreadDmBySender, nextDmBySender) ||
        _unreadCount != nextUnreadTotal;
    _unreadDmBySender = nextDmBySender;
    _unreadCount = nextUnreadTotal;
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> refreshUnreadState() async {
    if (_isRefreshingUnread || !AuthService.isLoggedIn) return;
    _isRefreshingUnread = true;
    try {
      final list =
          await NotificationService.getNotifications(page: 1, pageSize: 100);
      _applyNotifications(list, replaceList: false);
    } catch (e) {
      debugPrint('Failed to refresh unread state: $e');
    } finally {
      _isRefreshingUnread = false;
    }
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final list =
          await NotificationService.getNotifications(page: 1, pageSize: 100);
      _applyNotifications(list, replaceList: true);
    } catch (e) {
      debugPrint('Failed to fetch notifications: $e');
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> markDirectMessagesAsRead(String senderId) async {
    if (senderId.isEmpty || !AuthService.isLoggedIn) return;

    if (_unreadDmBySender.containsKey(senderId)) {
      final nextDm = Map<String, int>.from(_unreadDmBySender)..remove(senderId);
      _unreadDmBySender = nextDm;
      _unreadCount = _activityUnreadCount +
          nextDm.values.fold<int>(0, (sum, v) => sum + v);
      notifyListeners();
    }

    const pageSize = 50;
    const maxPages = 5;
    try {
      for (var page = 1; page <= maxPages; page++) {
        final list = await NotificationService.getNotifications(
          page: page,
          pageSize: pageSize,
        );
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
          break;
        }
      }
    } catch (e) {
      debugPrint('Failed to mark direct messages as read: $e');
    } finally {
      await refreshUnreadState();
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;

    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index < 0 || _notifications[index].isRead) return;

    final target = _notifications[index];
    final next = List<NotificationItem>.from(_notifications);
    next[index] = target.copyWith(isRead: true);
    _applyNotifications(next, replaceList: true);

    final ok = await NotificationService.markAsRead(notificationId);
    if (!ok) {
      next[index] = target;
      _applyNotifications(next, replaceList: true);
    }
  }

  Future<void> markAllActivityAsRead() async {
    final targets = _notifications
        .where((n) => !n.isRead && n.type != NotificationModel.directMessage)
        .toList(growable: false);
    if (targets.isEmpty) return;

    final next = _notifications
        .map(
          (n) => n.type == NotificationModel.directMessage
              ? n
              : n.copyWith(isRead: true),
        )
        .toList(growable: false);
    _applyNotifications(next, replaceList: true);

    var shouldRefresh = false;
    for (final notification in targets) {
      final ok = await NotificationService.markAsRead(notification.id);
      if (!ok) {
        shouldRefresh = true;
      }
    }

    if (shouldRefresh) {
      await fetchNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    final next = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _applyNotifications(next, replaceList: true);

    final ok = await NotificationService.markAllAsRead();
    if (!ok) {
      await fetchNotifications();
    }
  }

  Future<void> clearAllNotifications() async {
    final previous = List<NotificationItem>.from(_notifications);
    _notifications = [];
    _unreadCount = 0;
    _activityUnreadCount = 0;
    _unreadDmBySender = {};
    notifyListeners();

    final ok = await NotificationService.clearAllNotifications();
    if (!ok) {
      _applyNotifications(previous, replaceList: true);
    }
  }

  void dismissNotification(String notificationId) {
    if (notificationId.isEmpty) return;
    final next = _notifications.where((n) => n.id != notificationId).toList();
    _applyNotifications(next, replaceList: true);
  }

  void _applyNotifications(
    List<NotificationItem> list, {
    required bool replaceList,
  }) {
    final activityUnread = list.where((n) {
      return !n.isRead && n.type != NotificationModel.directMessage;
    }).length;
    final dmUnread = _mergeDmUnreadBySender(list);
    final unreadTotal = activityUnread +
        dmUnread.values.fold<int>(0, (sum, value) => sum + value);
    final changed =
        (replaceList && !_sameNotificationList(_notifications, list)) ||
            !_mapEquals(_unreadDmBySender, dmUnread) ||
            _unreadCount != unreadTotal ||
            _activityUnreadCount != activityUnread;

    if (!changed) return;

    if (replaceList) {
      _notifications = list;
    }
    _unreadDmBySender = dmUnread;
    _activityUnreadCount = activityUnread;
    _unreadCount = unreadTotal;
    notifyListeners();
  }

  Map<String, int> _mergeDmUnreadBySender(List<NotificationItem> list) {
    final notifDmUnread = <String, int>{};
    for (final n in list) {
      if (n.isRead || n.type != NotificationModel.directMessage) {
        continue;
      }
      final senderId = (n.senderId ?? '').trim();
      if (senderId.isEmpty) continue;
      notifDmUnread[senderId] = (notifDmUnread[senderId] ?? 0) + 1;
    }

    final merged = Map<String, int>.from(notifDmUnread);
    final pushUnread = ChatPushService.unreadBySender.value;
    for (final entry in pushUnread.entries) {
      if (entry.value <= 0) continue;
      merged[entry.key] = entry.value;
    }
    return merged;
  }

  bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool _sameNotificationList(
      List<NotificationItem> a, List<NotificationItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.isRead != y.isRead ||
          x.type != y.type ||
          x.content != y.content ||
          x.senderId != y.senderId ||
          x.postId != y.postId) {
        return false;
      }
    }
    return true;
  }
}
