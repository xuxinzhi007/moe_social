import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth_service.dart';
import '../../constants/feature_flags.dart';
import '../../models/notification.dart';
import '../../models/private_conversation_item.dart';
import '../../models/user.dart';
import '../../services/chat_push_service.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../services/presence_service.dart';
import '../../providers/main_nav_controller.dart';
import '../../providers/notification_provider.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/chat_message_display.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_glass_surface.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../widgets/motion/moe_motion.dart';
import 'conversations_viewmodel.dart';
import 'widgets/chat_empty_illustration.dart';

/// 会话列表。`embedded: true` 时无 Scaffold，用于嵌在 [FriendsPage] 的 Tab 里。
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    super.key,
    this.embedded = false,
    this.showEmbeddedToolbar = true,
    this.onEmptyFindFriends,
  });

  final bool embedded;
  final bool showEmbeddedToolbar;
  final VoidCallback? onEmptyFindFriends;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  late final ConversationsViewModel _vm;
  final Set<String> _revealedConversationKeys = <String>{};
  int _hideNoticeToken = 0;
  String? _hideNoticePeerId;

  @override
  void initState() {
    super.initState();
    _vm = ConversationsViewModel();
    _vm.addListener(_onVmChanged);
    ChatPushService.unreadBySender.addListener(_onPushUnread);
    DirectChatSyncBus.threadsTick.addListener(_onLocalThreadsTick);
    PresenceService.start();
    PresenceService.online.addListener(_onPresenceChanged);
    unawaited(_vm.load());
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    ChatPushService.unreadBySender.removeListener(_onPushUnread);
    DirectChatSyncBus.threadsTick.removeListener(_onLocalThreadsTick);
    PresenceService.online.removeListener(_onPresenceChanged);
    super.dispose();
  }

  void _onPresenceChanged() {
    if (mounted) setState(() {});
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  void _onPushUnread() {
    _vm.onPushUnread();
  }

  void _onLocalThreadsTick() {
    _vm.onLocalThreadsTick();
  }

  Widget _buildBody(BuildContext context) {
    if (_vm.loading) {
      return Center(child: MoeLoading(color: MoeTheme.of(context).primary));
    }
    if (_vm.loadError != null) {
      return Center(
        child: MoeErrorState.fromError(
          _vm.loadError,
          scene: MoeErrorScene.messages,
          variant: MoeErrorVariant.plain,
          onRetry: () => unawaited(_vm.load()),
        ),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildOnlineFriendsStrip(context),
        const SizedBox(height: 4),
        Expanded(child: _buildList(context, _vm.localPeers)),
      ],
    );
  }

  Widget _buildOnlineFriendsStrip(BuildContext context) {
    final onlineFriends = _vm.friends
        .where((f) => PresenceService.isUserOnline(f.id))
        .take(16)
        .toList();
    if (onlineFriends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
          child: Text(
            '在线同好 · ${onlineFriends.length}',
            style: const TextStyle(
              fontSize: MoeTokens.textSm,
              fontWeight: MoeTokens.fontWeightSubtitle,
              color: MoeTokens.hintText,
            ),
          ),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: onlineFriends.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final user = onlineFriends[i];
              return _OnlineFriendChip(
                user: user,
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    '/direct-chat',
                    arguments: {
                      'userId': user.id,
                      'username': user.username,
                      'avatar': user.avatar,
                    },
                  );
                  if (mounted) await _vm.load();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _withHideCapsule(_buildBody(context));
    if (widget.embedded) {
      if (!widget.showEmbeddedToolbar) return body;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _vm.loading ? null : () => unawaited(_vm.load()),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('刷新'),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    final glassNav = FeatureFlags.glassNavigation;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '消息',
          style: TextStyle(
            fontSize: MoeTokens.textXl,
            fontWeight: MoeTokens.fontWeightTitle,
            color: MoeTokens.titleText,
          ),
        ),
        backgroundColor: glassNav ? Colors.transparent : MoeTokens.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: glassNav
            ? null
            : const ContinuousRectangleBorder(
                side: BorderSide(color: MoeTokens.surfaceBorder),
              ),
        flexibleSpace: glassNav
            ? MoeGlassSurface(
                tint: MoeTokens.surface1.withValues(alpha: 0.78),
                showBorder: false,
                child: Container(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _vm.loading ? null : () => unawaited(_vm.load()),
            icon: const Icon(
              Icons.refresh_rounded,
              color: MoeTokens.hintText,
            ),
          ),
        ],
      ),
      backgroundColor: MoeTokens.surface0,
      extendBodyBehindAppBar: glassNav,
      body: body,
    );
  }

  Widget _buildList(BuildContext context, Set<String> localPeers) {
    final myId = AuthService.currentUser ?? '';
    final pushUnread = context.watch<NotificationProvider>().unreadDmBySender;

    if (_vm.serverConversations.isNotEmpty) {
      final rows = List<PrivateConversationItem>.from(_vm.serverConversations)
          .where((c) {
        final peerId = c.peerUserId.trim();
        final lastAt = DateTime.tryParse(c.lastMessage.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (!_vm.isPeerVisibleInConversationList(peerId, lastAt)) {
          return false;
        }
        final body = c.lastMessage.body.trim();
        return body.isNotEmpty || c.lastMessage.imagePaths.isNotEmpty;
      }).toList();
      if (rows.isEmpty) {
        return _buildListEmptyState(context, searching: false);
      }
      return RefreshIndicator(
        onRefresh: _vm.load,
        color: MoeTheme.of(context).primary,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 76,
            color: MoeTokens.surfaceBorder,
          ),
          itemBuilder: (context, i) {
            final c = rows[i];
            final peerId = c.peerUserId.trim();
            if (peerId.isEmpty || peerId == myId) {
              return const SizedBox.shrink();
            }
            User? friend;
            for (final u in _vm.friends) {
              if (u.id == peerId) {
                friend = u;
                break;
              }
            }
            final title = () {
              final friendName = (friend?.username ?? '').trim();
              if (friendName.isNotEmpty) return friendName;
              final peerName = c.peerName.trim();
              if (peerName.isNotEmpty) return peerName;
              return ChatPushService.cachedSenderDisplayName(peerId) ?? '用户';
            }();
            final avatar = (friend?.avatar ?? '').trim().isNotEmpty
                ? friend!.avatar
                : c.peerAvatar;
            var previewRaw = c.lastMessage.body.trim();
            if (previewRaw.isEmpty && c.lastMessage.imagePaths.isNotEmpty) {
              previewRaw = '[IMG]';
            }
            final preview = formatDmPreviewForUi(previewRaw);
            final badge = c.unreadCount;
            // 解析最后活跃时间
            DateTime? lastActive;
            try {
              lastActive = DateTime.parse(c.lastMessage.createdAt);
            } catch (_) {}
            return _dismissibleConversation(
              peerId: peerId,
              child: _buildConversationRow(
                context,
                avatar: avatar,
                title: title,
                preview: preview,
                badge: badge,
                lastActive: lastActive,
                isOnline: PresenceService.isUserOnline(peerId),
                onTap: () async {
                  if (!context.mounted) return;
                  await Navigator.pushNamed(
                    context,
                    '/direct-chat',
                    arguments: {
                      'userId': peerId,
                      'username': title,
                      'avatar': avatar,
                    },
                  );
                  if (mounted) await _vm.load();
                },
              ),
            );
          },
        ),
      );
    }

    final dmNotifs = _vm.notifs
        .where((n) =>
            n.type == NotificationModel.directMessage &&
            (n.senderId ?? '').isNotEmpty &&
            n.senderId != myId &&
            _vm.isAfterClearMarker(n.senderId!, n.createdAt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final lastBySender = <String, NotificationModel>{};
    for (final n in dmNotifs) {
      final sid = n.senderId!;
      lastBySender.putIfAbsent(sid, () => n);
    }

    final peerIds = <String>{};
    peerIds.addAll(pushUnread.keys);
    peerIds.addAll(lastBySender.keys);
    peerIds.addAll(localPeers);
    peerIds.addAll(_vm.serverThreadTails.keys);
    peerIds.remove(myId);
    peerIds.removeWhere((e) => e.isEmpty);

    if (peerIds.isEmpty) {
      return _buildListEmptyState(context, searching: false);
    }

    DateTime lastActivity(String peerId) {
      final nt = lastBySender[peerId]?.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final lt = _vm.localThreadTails[peerId]?.at ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final st = _vm.serverThreadTails[peerId]?.at ??
          DateTime.fromMillisecondsSinceEpoch(0);
      var latest = nt;
      if (lt.isAfter(latest)) latest = lt;
      if (st.isAfter(latest)) latest = st;
      return latest;
    }

    final rows = peerIds.toList();
    rows.sort((a, b) {
      final ua = pushUnread[a] ?? 0;
      final ub = pushUnread[b] ?? 0;
      if (ua != ub) return ub.compareTo(ua);
      return lastActivity(b).compareTo(lastActivity(a));
    });

    final filteredRows = rows.where((peerId) {
      if (!_vm.isPeerVisibleInConversationList(
        peerId,
        lastActivity(peerId),
      )) {
        return false;
      }
      return _conversationPreview(
        peerId: peerId,
        notification: lastBySender[peerId],
      ).isNotEmpty;
    }).toList();

    if (filteredRows.isEmpty) {
      return _buildListEmptyState(context, searching: false);
    }

    return RefreshIndicator(
      onRefresh: _vm.load,
      color: MoeTheme.of(context).primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: filteredRows.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 76,
          color: MoeTokens.surfaceBorder,
        ),
        itemBuilder: (context, i) {
          final peerId = filteredRows[i];
          User? friend;
          for (final u in _vm.friends) {
            if (u.id == peerId) {
              friend = u;
              break;
            }
          }
          final last = lastBySender[peerId];
          final title = friend?.username ??
              ChatPushService.cachedSenderDisplayName(peerId) ??
              last?.senderName ??
              '用户';
          final avatar = friend?.avatar ?? last?.senderAvatar ?? '';
          final preview = _conversationPreview(
            peerId: peerId,
            notification: last,
          );
          final badge = pushUnread[peerId] ?? 0;

          return MoeStaggerReveal(
            index: i,
            itemKey: 'conv_$peerId',
            revealedKeys: _revealedConversationKeys,
            child: _dismissibleConversation(
              peerId: peerId,
              child: _buildConversationRow(
                context,
                avatar: avatar,
                title: title,
                preview: preview,
                badge: badge,
                lastActive: lastActivity(peerId),
                isOnline: PresenceService.isUserOnline(peerId),
                onTap: () async {
                  if (!context.mounted) return;
                  await Navigator.pushNamed(
                    context,
                    '/direct-chat',
                    arguments: {
                      'userId': peerId,
                      'username': title,
                      'avatar': avatar,
                    },
                  );
                  if (mounted) await _vm.load();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// 列表空态：有搜索词 → 搜索无结果；否则 → 暂无会话（含全部隐藏）。
  Widget _buildListEmptyState(
    BuildContext context, {
    required bool searching,
  }) {
    final empty = searching
        ? MoeEmptyState(
            icon: Icons.search_off_rounded,
            title: '没有找到匹配的会话',
            subtitle: '试试搜索好友昵称、用户 ID，或者先去添加新的好友。',
            compact: true,
            primaryAction: MoeEmptyStateAction(
              label: '清空搜索',
              icon: Icons.refresh_rounded,
              onPressed: () {},
            ),
            secondaryAction: MoeEmptyStateAction(
              label: '找好友',
              icon: Icons.people_rounded,
              onPressed: () {
                if (widget.onEmptyFindFriends != null) {
                  widget.onEmptyFindFriends!();
                  return;
                }
                context.read<MainNavController>().requestTab(1);
              },
            ),
          )
        : MoeEmptyState(
            image: const ChatEmptyIllustration(),
            title: '还没有会话',
            subtitle: '新消息会出现在这里',
            compact: true,
            showCard: false,
            secondaryAction: MoeEmptyStateAction(
              label: '去通讯录',
              icon: Icons.people_outline_rounded,
              onPressed: () {
                if (widget.onEmptyFindFriends != null) {
                  widget.onEmptyFindFriends!();
                  return;
                }
                context.read<MainNavController>().requestTab(1);
              },
            ),
          );

    return RefreshIndicator(
      onRefresh: _vm.load,
      color: MoeTheme.of(context).primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: empty),
            ),
          );
        },
      ),
    );
  }

  Widget _dismissibleConversation({
    required String peerId,
    required Widget child,
  }) {
    return Dismissible(
      key: ValueKey('hide_conv_$peerId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: MoeTokens.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.visibility_off_outlined,
                color: MoeTokens.danger, size: 20),
            SizedBox(width: 6),
            Text(
              '不显示',
              style: TextStyle(
                color: MoeTokens.danger,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        // 先清未读，避免隐藏后列表刷新仍凭旧未读/活动把会话加回来。
        await context
            .read<NotificationProvider>()
            .markDirectMessagesAsRead(peerId);
        if (!mounted) return true;
        await _vm.hideConversation(peerId);
        if (!mounted) return true;
        _showHideCapsule(peerId);
        return true;
      },
      child: child,
    );
  }

  Widget _buildConversationRow(
    BuildContext context, {
    required String avatar,
    required String title,
    required String preview,
    required int badge,
    required VoidCallback onTap,
    DateTime? lastActive,
    bool isOnline = false,
  }) {
    // 格式化时间戳
    String? timeLabel;
    if (lastActive != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDate =
          DateTime(lastActive.year, lastActive.month, lastActive.day);
      final hm =
          '${lastActive.hour.toString().padLeft(2, '0')}:${lastActive.minute.toString().padLeft(2, '0')}';
      if (msgDate == today) {
        timeLabel = hm;
      } else if (msgDate == today.subtract(const Duration(days: 1))) {
        timeLabel = '昨天';
      } else {
        timeLabel = '${lastActive.month}/${lastActive.day}';
      }
    }

    return Material(
      color: Colors.transparent,
      child: MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            color: MoeTokens.surface1,
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MoeTokens.spaceMd,
              vertical: 12,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    avatar.trim().isNotEmpty
                        ? NetworkAvatarImage(
                            imageUrl: avatar,
                            radius: 24,
                          )
                        : ClipOval(
                            child: Image.asset(
                              'assets/chat/avatar_placeholder.png',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: MoeTokens.pastelTeal,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MoeTokens.surface1,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: MoeTokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: MoeTokens.fontWeightSubtitle,
                          fontSize: MoeTokens.textMd,
                          color: MoeTokens.titleText,
                        ),
                      ),
                      SizedBox(height: MoeTokens.spaceXs),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MoeTokens.hintText,
                          fontSize: MoeTokens.textSm,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: MoeTokens.spaceSm),
                // 右侧：时间 + 未读 badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            color: MoeTokens.hintText,
                            fontSize: MoeTokens.textXs,
                            fontWeight: MoeTokens.fontWeightCaption,
                          ),
                        ),
                      ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: MoeTokens.gradientPrimary,
                          borderRadius: BorderRadius.circular(
                            MoeTokens.radiusFull,
                          ),
                          boxShadow: MoeTokens.shadowGlow(
                            MoeTokens.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: MoeTokens.surface1,
                            fontSize: MoeTokens.textSm,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 有正文或图片才算一条会话；通知占位、空好友行不进列表。
  String _conversationPreview({
    required String peerId,
    required NotificationModel? notification,
  }) {
    final lt = _vm.localThreadTails[peerId];
    final st = _vm.serverThreadTails[peerId];
    var bestAt = DateTime.fromMillisecondsSinceEpoch(0);
    var bestRaw = '';
    if (lt != null && lt.rawPreview.trim().isNotEmpty) {
      bestAt = lt.at;
      bestRaw = lt.rawPreview;
    }
    if (st != null &&
        st.rawPreview.trim().isNotEmpty &&
        !st.at.isBefore(bestAt)) {
      bestRaw = st.rawPreview;
    }
    if (bestRaw.trim().isNotEmpty) {
      return formatDmPreviewForUi(bestRaw);
    }
    final content = (notification?.content ?? '').trim();
    if (content.isEmpty) return '';
    return formatDmPreviewForUi(content);
  }

  Widget _withHideCapsule(Widget child) {
    final peerId = _hideNoticePeerId;
    if (peerId == null) return child;
    final token = _hideNoticeToken;
    return Stack(
      children: [
        child,
        Positioned(
          top: MoeTokens.spaceSm,
          left: 0,
          right: 0,
          child: _HideCapsuleNotice(
            key: ValueKey(token),
            onUndo: () {
              setState(() => _hideNoticePeerId = null);
              unawaited(_vm.unhideConversation(peerId));
            },
            onDismissed: () {
              if (!mounted || _hideNoticeToken != token) return;
              setState(() => _hideNoticePeerId = null);
            },
          ),
        ),
      ],
    );
  }

  void _showHideCapsule(String peerId) {
    setState(() {
      _hideNoticeToken++;
      _hideNoticePeerId = peerId;
    });
  }
}

class _OnlineFriendChip extends StatelessWidget {
  const _OnlineFriendChip({
    required this.user,
    required this.onTap,
  });

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                user.avatar.trim().isNotEmpty
                    ? NetworkAvatarImage(imageUrl: user.avatar, radius: 24)
                    : ClipOval(
                        child: Image.asset(
                          'assets/chat/avatar_placeholder.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: MoeTokens.pastelTeal,
                      shape: BoxShape.circle,
                      border: Border.all(color: MoeTokens.surface1, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: MoeTokens.textXs,
                fontWeight: FontWeight.w600,
                color: MoeTokens.titleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部胶囊：淡入，停留后向上收回。
class _HideCapsuleNotice extends StatefulWidget {
  const _HideCapsuleNotice({
    super.key,
    required this.onUndo,
    required this.onDismissed,
  });

  final VoidCallback onUndo;
  final VoidCallback onDismissed;

  @override
  State<_HideCapsuleNotice> createState() => _HideCapsuleNoticeState();
}

class _HideCapsuleNoticeState extends State<_HideCapsuleNotice>
    with SingleTickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 2200);

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MoeTokens.motionMedium,
      reverseDuration: MoeTokens.motionFast,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.85),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (moeReduceMotion(context)) {
        _holdTimer = Timer(_hold, widget.onDismissed);
        return;
      }
      _controller.forward();
      _holdTimer = Timer(_hold, _close);
    });
  }

  Future<void> _close() async {
    _holdTimer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capsule = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(color: MoeTokens.lineSoft),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_off_outlined,
              size: 16,
              color: MoeTokens.inkMuted,
            ),
            const SizedBox(width: 6),
            const Text(
              '已隐藏',
              style: TextStyle(
                color: MoeTokens.titleText,
                fontSize: MoeTokens.textSm,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: widget.onUndo,
              style: TextButton.styleFrom(
                foregroundColor: MoeTokens.primary,
                minimumSize: const Size(44, 28),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                '撤销',
                style: TextStyle(
                  fontSize: MoeTokens.textSm,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Center(
      child: moeReduceMotion(context)
          ? capsule
          : FadeTransition(
              opacity: _opacity,
              child: SlideTransition(position: _offset, child: capsule),
            ),
    );
  }
}
