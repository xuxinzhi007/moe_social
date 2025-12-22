import 'dart:async';
import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  // 获取通知列表
  static Future<List<NotificationModel>> getNotifications() async {
    try {
      // 实际应用中应该调用后端API获取通知
      // final result = await ApiService.getNotifications();
      // final notificationsJson = result['data'] as List;
      // return notificationsJson.map((json) => NotificationModel.fromJson(json)).toList();
      
      // 模拟数据
      return _getMockNotifications();
    } catch (e) {
      print('Failed to get notifications: $e');
      // 返回模拟数据作为备选
      return _getMockNotifications();
    }
  }

  // 标记通知为已读（本地模拟）
  static Future<void> markAsRead(String notificationId) async {
    try {
      // 实际应用中应该调用后端API
      // await ApiService.markNotificationAsRead(notificationId);
      print('Notification marked as read: $notificationId');
    } catch (e) {
      print('Failed to mark notification as read: $e');
    }
  }

  // 标记所有通知为已读（本地模拟）
  static Future<void> markAllAsRead() async {
    try {
      // 实际应用中应该调用后端API
      // await ApiService.markAllNotificationsAsRead();
      print('All notifications marked as read');
    } catch (e) {
      print('Failed to mark all notifications as read: $e');
    }
  }

  // 删除通知（本地模拟）
  static Future<void> deleteNotification(String notificationId) async {
    try {
      // 实际应用中应该调用后端API
      // await ApiService.deleteNotification(notificationId);
      print('Notification deleted: $notificationId');
    } catch (e) {
      print('Failed to delete notification: $e');
    }
  }

  // 清除所有通知（本地模拟）
  static Future<void> clearAllNotifications() async {
    try {
      // 实际应用中应该调用后端API
      // await ApiService.clearAllNotifications();
      print('All notifications cleared');
    } catch (e) {
      print('Failed to clear all notifications: $e');
    }
  }

  // 获取未读通知数量（本地模拟）
  static Future<int> getUnreadCount() async {
    try {
      // 实际应用中应该调用后端API
      // final result = await ApiService.getUnreadNotificationCount();
      // return result['data'] as int;
      return 3; // 模拟3条未读通知
    } catch (e) {
      print('Failed to get unread notification count: $e');
      return 0;
    }
  }

  // 模拟通知数据
  static List<NotificationModel> _getMockNotifications() {
    final now = DateTime.now();
    return [
      NotificationModel(
        id: '1',
        type: NotificationModel.like,
        title: '有人点赞了你的帖子',
        content: '用户 "小明" 点赞了你的帖子 "今天天气真好"',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 10)),
        relatedPostId: 'post1',
        relatedUserId: 'user1',
        relatedUserName: '小明',
        relatedUserAvatar: 'https://randomuser.me/api/portraits/men/32.jpg',
      ),
      NotificationModel(
        id: '2',
        type: NotificationModel.comment,
        title: '有人评论了你的帖子',
        content: '用户 "小红" 评论了你的帖子 "今天天气真好": "确实不错！"',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 1)),
        relatedPostId: 'post1',
        relatedUserId: 'user2',
        relatedUserName: '小红',
        relatedUserAvatar: 'https://randomuser.me/api/portraits/women/44.jpg',
      ),
      NotificationModel(
        id: '3',
        type: NotificationModel.follow,
        title: '有人关注了你',
        content: '用户 "小刚" 关注了你',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 3)),
        relatedUserId: 'user3',
        relatedUserName: '小刚',
        relatedUserAvatar: 'https://randomuser.me/api/portraits/men/78.jpg',
      ),
      NotificationModel(
        id: '4',
        type: NotificationModel.system,
        title: '系统通知',
        content: '欢迎使用 Moe Social！我们将持续为您提供更好的服务',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
