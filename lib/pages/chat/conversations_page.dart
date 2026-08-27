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
import '../../widgets/moe_icon.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_glass_surface.dart';
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
  });

  final bool embedded;
  final bool showEmbeddedToolbar;
  final VoidCallback? onEmptyFindFriends;

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
    PresenceService.start();
    PresenceService.online.addListener(_onPresenceChanged);
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
    PresenceService.online.removeListener(_onPresenceChanged);
    super.dispose();
  }

  void _onPresenceChanged() {
    if (mounted) setState(() {});
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

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: MoeInputField(
        controller: _searchController,
        hintText: '搜索会话、好友昵称或 Moe ID',
        maxLines: 1,
        textInputAction: TextInputAction.search,
        fillColor: MoeTokens.surface1,
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
    final query = _vm.searchQuery.toLowerCase();

    if (_vm.serverConversations.isNotEmpty) {
      final rows = List<PrivateConversationItem>.from(_vm.serverConversations)
          .where((c) {
        final peerId = c.peerUserId.trim();
        final lastAt = DateTime.tryParse(c.lastMessage.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (!_vm.isPeerVisibleInConversationList(peerId, lastAt)) {
          return false;
        }
        if (query.isEmpty) return true;
        final peerIdQ = peerId.toLowerCase();
        final peerName = c.peerName.trim().toLowerCase();
        final friend = _vm.friends.cast<User?>().firstWhere(
              (u) => u?.id == peerId,
              orElse: () => null,
            );
        final friendName = (friend?.username ?? '').trim().toLowerCase();
        final moeNo = (friend?.moeNo ?? '').trim().toLowerCase();
        return peerIdQ.contains(query) ||
            peerName.contains(query) ||
            friendName.contains(query) ||
            moeNo.contains(query);
      }).toList();
      if (rows.isEmpty) {
        return _buildListEmptyState(context, searching: query.isNotEmpty);
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
            final isVoicePreview = isVoiceDmPreview(previewRaw);
            final pushBadge = pushUnread[peerId] ?? 0;
            final badge = pushBadge > c.unreadCount ? pushBadge : c.unreadCount;
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
                isVoicePreview: isVoicePreview,
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
    for (final f in _vm.friends) {
      peerIds.add(f.id);
    }
    peerIds.addAll(pushUnread.keys);
    peerIds.addAll(lastBySender.keys);
    peerIds.addAll(localPeers);
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
      return _buildListEmptyState(context, searching: query.isNotEmpty);
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
          final isVoicePreview = isVoiceDmPreview(previewRaw);
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
                preview: preview.isEmpty ? '点击开始聊天' : preview,
                isVoicePreview: isVoicePreview,
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
          )
        : MoeEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: '暂时没有会话',
            subtitle: '左滑可隐藏会话；有新消息时会再出现在这里',
            compact: true,
            primaryAction: MoeEmptyStateAction(
              label: '去通讯录',
              icon: Icons.people_rounded,
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
        _showHideConversationSnackBar(peerId);
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
    bool isVoicePreview = false,
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
                      // 语音消息预览：MoeIcon 麦克风 + 文案（替代旧 🎤 emoji）。
                      if (isVoicePreview)
                        Row(
                          children: [
                            MoeIcon(
                              name: 'mic',
                              size: MoeTokens.textSm * 1.2,
                              color: MoeTokens.hintText,
                            ),
                            SizedBox(width: MoeTokens.spaceXs),
                            Expanded(
                              child: Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: MoeTokens.hintText,
                                  fontSize: MoeTokens.textSm,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
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

  /// 隐藏会话后的可撤销提示：带倒计时，到期自动消失。
  void _showHideConversationSnackBar(String peerId) {
    const undoSeconds = 5;
    final messenger = ScaffoldMessenger.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: _CountdownSnackLabel(
          prefix: '已隐藏',
          seconds: undoSeconds,
        ),
        duration: const Duration(seconds: undoSeconds),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.down,
        // 避开底部 Tab，避免与导航叠挤导致溢出条。
        margin: EdgeInsets.fromLTRB(16, 0, 16, 72 + bottomInset),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            unawaited(_vm.unhideConversation(peerId));
          },
        ),
      ),
    );
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

/// SnackBar 文案：`前缀 · Ns`，每秒刷新。
class _CountdownSnackLabel extends StatefulWidget {
  const _CountdownSnackLabel({
    required this.prefix,
    required this.seconds,
  });

  final String prefix;
  final int seconds;

  @override
  State<_CountdownSnackLabel> createState() => _CountdownSnackLabelState();
}

class _CountdownSnackLabelState extends State<_CountdownSnackLabel> {
  late int _left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _left = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_left <= 1) {
        timer.cancel();
        setState(() => _left = 0);
        return;
      }
      setState(() => _left -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suffix = _left > 0 ? ' · ${_left}s' : '';
    return Text(
      '${widget.prefix}$suffix',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
