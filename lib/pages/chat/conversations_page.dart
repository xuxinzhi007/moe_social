import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth_service.dart';
import '../../models/notification.dart';
import '../../models/private_conversation_item.dart';
import '../../models/user.dart';
import '../../services/chat_push_service.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../providers/main_nav_controller.dart';
import '../../providers/notification_provider.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/chat_message_display.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_stagger.dart';
import 'conversations_viewmodel.dart';

/// 会话列表。`embedded: true` 时无 Scaffold，用于嵌在 [FriendsPage] 的 Tab 里。
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    super.key,
    this.embedded = false,
    this.showEmbeddedToolbar = true,
    this.onEmptyFindFriends,
    this.onEmptyExplore,
    this.emptyExploreLabel,
    this.emptyExploreIcon,
  });

  final bool embedded;
  final bool showEmbeddedToolbar;
  final VoidCallback? onEmptyFindFriends;
  final VoidCallback? onEmptyExplore;
  final String? emptyExploreLabel;
  final IconData? emptyExploreIcon;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  late final ConversationsViewModel _vm;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _revealedConversationKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _vm = ConversationsViewModel();
    _vm.addListener(_onVmChanged);
    _searchController.addListener(_handleSearchChanged);
    ChatPushService.unreadBySender.addListener(_onPushUnread);
    DirectChatSyncBus.threadsTick.addListener(_onLocalThreadsTick);
    unawaited(_vm.load());
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    ChatPushService.unreadBySender.removeListener(_onPushUnread);
    DirectChatSyncBus.threadsTick.removeListener(_onLocalThreadsTick);
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  void _handleSearchChanged() {
    _vm.updateSearchQuery(_searchController.text);
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
        _buildSearchBar(context),
        const SizedBox(height: 8),
        Expanded(child: _buildList(context, _vm.localPeers)),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(color: MoeTokens.surfaceBorder),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜索会话、好友昵称或 Moe ID',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: MoeTokens.hintText,
            ),
            suffixIcon: _vm.searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    onPressed: () => _searchController.clear(),
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
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
        backgroundColor: MoeTokens.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const ContinuousRectangleBorder(
          side: BorderSide(color: MoeTokens.surfaceBorder),
        ),
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
      body: body,
    );
  }

  Widget _buildList(BuildContext context, Set<String> localPeers) {
    final myId = AuthService.currentUser ?? '';
    final pushUnread = context.watch<NotificationProvider>().unreadDmBySender;
    final query = _vm.searchQuery.toLowerCase();

    if (_vm.serverConversations.isNotEmpty) {
      final rows =
          List<PrivateConversationItem>.from(_vm.serverConversations).where((c) {
        final lastAt = DateTime.tryParse(c.lastMessage.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (!_vm.isAfterClearMarker(c.peerUserId.trim(), lastAt)) return false;
        if (query.isEmpty) return true;
        final peerId = c.peerUserId.trim().toLowerCase();
        final peerName = c.peerName.trim().toLowerCase();
        final friend = _vm.friends.cast<User?>().firstWhere(
              (u) => u?.id == c.peerUserId.trim(),
              orElse: () => null,
            );
        final friendName = (friend?.username ?? '').trim().toLowerCase();
        final moeNo = (friend?.moeNo ?? '').trim().toLowerCase();
        return peerId.contains(query) ||
            peerName.contains(query) ||
            friendName.contains(query) ||
            moeNo.contains(query);
      }).toList();
      if (rows.isEmpty) {
        return _buildSearchEmptyState(context);
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
            final preview = previewRaw.isEmpty
                ? '点击开始聊天'
                : formatDmPreviewForUi(previewRaw);
            final pushBadge = pushUnread[peerId] ?? 0;
            final badge = pushBadge > c.unreadCount ? pushBadge : c.unreadCount;
            // 解析最后活跃时间
            DateTime? lastActive;
            try {
              lastActive = DateTime.parse(c.lastMessage.createdAt);
            } catch (_) {}
            return _buildConversationRow(
              context,
              avatar: avatar,
              title: title,
              preview: preview,
              badge: badge,
              lastActive: lastActive,
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
    for (final f in _vm.friends) {
      peerIds.add(f.id);
    }
    peerIds.addAll(pushUnread.keys);
    peerIds.addAll(lastBySender.keys);
    peerIds.addAll(localPeers);
    peerIds.remove(myId);
    peerIds.removeWhere((e) => e.isEmpty);

    if (peerIds.isEmpty) {
      return Center(
        child: MoeEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: '还没有聊天',
          subtitle: '先添加好友，或者通过搜索找到要聊天的人',
          primaryAction: MoeEmptyStateAction(
            label: '去找好友',
            icon: Icons.people_rounded,
            onPressed: () {
              if (widget.onEmptyFindFriends != null) {
                widget.onEmptyFindFriends!();
                return;
              }
              context.read<MainNavController>().requestTab(1);
            },
          ),
          secondaryAction: MoeEmptyStateAction(
            label: widget.emptyExploreLabel ?? '回首页',
            icon: widget.emptyExploreIcon ?? Icons.home_rounded,
            onPressed: () {
              if (widget.onEmptyExplore != null) {
                widget.onEmptyExplore!();
                return;
              }
              context.read<MainNavController>().requestTab(0);
            },
          ),
        ),
      );
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
      if (query.isEmpty) return true;
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
          '';
      final moeNo = friend?.moeNo ?? '';
      return peerId.toLowerCase().contains(query) ||
          title.toLowerCase().contains(query) ||
          moeNo.toLowerCase().contains(query);
    }).toList();

    if (filteredRows.isEmpty) {
      return _buildSearchEmptyState(context);
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
          final lt = _vm.localThreadTails[peerId];
          final st = _vm.serverThreadTails[peerId];
          final previewRaw = () {
            var bestAt = DateTime.fromMillisecondsSinceEpoch(0);
            var bestRaw = '';
            if (lt != null &&
                lt.rawPreview.isNotEmpty &&
                lt.at.isAfter(bestAt)) {
              bestAt = lt.at;
              bestRaw = lt.rawPreview;
            }
            if (st != null &&
                st.rawPreview.isNotEmpty &&
                st.at.isAfter(bestAt)) {
              bestRaw = st.rawPreview;
            }
            return bestRaw;
          }();
          final preview = previewRaw.isEmpty
              ? (last == null ? '' : '收到一条新消息')
              : formatDmPreviewForUi(previewRaw);
          final badge = pushUnread[peerId] ?? 0;

          return MoeStaggerReveal(
            index: i,
            itemKey: 'conv_$peerId',
            revealedKeys: _revealedConversationKeys,
            child: _buildConversationRow(
              context,
              avatar: avatar,
              title: title,
              preview: preview.isEmpty ? '点击开始聊天' : preview,
              badge: badge,
              lastActive: lastActivity(peerId),
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

  Widget _buildSearchEmptyState(BuildContext context) {
    return Center(
      child: MoeEmptyState(
        icon: Icons.search_off_rounded,
        title: '没有找到匹配的会话',
        subtitle: '试试搜索好友昵称、用户 ID，或者先去添加新的好友。',
        primaryAction: MoeEmptyStateAction(
          label: '清空搜索',
          icon: Icons.refresh_rounded,
          onPressed: () => _searchController.clear(),
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
      ),
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
}
