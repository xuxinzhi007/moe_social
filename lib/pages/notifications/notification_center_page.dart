import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../widgets/avatar_image.dart';
import '../../utils/error_handler.dart';
import '../../theme/moe_tokens.dart';
import '../../theme/moe_theme_extension.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/fade_in_up.dart';
import '../announcements/announcement_detail_page.dart';

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MoeTokens.radiusXl)),
          title: const Text('清除所有通知'),
          content: const Text('确定要清除所有通知吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
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
      case NotificationModel.announcement:
        icon = Icons.campaign_rounded;
        color = MoeTokens.primary;
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
      padding: const EdgeInsets.all(MoeTokens.spaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: MoeTokens.textXl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: Text(
          '消息中心',
          style: TextStyle(
            fontWeight: MoeTokens.fontWeightTitle,
            fontSize: MoeTokens.textLg,
          ),
        ),
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/announcements'),
            child: const Text('公告'),
          ),
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: MoeTokens.spaceLg),
              label: const Text('已读'),
              style: TextButton.styleFrom(
                foregroundColor: moe.primary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
            onPressed: _clearAllNotifications,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const MessageSkeleton(itemCount: 8);
    }
    
    if (_notifications.isEmpty) {
      return const Center(
        child: MoeEmptyState(
          title: '暂无新消息',
          subtitle: '当有人互动时，你会在这里收到通知',
          icon: Icons.notifications_none_rounded,
          compact: false,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg,
        vertical: MoeTokens.spaceMd,
      ),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final delay = Duration(
          milliseconds: index * MoeTokens.motionStaggerStep.inMilliseconds,
        );
        return FadeInUp(
          delay: delay,
          child: Dismissible(
            key: ValueKey('notification_${notification.id}'),
            background: Container(
              margin: EdgeInsets.symmetric(vertical: MoeTokens.spaceXs + MoeTokens.spaceXs),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
              ),
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: MoeTokens.spaceXl),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              setState(() {
                _notifications.removeAt(index);
              });
            },
            child: GestureDetector(
              onTap: () {
                if (!notification.isRead) {
                  _markAsRead(notification.id);
                }
                final annId = notification.announcementId;
                if (annId != null && annId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AnnouncementDetailPage(announcementId: annId),
                    ),
                  );
                  return;
                }
                if (notification.type == NotificationModel.system) {
                  Navigator.pushNamed(context, '/announcements');
                }
              },
              child: Container(
                margin: EdgeInsets.only(bottom: MoeTokens.spaceMd),
                decoration: BoxDecoration(
                  color: MoeTokens.cardBackground,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                  boxShadow: MoeTokens.shadowSm(),
                  border: !notification.isRead 
                      ? Border.all(color: MoeTokens.primary.withValues(alpha: 0.3), width: 1.5)
                      : null,
                ),
                child: Padding(
                  padding: EdgeInsets.all(MoeTokens.spaceLg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧图标或头像
                      notification.relatedUserAvatar != null
                          ? NetworkAvatarImage(
                              imageUrl: notification.relatedUserAvatar!,
                              radius: MoeTokens.space2xl,
                              placeholderIcon: Icons.person,
                            )
                          : _buildNotificationIcon(notification.type),
                      
                      SizedBox(width: MoeTokens.spaceLg),
                      
                      // 内容区域
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
                                      fontWeight: MoeTokens.fontWeightSubtitle,
                                      fontSize: MoeTokens.textMd,
                                      color: MoeTokens.titleText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    margin: EdgeInsets.only(left: MoeTokens.spaceSm),
                                    width: MoeTokens.spaceSm,
                                    height: MoeTokens.spaceSm,
                                    decoration: BoxDecoration(
                                      color: MoeTokens.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: MoeTokens.spaceXs + MoeTokens.spaceXs),
                            Text(
                              notification.content,
                              style: TextStyle(
                                color: MoeTokens.hintText,
                                fontSize: MoeTokens.textBase,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: MoeTokens.spaceSm),
                            Text(
                              _formatTime(notification.createdAt),
                              style: TextStyle(
                                fontSize: MoeTokens.textSm,
                                color: MoeTokens.hintText.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
