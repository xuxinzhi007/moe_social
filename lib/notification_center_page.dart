import 'package:flutter/material.dart';
import './models/notification.dart';
import './services/notification_service.dart';
import './widgets/avatar_image.dart';
import './utils/error_handler.dart';
import './widgets/fade_in_up.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await NotificationService.getNotifications();
      setState(() {
        _notifications = notifications;
        _unreadCount = notifications.where((n) => !n.isRead).length;
      });
    } catch (e) {
      ErrorHandler.handleException(context, e as Exception);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService.markAllAsRead();
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList().cast<NotificationModel>();
        _unreadCount = 0;
      });
      ErrorHandler.showSuccess(context, '所有通知已标记为已读');
    } catch (e) {
      ErrorHandler.handleException(context, e as Exception);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllNotifications() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('清除所有通知'),
          content: const Text('确定要清除所有通知吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  _isLoading = true;
                });

                try {
                  await NotificationService.clearAllNotifications();
                  setState(() {
                    _notifications = [];
                    _unreadCount = 0;
                  });
                  ErrorHandler.showSuccess(context, '所有通知已清除');
                } catch (e) {
                  ErrorHandler.handleException(context, e as Exception);
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              child: const Text('确定', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList().cast<NotificationModel>();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      });
    } catch (e) {
      ErrorHandler.handleException(context, e as Exception);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }

  Widget _buildNotificationIcon(int type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case NotificationModel.like:
        icon = Icons.favorite_rounded;
        color = Colors.pinkAccent;
        break;
      case NotificationModel.comment:
        icon = Icons.chat_bubble_rounded;
        color = Colors.blueAccent;
        break;
      case NotificationModel.follow:
        icon = Icons.person_add_rounded;
        color = Colors.green;
        break;
      case NotificationModel.system:
        icon = Icons.notifications_rounded;
        color = Colors.orange;
        break;
      case NotificationModel.directMessage:
        icon = Icons.mark_chat_unread_rounded;
        color = Colors.deepPurple;
        break;
      default:
        icon = Icons.notifications_rounded;
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('消息中心', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text('全部已读'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7F7FD5),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
            onPressed: _clearAllNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                          ],
                        ),
                        child: Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey[300]),
                      ),
                      const SizedBox(height: 24),
                      const Text('暂无新消息', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: 30 * (index % 10)),
                      child: GestureDetector(
                        onTap: () {
                          if (!notification.isRead) {
                            _markAsRead(notification.id);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: !notification.isRead 
                                ? Border.all(color: const Color(0xFF7F7FD5).withOpacity(0.3), width: 1.5)
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                notification.relatedUserAvatar != null
                                    ? NetworkAvatarImage(
                                        imageUrl: notification.relatedUserAvatar!,
                                        radius: 24,
                                        placeholderIcon: Icons.person,
                                      )
                                    : _buildNotificationIcon(notification.type),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notification.title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.grey[800],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!notification.isRead)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF7F7FD5),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification.content,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatTime(notification.createdAt),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
