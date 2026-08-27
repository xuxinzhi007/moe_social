import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../auth_service.dart';
import '../models/notification.dart';
import 'api_service.dart';
import 'api_response.dart';
import 'companion_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localInitialized = false;
  static String? _pendingCompanionNotificationPayload;
  static String? _pendingDmSenderId;
  static String? _pendingDmSenderName;
  static Timer? _pendingNotificationTimer;
  static int _pendingNotificationAttempts = 0;

  /// WS 推送公告/系统通知时触发，供 [NotificationProvider] 刷新未读。
  static VoidCallback? onRealtimeRefresh;

  static const _dmChannelId = 'direct_message_channel_v2';

  static int _dmNotificationId(String senderId) =>
      senderId.hashCode & 0x7fffffff;

  static Future<void> initLocalNotifications() async {
    if (kIsWeb || _localInitialized) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _dmChannelId,
        '私信消息',
        description: '私信消息通知',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('moe_notify'),
      ),
    );

    _localInitialized = true;
  }

  static void _handleLocalNotificationResponse(
    NotificationResponse response,
  ) {
    final payload = response.payload?.trim() ?? '';
    if (payload.isEmpty) return;
    if (payload.startsWith('dm:')) {
      _pendingDmSenderId = payload.substring(3).trim();
      _pendingDmSenderName = null;
      _flushPendingDmNotification();
      return;
    }
    if (!payload.startsWith('companion')) return;
    _pendingCompanionNotificationPayload = payload;
    _flushPendingCompanionNotification();
  }

  static void _flushPendingDmNotification() {
    _pendingNotificationTimer?.cancel();
    _pendingNotificationTimer = null;
    final navigator = AuthService.navigatorKey.currentState;
    if (navigator == null) {
      if (_pendingNotificationAttempts++ >= 20) {
        _pendingDmSenderId = null;
        _pendingDmSenderName = null;
        _pendingNotificationAttempts = 0;
        return;
      }
      _pendingNotificationTimer = Timer(
        const Duration(milliseconds: 200),
        _flushPendingDmNotification,
      );
      return;
    }

    final senderId = _pendingDmSenderId?.trim() ?? '';
    final senderName = (_pendingDmSenderName?.trim().isNotEmpty == true)
        ? _pendingDmSenderName!.trim()
        : '用户';
    _pendingDmSenderId = null;
    _pendingDmSenderName = null;
    _pendingNotificationAttempts = 0;
    if (senderId.isEmpty) return;

    navigator.pushNamed(
      '/direct-chat',
      arguments: <String, dynamic>{
        'userId': senderId,
        'username': senderName,
        'avatar': '',
      },
    );
  }

  static void _flushPendingCompanionNotification() {
    _pendingNotificationTimer?.cancel();
    _pendingNotificationTimer = null;
    final navigator = AuthService.navigatorKey.currentState;
    if (navigator == null) {
      if (_pendingNotificationAttempts++ >= 20) {
        _pendingCompanionNotificationPayload = null;
        _pendingNotificationAttempts = 0;
        return;
      }
      _pendingNotificationTimer = Timer(
        const Duration(milliseconds: 200),
        _flushPendingCompanionNotification,
      );
      return;
    }

    final payload = _pendingCompanionNotificationPayload;
    _pendingCompanionNotificationPayload = null;
    _pendingNotificationAttempts = 0;
    navigator.pushNamed('/ai-chat');
    final notificationId = payload?.startsWith('companion:') == true
        ? payload!.substring('companion:'.length).trim()
        : '';
    if (notificationId.isNotEmpty) {
      unawaited(
        CompanionService().markProactiveRead(notificationId).catchError((_) {}),
      );
    }
  }

  static Future<void> showPrivateMessageNotification({
    required String senderId,
    required String senderName,
    required String messagePreview,
    required int unreadCount,
  }) async {
    if (kIsWeb || senderId.trim().isEmpty) {
      return;
    }

    if (!_localInitialized) {
      await initLocalNotifications();
    }

    const androidDetails = AndroidNotificationDetails(
      _dmChannelId,
      '私信消息',
      channelDescription: '私信消息通知',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('moe_notify'),
      category: AndroidNotificationCategory.message,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final name = senderName.trim().isEmpty ? '用户' : senderName.trim();
    final title = '$name 给你发来了私信';
    final preview = messagePreview.trim();
    final body = unreadCount > 1
        ? '你有 $unreadCount 条未读私信'
        : (preview.isEmpty ? '发来一条新消息' : preview);

    _pendingDmSenderName = name;
    await _localNotifications.show(
      _dmNotificationId(senderId),
      title,
      body,
      details,
      payload: 'dm:$senderId',
    );
  }

  /// 进入对应对话或已读后清除通知栏条目。
  static Future<void> cancelPrivateMessageNotification(String senderId) async {
    if (kIsWeb || senderId.trim().isEmpty || !_localInitialized) return;
    await _localNotifications.cancel(_dmNotificationId(senderId));
  }

  static Future<void> showCompanionProactiveNotification({
    required String message,
    String reason = '',
    int notificationId = 0,
  }) async {
    if (kIsWeb) return;
    if (!_localInitialized) await initLocalNotifications();

    const androidDetails = AndroidNotificationDetails(
      'companion_proactive_channel',
      'AI 伙伴主动陪伴',
      channelDescription: 'AI 伙伴主动消息',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentSound: true),
    );
    final body = message.trim().isNotEmpty ? message.trim() : reason.trim();
    if (body.isEmpty) return;
    final localId = notificationId > 0
        ? 100000000 + notificationId.remainder(100000000)
        : 100000001;
    await _localNotifications.show(
      localId,
      'AI 伙伴想和你聊聊',
      body,
      details,
      payload: notificationId > 0 ? 'companion:$notificationId' : 'companion',
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
      if (!ApiResponse.isSuccess(response)) return [];

      final data = ApiResponse.listOf(
        response,
        keys: const ['notifications', 'data'],
      );
      final out = <NotificationModel>[];
      for (final e in data) {
        if (e is! Map) continue;
        try {
          out.add(NotificationModel.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {
          // 单条解析失败时跳过，避免整页空白
        }
      }
      return out;
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
      if (!ApiResponse.isSuccess(response)) return 0;

      final count = ApiResponse.intField(response, 'count');
      if (count != null) return count;

      final d = response['data'];
      if (d is int) return d;
      if (d is num) return d.toInt();
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
