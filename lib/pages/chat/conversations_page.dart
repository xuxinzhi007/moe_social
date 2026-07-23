import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../models/notification.dart';
import '../../models/private_conversation_item.dart';
import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../services/chat_push_service.dart';
import '../../services/direct_chat_local_reader.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../services/notification_service.dart';
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
  bool _loading = true;
  Object? _loadError;
  List<User> _friends = [];
  List<NotificationModel> _notifs = [];
  List<PrivateConversationItem> _serverConversations = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// 与 [DirectChatPage] 本地缓存对齐的最后一条（用于在线聊天未进通知时的预览）
  Map<String, ({DateTime at, String rawPreview})> _localThreadTails = {};

  /// 服务端历史兜底的最后一条（避免仅靠通知/本地缓存导致预览缺失或过旧）。
  Map<String, ({DateTime at, String rawPreview})> _serverThreadTails = {};
  bool _refreshingServerTails = false;
  DateTime? _lastServerTailRefreshAt;
  Map<String, DateTime> _clearMarkers = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    ChatPushService.unreadBySender.addListener(_onPushUnread);
    DirectChatSyncBus.threadsTick.addListener(_onLocalThreadsTick);
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    ChatPushService.unreadBySender.removeListener(_onPushUnread);
    DirectChatSyncBus.threadsTick.removeListener(_onLocalThreadsTick);
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  void _onPushUnread() {
    if (mounted) setState(() {});
    unawaited(_syncLocalThreadTails());
    unawaited(_refreshServerConversations());
    if (_serverConversations.isEmpty) {
      unawaited(_refreshServerThreadTails());
    }
  }

  void _onLocalThreadsTick() {
    unawaited(_syncLocalThreadTails());
  }

  Future<void> _syncLocalThreadTails() async {
    final myId = await AuthService.getUserId();
    if (myId.isEmpty) return;
    final next = await DirectChatLocalReader.readThreadTails(myId);
    if (!mounted) return;
    setState(() => _localThreadTails = next);
  }

  Set<String> _collectPeerIdsForServerTail(String myId) {
    final out = <String>{};
    for (final f in _friends) {
      if (f.id.isNotEmpty) out.add(f.id);
    }
    for (final sender in ChatPushService.unreadBySender.value.keys) {
      if (sender.isNotEmpty) out.add(sender);
    }
    for (final n in _notifs) {
      if (n.type != NotificationModel.directMessage) continue;
      final sid = (n.senderId ?? '').trim();
      if (sid.isEmpty) continue;
      out.add(sid);
    }
    out.remove(myId);
    out.removeWhere((e) => e.trim().isEmpty);
    return out;
  }

  Future<void> _refreshServerThreadTails({bool force = false}) async {
    final myId = await AuthService.getUserId();
    if (myId.isEmpty) return;
    if (_refreshingServerTails) return;
    final lastAt = _lastServerTailRefreshAt;
    if (!force &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < const Duration(seconds: 25)) {
      return;
    }

    final peers = _collectPeerIdsForServerTail(myId).toList();
    if (peers.isEmpty) return;
    if (peers.length > 24) {
      peers.sort();
      peers.removeRange(24, peers.length);
    }

    _refreshingServerTails = true;
    try {
      final next = Map<String, ({DateTime at, String rawPreview})>.from(
        _serverThreadTails,
      );
      for (final peerId in peers) {
        try {
          final page = await ChatService.listPrivateMessages(
            peerUserId: peerId,
            limit: 1,
          );
          if (page.items.isEmpty) continue;
          final item = page.items.first;
          final at = DateTime.tryParse(item.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          var rawPreview = item.body.trim();
          if (rawPreview.isEmpty && item.imagePaths.isNotEmpty) {
            rawPreview = '[IMG]';
          }
          if (rawPreview.isEmpty) continue;
          final prev = next[peerId];
          if (prev == null || at.isAfter(prev.at)) {
            next[peerId] = (at: at, rawPreview: rawPreview);
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _serverThreadTails = next;
        _lastServerTailRefreshAt = DateTime.now();
      });
    } finally {
      _refreshingServerTails = false;
    }
  }

  Future<void> _refreshServerConversations() async {
    try {
      final page =
          await ChatService.listPrivateConversations(limit: 120, offset: 0);
      if (!mounted) return;
      setState(() {
        _serverConversations = page.items;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final uid = await AuthService.getUserId();
      if (uid.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = '请先登录';
        });
        return;
      }

      final clearMarkers = await _loadClearMarkers(uid);
      final friends = await UserService.getFriends(uid);
      List<PrivateConversationItem> serverConvs = [];
      try {
        final page =
            await ChatService.listPrivateConversations(limit: 120, offset: 0);
        serverConvs = page.items;
      } catch (_) {}

      if (serverConvs.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _friends = friends;
          _serverConversations = serverConvs;
          _notifs = [];
          _clearMarkers = clearMarkers;
          _loading = false;
        });
        unawaited(_syncLocalThreadTails());
        return;
      }

      // 兜底：服务端尚无会话索引时，通知只用于提供会话入口，不作为聊天正文来源。
      final batch =
          await NotificationService.getNotifications(page: 1, pageSize: 50);
      final allNotifs = List<NotificationModel>.from(batch);

      if (!mounted) return;
      setState(() {
        _friends = friends;
        _notifs = allNotifs;
        _serverConversations = [];
        _clearMarkers = clearMarkers;
        _loading = false;
      });

      final dmForWarm = allNotifs
          .where((n) =>
              n.type == NotificationModel.directMessage &&
              (n.senderId ?? '').isNotEmpty &&
              n.senderId != uid)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final lastBySid = <String, NotificationModel>{};
      for (final n in dmForWarm) {
        final sid = n.senderId!;
        lastBySid.putIfAbsent(sid, () => n);
      }
      for (final e in lastBySid.entries) {
        final sid = e.key;
        final n = e.value;
        final hasFriend = friends.any((f) => f.id == sid);
        if (!hasFriend && looksLikeMoeNoOrWeakSenderLabel(n.senderName ?? '')) {
          unawaited(ChatPushService.prefetchSenderDisplayName(sid).then((_) {
            if (mounted) setState(() {});
          }));
        }
      }

      unawaited(_syncLocalThreadTails());
      unawaited(_refreshServerThreadTails(force: true));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<Set<String>> _localChatPeerIds(String myId) async {
    final prefs = await SharedPreferences.getInstance();
    const prefix = 'direct_chat_';
    final out = <String>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final rest = k.substring(prefix.length);
      final parts = rest.split('_');
      if (parts.length != 2) continue;
      final a = parts[0];
      final b = parts[1];
      if (a == myId) {
        out.add(b);
      } else if (b == myId) {
        out.add(a);
      }
    }
    return out;
  }

  Future<Map<String, DateTime>> _loadClearMarkers(String myId) async {
    if (myId.isEmpty) return const {};
    final prefs = await SharedPreferences.getInstance();
    const prefix = 'direct_chat_cleared_';
    final out = <String, DateTime>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final rest = k.substring(prefix.length);
      final parts = rest.split('_');
      if (parts.length != 2) continue;
      final a = parts[0];
      final b = parts[1];
      final peerId = a == myId ? b : (b == myId ? a : '');
      if (peerId.isEmpty || peerId == myId) continue;
      final at = DateTime.tryParse(prefs.getString(k) ?? '');
      if (at != null) out[peerId] = at;
    }
    return out;
  }

  bool _isAfterClearMarker(String peerId, DateTime time) {
    final clearedAt = _clearMarkers[peerId];
    if (clearedAt == null) return true;
    return time.isAfter(clearedAt);
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(child: MoeLoading(color: MoeTheme.of(context).primary));
    }
    if (_loadError != null) {
      return Center(
        child: MoeErrorState.fromError(
          _loadError,
          scene: MoeErrorScene.messages,
          variant: MoeErrorVariant.plain,
          onRetry: () => unawaited(_load()),
        ),
      );
    }
    return FutureBuilder<Set<String>>(
      future: _localChatPeerIds(AuthService.currentUser ?? ''),
      builder: (context, snap) {
        final localPeers = snap.data ?? {};
        return Column(
          children: [
            _buildSearchBar(context),
            const SizedBox(height: 8),
            _buildConversationOverview(context),
            const SizedBox(height: 12),
            Expanded(child: _buildList(context, localPeers)),
          ],
        );
      },
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
            suffixIcon: _searchQuery.isEmpty
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

  Widget _buildConversationOverview(BuildContext context) {
    final unreadMap = context.watch<NotificationProvider>().unreadDmBySender;
    final unreadCount =
        unreadMap.values.fold<int>(0, (sum, value) => sum + value);
    final conversationCount = _serverConversations.isNotEmpty
        ? _serverConversations.length
        : (_friends.isEmpty ? _notifs.length : _friends.length);
    final quickFriends = _friends.take(6).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowCard(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      label: '会话',
                      value: '$conversationCount',
                      icon: Icons.forum_rounded,
                      tint: MoeTokens.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatTile(
                      label: '未读',
                      value: '$unreadCount',
                      icon: Icons.mark_chat_unread_rounded,
                      tint: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatTile(
                      label: '好友',
                      value: '${_friends.length}',
                      icon: Icons.people_rounded,
                      tint: Colors.teal,
                    ),
                  ),
                ],
              ),
              if (quickFriends.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '最近联系人',
                        style: TextStyle(
                          color: MoeTokens.titleText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          context.read<MainNavController>().requestTab(1),
                      icon:
                          const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: const Text('找好友'),
                      style: TextButton.styleFrom(
                        foregroundColor: MoeTokens.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: quickFriends.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final friend = quickFriends[index];
                      return GestureDetector(
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            '/direct-chat',
                            arguments: {
                              'userId': friend.id,
                              'username': friend.username,
                              'avatar': friend.avatar,
                            },
                          );
                          if (mounted) await _load();
                        },
                        child: Container(
                          width: 68,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              NetworkAvatarImage(
                                  imageUrl: friend.avatar, radius: 24),
                              const SizedBox(height: 8),
                              Text(
                                friend.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: MoeTokens.titleText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MoeTokens.titleText,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
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
                onPressed: _loading ? null : () => unawaited(_load()),
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
            onPressed: _loading ? null : () => unawaited(_load()),
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
    final query = _searchQuery.toLowerCase();

    if (_serverConversations.isNotEmpty) {
      final rows =
          List<PrivateConversationItem>.from(_serverConversations).where((c) {
        final lastAt = DateTime.tryParse(c.lastMessage.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (!_isAfterClearMarker(c.peerUserId.trim(), lastAt)) return false;
        if (query.isEmpty) return true;
        final peerId = c.peerUserId.trim().toLowerCase();
        final peerName = c.peerName.trim().toLowerCase();
        final friend = _friends.cast<User?>().firstWhere(
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
        onRefresh: _load,
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
            for (final u in _friends) {
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
                if (mounted) await _load();
              },
            );
          },
        ),
      );
    }

    final dmNotifs = _notifs
        .where((n) =>
            n.type == NotificationModel.directMessage &&
            (n.senderId ?? '').isNotEmpty &&
            n.senderId != myId &&
            _isAfterClearMarker(n.senderId!, n.createdAt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final lastBySender = <String, NotificationModel>{};
    for (final n in dmNotifs) {
      final sid = n.senderId!;
      lastBySender.putIfAbsent(sid, () => n);
    }

    final peerIds = <String>{};
    for (final f in _friends) {
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
          subtitle: '和同好打个招呼，或先在「同好」里添加好友',
          primaryAction: MoeEmptyStateAction(
            label: '去看同好',
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
      final lt = _localThreadTails[peerId]?.at ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final st = _serverThreadTails[peerId]?.at ??
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
      for (final u in _friends) {
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
      onRefresh: _load,
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
          for (final u in _friends) {
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
          final lt = _localThreadTails[peerId];
          final st = _serverThreadTails[peerId];
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

          return _buildConversationRow(
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
              if (mounted) await _load();
            },
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: Ink(
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
                            color: Colors.white,
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
