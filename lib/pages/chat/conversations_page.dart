import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../models/notification.dart';
import '../../models/private_conversation_item.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
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
          final page = await ApiService.listPrivateMessages(
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
          await ApiService.listPrivateConversations(limit: 120, offset: 0);
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

      final friends = await ApiService.getFriends(uid);
      List<PrivateConversationItem> serverConvs = [];
      try {
        final page =
            await ApiService.listPrivateConversations(limit: 120, offset: 0);
        serverConvs = page.items;
      } catch (_) {}

      if (serverConvs.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _friends = friends;
          _serverConversations = serverConvs;
          _notifs = [];
          _loading = false;
        });
        unawaited(_syncLocalThreadTails());
        return;
      }

      // 兜底：服务端尚无会话索引时，用通知 + 本地缓存拼列表（仅拉一页）
      final batch =
          await NotificationService.getNotifications(page: 1, pageSize: 50);
      final allNotifs = List<NotificationModel>.from(batch);

      if (!mounted) return;
      setState(() {
        _friends = friends;
        _notifs = allNotifs;
        _serverConversations = [];
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
            Expanded(child: _buildList(context, localPeers)),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: MoeTokens.cardShadow(
            tint: MoeTheme.of(context).primary,
            blur: 10,
          ),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜索会话、好友昵称或 Moe ID',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: scheme.onSurfaceVariant,
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
        title: const Text('消息'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
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
          separatorBuilder: (_, __) => const SizedBox(height: 8),
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
            return _buildConversationRow(
              context,
              avatar: avatar,
              title: title,
              preview: preview,
              badge: badge,
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
            n.senderId != myId)
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
        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
          final ntTime =
              last?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final previewRaw = () {
            final fromNotif = (last?.content ?? '').trim();
            var bestAt = ntTime;
            var bestRaw = fromNotif;
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
          final preview =
              previewRaw.isEmpty ? '' : formatDmPreviewForUi(previewRaw);
          final badge = pushUnread[peerId] ?? 0;

          return _buildConversationRow(
            context,
            avatar: avatar,
            title: title,
            preview: preview.isEmpty ? '点击开始聊天' : preview,
            badge: badge,
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
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            color: MoeTokens.cardBackground,
            borderRadius: BorderRadius.circular(MoeTokens.radiusCard),
            boxShadow: MoeTokens.cardShadow(blur: 12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                NetworkAvatarImage(
                  imageUrl: avatar,
                  radius: 24,
                  placeholderIcon: Icons.person_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: MoeTokens.titleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MoeTokens.hintText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
