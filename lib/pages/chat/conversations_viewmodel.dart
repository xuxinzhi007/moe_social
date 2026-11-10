import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../models/private_conversation_item.dart';
import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../services/direct_chat_local_reader.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../services/user_service.dart';

/// 会话列表状态与加载/同步（页面负责列表 UI 与导航，搜索走统一搜索页）。
class ConversationsViewModel extends ChangeNotifier {
  static const int pageSize = 30;

  bool _loading = true;
  Object? _loadError;
  Object? _refreshError;
  Object? _loadMoreError;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _refreshing = false;
  List<User> _friends = [];
  List<PrivateConversationItem> _serverConversations = [];
  Map<String, DateTime> _clearMarkers = {};
  bool _disposed = false;

  bool get loading => _loading;
  Object? get loadError => _loadError;
  Object? get refreshError => _refreshError;
  Object? get loadMoreError => _loadMoreError;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  bool get refreshing => _refreshing;
  List<User> get friends => _friends;
  List<PrivateConversationItem> get serverConversations => _serverConversations;
  Map<String, DateTime> get clearMarkers => _clearMarkers;

  /// 取出并清空一次刷新错误（供页面弹出 SnackBar）。
  Object? takeRefreshError() {
    final err = _refreshError;
    _refreshError = null;
    return err;
  }

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    _refreshError = null;
    _loadMoreError = null;
    _notify();
    try {
      final uid = await AuthService.getUserId();
      if (uid.isEmpty) {
        _loading = false;
        _loadError = '请先登录';
        _notify();
        return;
      }

      await DirectChatLocalReader.releaseMisusedClearMarkers();
      final clearMarkers = _mergeClearMarkers(
        await _loadClearMarkers(uid),
        _clearMarkers,
      );
      final friends = await UserService.getFriends(uid);
      final page = await ChatService.listPrivateConversations(
        limit: pageSize,
        offset: 0,
      );

      if (_disposed) return;
      _friends = friends;
      _serverConversations = page.items;
      _hasMore = page.hasMore;
      _clearMarkers = clearMarkers;
      _loading = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _loading = false;
      _loadError = e;
      _notify();
    }
  }

  /// 软刷新：失败不清空已有列表，错误写入 [refreshError]。
  Future<void> refreshServerConversations({bool reloadFriends = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    _notify();
    try {
      final uid = await AuthService.getUserId();
      List<User>? friends;
      if (reloadFriends && uid.isNotEmpty) {
        friends = await UserService.getFriends(uid);
      }
      final page = await ChatService.listPrivateConversations(
        limit: pageSize,
        offset: 0,
      );
      if (_disposed) return;
      if (friends != null) {
        _friends = friends;
      }
      _serverConversations = page.items;
      _hasMore = page.hasMore;
      _loadMoreError = null;
      _refreshError = null;
      _notify();
    } catch (e) {
      if (_disposed) return;
      // 保留现有列表，只暴露错误。
      _refreshError = e;
      _notify();
    } finally {
      if (!_disposed) {
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _refreshing) return;
    _loadingMore = true;
    _loadMoreError = null;
    _notify();
    try {
      final page = await ChatService.listPrivateConversations(
        limit: pageSize,
        offset: _serverConversations.length,
      );
      if (_disposed) return;
      _serverConversations = _mergeConversations(
        _serverConversations,
        page.items,
      );
      _hasMore = page.hasMore;
      _loadingMore = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _loadingMore = false;
      _loadMoreError = e;
      _notify();
    }
  }

  void clearLoadMoreError() {
    if (_loadMoreError == null) return;
    _loadMoreError = null;
    _notify();
  }

  void onPushUnread() {
    unawaited(refreshServerConversations());
  }

  void onLocalThreadsTick() {
    unawaited(refreshServerConversations());
  }

  bool isAfterClearMarker(String peerId, DateTime time) {
    final clearedAt = _clearMarkers[peerId];
    if (clearedAt == null) return true;
    return time.isAfter(clearedAt);
  }

  /// 会话列表是否展示该 peer（微信式：隐藏后直到有更新活动才再出现）。
  ///
  /// [lastActivityAt] 为该会话最后一条消息时间；无消息时用 epoch。
  bool isPeerVisibleInConversationList(
    String peerId,
    DateTime lastActivityAt,
  ) {
    final trimmed = peerId.trim();
    if (trimmed.isEmpty) return false;
    return isAfterClearMarker(trimmed, lastActivityAt);
  }

  /// 从会话列表隐藏。只记列表标记，不删、不遮聊天记录。
  Future<void> hideConversation(String peerId) async {
    final trimmed = peerId.trim();
    if (trimmed.isEmpty) return;
    final uid = await AuthService.getUserId();
    if (uid.isEmpty) return;

    // marker 至少覆盖当前已知最后活动，避免时钟偏差导致「隐藏后立刻又出现」。
    var marker = DateTime.now();
    for (final c in _serverConversations) {
      if (c.peerUserId.trim() != trimmed) continue;
      final at = DateTime.tryParse(c.lastMessage.createdAt);
      if (at != null && !at.isBefore(marker)) {
        marker = at.add(const Duration(milliseconds: 1));
      }
    }
    final ids = [uid, trimmed]..sort();
    final key = 'direct_chat_hidden_${ids.join('_')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, marker.toIso8601String());

    if (_disposed) return;
    _clearMarkers = Map<String, DateTime>.from(_clearMarkers)
      ..[trimmed] = marker;
    _serverConversations = _serverConversations
        .where((c) => c.peerUserId.trim() != trimmed)
        .toList();
    DirectChatSyncBus.bump();
    _notify();
  }

  /// 撤销 [hideConversation]（去掉列表隐藏标记并刷新）。
  Future<void> unhideConversation(String peerId) async {
    final trimmed = peerId.trim();
    if (trimmed.isEmpty) return;
    final uid = await AuthService.getUserId();
    if (uid.isEmpty) return;

    final ids = [uid, trimmed]..sort();
    final key = 'direct_chat_hidden_${ids.join('_')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);

    if (_disposed) return;
    final nextMarkers = Map<String, DateTime>.from(_clearMarkers)
      ..remove(trimmed);
    _clearMarkers = nextMarkers;
    DirectChatSyncBus.bump();
    await load();
  }

  static List<PrivateConversationItem> _mergeConversations(
    List<PrivateConversationItem> existing,
    List<PrivateConversationItem> incoming,
  ) {
    if (incoming.isEmpty) return existing;
    final seen = <String>{
      for (final c in existing) c.peerUserId.trim(),
    };
    final out = List<PrivateConversationItem>.from(existing);
    for (final c in incoming) {
      final id = c.peerUserId.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(c);
    }
    return out;
  }

  static Map<String, DateTime> _mergeClearMarkers(
    Map<String, DateTime> loaded,
    Map<String, DateTime> inMemory,
  ) {
    final merged = Map<String, DateTime>.from(loaded);
    for (final entry in inMemory.entries) {
      final previous = merged[entry.key];
      if (previous == null || entry.value.isAfter(previous)) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  static Future<Map<String, DateTime>> _loadClearMarkers(String myId) async {
    if (myId.isEmpty) return const {};
    final prefs = await SharedPreferences.getInstance();
    const prefix = 'direct_chat_hidden_';
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
