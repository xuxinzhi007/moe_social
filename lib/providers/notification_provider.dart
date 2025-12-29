import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';
import '../auth_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollingTimer;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  // 初始化：启动轮询
  void init() {
    if (!AuthService.isLoggedIn) return;
    
    _fetchUnreadCount();
    // 每 30 秒轮询一次未读数
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (AuthService.isLoggedIn) {
        _fetchUnreadCount();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // 获取未读数
  Future<void> _fetchUnreadCount() async {
    try {
      final count = await NotificationService.getUnreadCount();
      if (_unreadCount != count) {
        _unreadCount = count;
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
      // 更新未读数（如果列表里全读了，理论上后端会更新，这里再拉一次）
      _fetchUnreadCount();
    } catch (e) {
      print('Failed to fetch notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
}

