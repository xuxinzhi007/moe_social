import 'package:flutter/material.dart';
import './models/notification.dart';
import './services/notification_service.dart';
import './widgets/avatar_image.dart';
import './utils/error_handler.dart';

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
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
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
        }).toList();
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

  Widget _buildNotificationIcon(String type) {
    switch (type) {
      case NotificationModel.like:
        return const Icon(Icons.favorite, color: Colors.red);
      case NotificationModel.comment:
        return const Icon(Icons.comment, color: Colors.blueAccent);
      case NotificationModel.follow:
        return const Icon(Icons.person_add, color: Colors.green);
      case NotificationModel.system:
        return const Icon(Icons.notifications, color: Colors.orange);
      default:
        return const Icon(Icons.notifications, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('全部已读'),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearAllNotifications();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('清除所有通知'),
                  ],
                ),
              ),
            ],
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
                      Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('暂无通知', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return GestureDetector(
                      onTap: () {
                        // 标记为已读
                        if (!notification.isRead) {
                          _markAsRead(notification.id);
                        }
                        // 根据通知类型跳转到相关页面
                        // if (notification.type == NotificationModel.like || notification.type == NotificationModel.comment) {
                        //   if (notification.relatedPostId != null) {
                        //     Navigator.pushNamed(context, '/post-detail', arguments: notification.relatedPostId);
                        //   }
                        // } else if (notification.type == NotificationModel.follow) {
                        //   if (notification.relatedUserId != null) {
                        //     Navigator.pushNamed(context, '/user-profile', arguments: notification.relatedUserId);
                        //   }
                        // }
                      },
                      child: Container(
                        color: notification.isRead ? null : Colors.blue[50],
                        child: ListTile(
                          leading: notification.relatedUserAvatar != null
                              ? NetworkAvatarImage(
                                  imageUrl: notification.relatedUserAvatar!,
                                  radius: 32,
                                  placeholderIcon: Icons.person,
                                )
                              : Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: _buildNotificationIcon(notification.type),
                                ),
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification.content),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(notification.createdAt),
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: !notification.isRead
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : const SizedBox(width: 8),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
