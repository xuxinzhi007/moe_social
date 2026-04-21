import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notification.dart';
import '../auth_service.dart';
import 'api_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localInitialized = false;

  static Future<void> initLocalNotifications() async {
    if (kIsWeb || _localInitialized) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(initSettings);
    _localInitialized = true;
  }

  static Future<void> showPrivateMessageNotification({
    required String senderName,
    required String messagePreview,
    required int unreadCount,
  }) async {
    if (kIsWeb) {
      return;
    }

    if (!_localInitialized) {
      await initLocalNotifications();
    }

    // 新 channel id：已装过旧版的用户会拿到带自定义铃声的新通道（Android 8+ 通道属性不可变）
    const androidDetails = AndroidNotificationDetails(
      'direct_message_channel_v2',
      '私信消息',
      channelDescription: '私信消息通知',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('moe_notify'),
    );
    // iOS 自定义 wav 需加入 Xcode Runner 资源；此处先保证系统提示音可靠触发
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final title = '$senderName 给你发来了私信';
    final body = unreadCount > 1 ? '你有 $unreadCount 条未读私信' : messagePreview;

    await _localNotifications.show(
      0,
      title,
      body,
      details,
    );
  }

  // 获取通知列表
  static Future<List<NotificationModel>> getNotifications(
      {int page = 1, int pageSize = 20}) async {
    final userId = AuthService.currentUser;
    if (userId == null) return [];

    try {
      final response = await ApiService.get(
          '/api/notifications?user_id=$userId&page=$page&page_size=$pageSize');
      if (response['code'] == 200) {
        final data = response['data'];
        if (data is List) {
          return data.map((e) => NotificationModel.fromJson(e)).toList();
        }
        // API returns data as a list in this project; keep defensive fallback.
        return [];
      }
      return [];
    } catch (e) {
      print('Notification API Error: $e');
      // 如果API失败，返回空列表，或者模拟数据（为了演示）
      return _getMockNotifications();
    }
  }

  // 获取未读数
  static Future<int> getUnreadCount() async {
    final userId = AuthService.currentUser;
    if (userId == null) return 0;

    try {
      final response =
          await ApiService.get('/api/notifications/unread?user_id=$userId');
      if (response['code'] == 200) {
        return response['data'] as int;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // 标记所有已读
  static Future<bool> markAllAsRead() async {
    final userId = AuthService.currentUser;
    if (userId == null) return false;

    try {
      await ApiService.post('/api/notifications/read-all',
          body: {'user_id': userId});
      return true;
    } catch (e) {
      return false;
    }
  }

  // 标记单个已读
  static Future<bool> markAsRead(String id) async {
    final userId = AuthService.currentUser;
    if (userId == null) return false;

    try {
      await ApiService.post('/api/notifications/$id/read',
          body: {'user_id': userId});
      return true;
    } catch (e) {
      return false;
    }
  }

  // 清除所有通知
  static Future<bool> clearAllNotifications() async {
    final userId = AuthService.currentUser;
    if (userId == null) return false;

    try {
      await ApiService.post('/api/notifications/clear-all',
          body: {'user_id': userId});
      return true;
    } catch (e) {
      return false;
    }
  }

  // 模拟数据 (Fallback)
  static List<NotificationModel> _getMockNotifications() {
    return [
      NotificationModel(
        id: '1',
        type: 2, // Comment
        content: '你的想法很有趣！',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        senderName: 'Moe User',
        senderAvatar: 'https://api.dicebear.com/7.x/avataaars/png?seed=Moe',
        postId: 'post_1',
      ),
      NotificationModel(
        id: '2',
        type: 4, // System
        content: '欢迎来到 Moe Social！',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        senderName: 'System',
      ),
    ];
  }
}
