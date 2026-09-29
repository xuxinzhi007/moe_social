import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification.dart';
import '../../providers/notification_provider.dart';
import '../../services/companion_chat_launcher.dart';
import '../../widgets/avatar_image.dart';
import '../../utils/error_handler.dart';
import '../../theme/moe_tokens.dart';
import '../../theme/moe_theme_extension.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../announcements/announcement_detail_page.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final Set<String> _revealedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().fetchNotifications(refresh: true);
    });
  }

  Future<void> _markAllAsRead() async {
    final provider = context.read<NotificationProvider>();
    try {
      await provider.markAllActivityAsRead();
      if (!mounted) return;
      ErrorHandler.showSuccess(context, '已全部标记为已读');
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await context.read<NotificationProvider>().markNotificationAsRead(
            notificationId,
          );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return difference.inMinutes <= 0 ? '刚刚' : '${difference.inMinutes} 分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} 天前';
    } else {
      return '${time.month}/${time.day}';
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
      case NotificationModel.giftReceived:
        icon = Icons.card_giftcard_rounded;
        color = Colors.amber;
        break;
      case NotificationModel.companionProactive:
        icon = Icons.auto_awesome_rounded;
        color = MoeTokens.primary;
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

  bool _isActionable(NotificationModel notification) {
    return notification.announcementId?.isNotEmpty == true ||
        notification.type == NotificationModel.system ||
        notification.type == NotificationModel.companionProactive;
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final notifications = provider.activityNotifications;
        final unreadCount = provider.activityUnreadCount;
        final isLoading = provider.isLoading;
        return Scaffold(
          backgroundColor: MoeTokens.pageBackground,
          appBar: AppBar(
            title: Text(
              '通知中心',
              style: TextStyle(
                fontWeight: MoeTokens.fontWeightTitle,
                fontSize: MoeTokens.textLg,
              ),
            ),
            backgroundColor: MoeTokens.cardBackground,
            foregroundColor: MoeTokens.titleText,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            shape: const Border(
              bottom: BorderSide(color: MoeTokens.surfaceBorder),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/announcements'),
                child: const Text('公告'),
              ),
              if (unreadCount > 0)
                IconButton(
                  onPressed: _markAllAsRead,
                  tooltip: '全部已读',
                  icon: Icon(Icons.done_all_rounded, color: moe.primary),
                ),
            ],
          ),
          body: _buildBody(provider, notifications, isLoading),
        );
      },
    );
  }

  Widget _buildBody(
    NotificationProvider provider,
    List<NotificationModel> notifications,
    bool isLoading,
  ) {
    return Column(
      children: [
        Expanded(
          child: isLoading
              ? const MessageSkeleton(itemCount: 8)
              : notifications.isEmpty
                  ? const Center(
                      child: MoeEmptyState(
                        title: '暂时没有通知',
                        subtitle: '评论、礼物和系统消息会出现在这里',
                        icon: Icons.notifications_none_rounded,
                        compact: false,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          provider.fetchNotifications(refresh: true),
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: MoeTokens.spaceLg,
                          vertical: MoeTokens.spaceMd,
                        ),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return MoeStaggerReveal(
                            index: index,
                            itemKey: notification.id,
                            revealedKeys: _revealedNotificationIds,
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                MoeTokens.radiusXl,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  MoeTokens.radiusXl,
                                ),
                                onTap: () {
                                  if (!notification.isRead) {
                                    _markAsRead(notification.id);
                                  }
                                  final annId = notification.announcementId;
                                  if (annId != null && annId.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => AnnouncementDetailPage(
                                            announcementId: annId),
                                      ),
                                    );
                                    return;
                                  }
                                  if (notification.type ==
                                      NotificationModel.system) {
                                    Navigator.pushNamed(
                                        context, '/announcements');
                                  } else if (notification.type ==
                                      NotificationModel.companionProactive) {
                                    unawaited(
                                      CompanionChatLauncher.openChat(context),
                                    );
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.only(
                                      bottom: MoeTokens.spaceMd),
                                  decoration: BoxDecoration(
                                    color: MoeTokens.surface1,
                                    borderRadius: BorderRadius.circular(
                                      MoeTokens.radiusXl,
                                    ),
                                    boxShadow: MoeTokens.shadowSm(),
                                    border: !notification.isRead
                                        ? Border.all(
                                            color: MoeTokens.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(MoeTokens.spaceLg),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        notification.relatedUserAvatar != null
                                            ? NetworkAvatarImage(
                                                imageUrl: notification
                                                    .relatedUserAvatar!,
                                                radius: MoeTokens.space2xl,
                                                placeholderIcon: Icons.person,
                                              )
                                            : _buildNotificationIcon(
                                                notification.type,
                                              ),
                                        SizedBox(width: MoeTokens.spaceLg),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      notification.title,
                                                      style: TextStyle(
                                                        fontWeight: MoeTokens
                                                            .fontWeightSubtitle,
                                                        fontSize:
                                                            MoeTokens.textMd,
                                                        color:
                                                            MoeTokens.titleText,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (!notification.isRead)
                                                    Container(
                                                      margin: EdgeInsets.only(
                                                        left: MoeTokens.spaceSm,
                                                      ),
                                                      width: MoeTokens.spaceSm,
                                                      height: MoeTokens.spaceSm,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            MoeTokens.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: MoeTokens.spaceXs +
                                                    MoeTokens.spaceXs,
                                              ),
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
                                              SizedBox(
                                                  height: MoeTokens.spaceSm),
                                              Text(
                                                _formatTime(
                                                    notification.createdAt),
                                                style: TextStyle(
                                                  fontSize: MoeTokens.textSm,
                                                  color: MoeTokens.hintText
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_isActionable(notification))
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(
                                              Icons.chevron_right_rounded,
                                              color: MoeTokens.hintText,
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
                      ),
                    ),
        ),
      ],
    );
  }
}
