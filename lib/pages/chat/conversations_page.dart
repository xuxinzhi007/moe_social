import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../models/notification.dart';
import '../../models/private_conversation_item.dart';
import '../../models/user.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../services/chat_push_service.dart';
import '../../services/direct_chat_local_reader.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../services/notification_service.dart';
import '../../providers/main_nav_controller.dart';
import '../../theme/moe_theme_extension.dart';
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
    this.onEmptyFindFriends,
    this.onEmptyExplore,
    this.emptyExploreLabel,
    this.emptyExploreIcon,
  });

  final bool embedded;
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

  /// 与 [DirectChatPage] 本地缓存对齐的最后一条（用于在线聊天未进通知时的预览）
  Map<String, ({DateTime at, String rawPreview})> _localThreadTails = {};

  /// 服务端历史兜底的最后一条（避免仅靠通知/本地缓存导致预览缺失或过旧）。
  Map<String, ({DateTime at, String rawPreview})> _serverThreadTails = {};
  bool _refreshingServerTails = false;
  DateTime? _lastServerTailRefreshAt;

  @override
  void initState() {
    super.initState();
    ChatPushService.unreadBySender.addListener(_onPushUnread);
    DirectChatSyncBus.threadsTick.addListener(_onLocalThreadsTick);
    unawaited(_load());
  }

  @override
  void dispose() {
    ChatPushService.unreadBySender.removeListener(_onPushUnread);
    DirectChatSyncBus.threadsTick.removeListener(_onLocalThreadsTick);
    super.dispose();
  }

  void _onPushUnread() {
    if (mounted) setState(() {});
    unawaited(_syncLocalThreadTails());
    unawaited(_refreshServerConversations());
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
      final allNotifs = <NotificationModel>[];
      for (var p = 1; p <= 3; p++) {
        final batch =
            await NotificationService.getNotifications(page: p, pageSize: 50);
        if (batch.isEmpty) break;
        allNotifs.addAll(batch);
      }

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

      unawaited(
        context.read<NotificationProvider>().fetchNotifications(refresh: true),
      );
      unawaited(_syncLocalThreadTails());
      unawaited(_refreshServerThreadTails(force: true));
      unawaited(_refreshServerConversations());
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
        return _buildList(context, localPeers);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (widget.embedded) {
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
    final pushUnread = ChatPushService.unreadBySender.value;

    if (_serverConversations.isNotEmpty) {
      final rows = List<PrivateConversationItem>.from(_serverConversations);
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
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
            return ListTile(
              leading: NetworkAvatarImage(
                imageUrl: avatar,
                radius: 22,
                placeholderIcon: Icons.person,
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: badge > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
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
                    )
                  : null,
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
          subtitle: '去同好列表找好友，或先在首页逛逛新内容',
          primaryAction: MoeEmptyStateAction(
            label: '去找同好',
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) {
          final peerId = rows[i];
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

          return ListTile(
            leading: NetworkAvatarImage(
              imageUrl: avatar,
              radius: 22,
              placeholderIcon: Icons.person,
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              preview.isEmpty ? '点击开始聊天' : preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: badge > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
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
                  )
                : null,
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
}
