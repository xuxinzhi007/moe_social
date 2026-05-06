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
      final code = response['code'];
      final ok = code == 200 || code == 0 || response['success'] == true;
      if (ok) {
        final data = response['data'];
        if (data is List) {
          final out = <NotificationModel>[];
          for (final e in data) {
            if (e is! Map<String, dynamic>) continue;
            try {
              out.add(NotificationModel.fromJson(e));
            } catch (_) {
              // 单条解析失败时跳过，避免整页空白
            }
          }
          return out;
        }
        return [];
      }
      return [];
    } catch (e) {
      debugPrint('Notification API Error: $e');
      return [];
    }
  }

  // 获取未读数
  static Future<int> getUnreadCount() async {
    final userId = AuthService.currentUser;
    if (userId == null) return 0;

    try {
      final response =
          await ApiService.get('/api/notifications/unread?user_id=$userId');
      final code = response['code'];
      final ok = code == 200 || code == 0 || response['success'] == true;
      if (ok) {
        final d = response['data'];
        if (d is int) return d;
        if (d is num) return d.toInt();
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

}
