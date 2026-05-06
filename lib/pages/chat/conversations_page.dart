import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../models/notification.dart';
import '../../models/user.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../services/chat_push_service.dart';
import '../../services/direct_chat_local_reader.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../services/notification_service.dart';
import '../../utils/chat_message_display.dart';
import '../../widgets/avatar_image.dart';

/// 会话列表。`embedded: true` 时无 Scaffold，用于嵌在 [FriendsPage] 的 Tab 里。
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  bool _loading = true;
  String? _error;
  List<User> _friends = [];
  List<NotificationModel> _notifs = [];
  /// 与 [DirectChatPage] 本地缓存对齐的最后一条（用于在线聊天未进通知时的预览）
  Map<String, ({DateTime at, String rawPreview})> _localThreadTails = {};

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await AuthService.getUserId();
      if (uid.isEmpty) {
        setState(() {
          _loading = false;
          _error = '请先登录';
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
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
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => unawaited(_load()),
                child: const Text('重试'),
              ),
            ],
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无会话\n在好友或发现里发起聊天后会出现在这里。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    DateTime lastActivity(String peerId) {
      final nt = lastBySender[peerId]?.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final lt = _localThreadTails[peerId]?.at ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return lt.isAfter(nt) ? lt : nt;
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
          final ntTime = last?.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final previewRaw = (lt != null &&
                  lt.rawPreview.isNotEmpty &&
                  lt.at.isAfter(ntTime))
              ? lt.rawPreview
              : (last?.content ?? '').trim();
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
