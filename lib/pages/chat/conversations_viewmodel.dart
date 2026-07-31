import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../models/notification.dart';
import '../../models/private_conversation_item.dart';
import '../../models/user.dart';
import '../../services/chat_push_service.dart';
import '../../services/chat_service.dart';
import '../../services/direct_chat_local_reader.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../utils/chat_message_display.dart';

/// 会话列表状态与加载/同步（页面只负责搜索框、列表 UI、导航）。
class ConversationsViewModel extends ChangeNotifier {
  bool _loading = true;
  Object? _loadError;
  List<User> _friends = [];
  List<NotificationModel> _notifs = [];
  List<PrivateConversationItem> _serverConversations = [];
  String _searchQuery = '';
  Map<String, ({DateTime at, String rawPreview})> _localThreadTails = {};
  Map<String, ({DateTime at, String rawPreview})> _serverThreadTails = {};
  bool _refreshingServerTails = false;
  DateTime? _lastServerTailRefreshAt;
  Map<String, DateTime> _clearMarkers = {};
  Set<String> _localPeers = {};
  bool _disposed = false;

  bool get loading => _loading;
  Object? get loadError => _loadError;
  List<User> get friends => _friends;
  List<NotificationModel> get notifs => _notifs;
  List<PrivateConversationItem> get serverConversations => _serverConversations;
  String get searchQuery => _searchQuery;
  Map<String, ({DateTime at, String rawPreview})> get localThreadTails =>
      _localThreadTails;
  Map<String, ({DateTime at, String rawPreview})> get serverThreadTails =>
      _serverThreadTails;
  Map<String, DateTime> get clearMarkers => _clearMarkers;
  Set<String> get localPeers => _localPeers;

  void updateSearchQuery(String query) {
    final next = query.trim();
    if (next == _searchQuery) return;
    _searchQuery = next;
    _notify();
  }

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    _notify();
    try {
      final uid = await AuthService.getUserId();
      if (uid.isEmpty) {
        _loading = false;
        _loadError = '请先登录';
        _notify();
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

      final localPeers = await localChatPeerIds(uid);

      if (serverConvs.isNotEmpty) {
        if (_disposed) return;
        _friends = friends;
        _serverConversations = serverConvs;
        _notifs = [];
        _clearMarkers = clearMarkers;
        _localPeers = localPeers;
        _loading = false;
        _notify();
        unawaited(syncLocalThreadTails());
        return;
      }

      final batch =
          await NotificationService.getNotifications(page: 1, pageSize: 50);
      final allNotifs = List<NotificationModel>.from(batch);

      if (_disposed) return;
      _friends = friends;
      _notifs = allNotifs;
      _serverConversations = [];
      _clearMarkers = clearMarkers;
      _localPeers = localPeers;
      _loading = false;
      _notify();

      final dmForWarm = allNotifs
          .where((n) =>
              n.type == NotificationModel.directMessage &&
              (n.senderId ?? '').isNotEmpty &&
              n.senderId != uid)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final lastBySid = <String, NotificationModel>{};
      for (final n in dmForWarm) {
        lastBySid.putIfAbsent(n.senderId!, () => n);
      }
      for (final e in lastBySid.entries) {
        final sid = e.key;
        final n = e.value;
        final hasFriend = friends.any((f) => f.id == sid);
        if (!hasFriend && looksLikeMoeNoOrWeakSenderLabel(n.senderName ?? '')) {
          unawaited(ChatPushService.prefetchSenderDisplayName(sid).then((_) {
            _notify();
          }));
        }
      }

      unawaited(syncLocalThreadTails());
      unawaited(refreshServerThreadTails(force: true));
    } catch (e) {
      if (_disposed) return;
      _loading = false;
      _loadError = e;
      _notify();
    }
  }

  Future<void> syncLocalThreadTails() async {
    final myId = await AuthService.getUserId();
    if (myId.isEmpty) return;
    final next = await DirectChatLocalReader.readThreadTails(myId);
    final peers = await localChatPeerIds(myId);
    if (_disposed) return;
    _localThreadTails = next;
    _localPeers = peers;
    _notify();
  }

  Future<void> refreshServerConversations() async {
    try {
      final page =
          await ChatService.listPrivateConversations(limit: 120, offset: 0);
      if (_disposed) return;
      _serverConversations = page.items;
      _notify();
    } catch (_) {}
  }

  Future<void> refreshServerThreadTails({bool force = false}) async {
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
      if (_disposed) return;
      _serverThreadTails = next;
      _lastServerTailRefreshAt = DateTime.now();
      _notify();
    } finally {
      _refreshingServerTails = false;
    }
  }

  void onPushUnread() {
    _notify();
    unawaited(syncLocalThreadTails());
    unawaited(refreshServerConversations());
    if (_serverConversations.isEmpty) {
      unawaited(refreshServerThreadTails());
    }
  }

  void onLocalThreadsTick() {
    unawaited(syncLocalThreadTails());
  }

  bool isAfterClearMarker(String peerId, DateTime time) {
    final clearedAt = _clearMarkers[peerId];
    if (clearedAt == null) return true;
    return time.isAfter(clearedAt);
  }

  /// 从会话列表隐藏（写 clear marker，与私信页清空历史同键）。
  Future<void> hideConversation(String peerId) async {
    final trimmed = peerId.trim();
    if (trimmed.isEmpty) return;
    final uid = await AuthService.getUserId();
    if (uid.isEmpty) return;

    final now = DateTime.now();
    final ids = [uid, trimmed]..sort();
    final key = 'direct_chat_cleared_${ids.join('_')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, now.toIso8601String());

    if (_disposed) return;
    _clearMarkers = Map<String, DateTime>.from(_clearMarkers)..[trimmed] = now;
    _serverConversations = _serverConversations
        .where((c) => c.peerUserId.trim() != trimmed)
        .toList();
    _localPeers = Set<String>.from(_localPeers)..remove(trimmed);
    _localThreadTails = Map<String, ({DateTime at, String rawPreview})>.from(
      _localThreadTails,
    )..remove(trimmed);
    _serverThreadTails = Map<String, ({DateTime at, String rawPreview})>.from(
      _serverThreadTails,
    )..remove(trimmed);
    DirectChatSyncBus.bump();
    _notify();
  }

  /// 撤销 [hideConversation]（删除 clear marker 并刷新列表）。
  Future<void> unhideConversation(String peerId) async {
    final trimmed = peerId.trim();
    if (trimmed.isEmpty) return;
    final uid = await AuthService.getUserId();
    if (uid.isEmpty) return;

    final ids = [uid, trimmed]..sort();
    final key = 'direct_chat_cleared_${ids.join('_')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);

    if (_disposed) return;
    final nextMarkers = Map<String, DateTime>.from(_clearMarkers)
      ..remove(trimmed);
    _clearMarkers = nextMarkers;
    DirectChatSyncBus.bump();
    await load();
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

  static Future<Set<String>> localChatPeerIds(String myId) async {
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

  static Future<Map<String, DateTime>> _loadClearMarkers(String myId) async {
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
