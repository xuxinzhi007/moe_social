import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../models/private_message_item.dart';
import '../../services/api_client.dart' show ApiException;
import '../../services/chat_push_service.dart';
import '../../services/chat_service.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../utils/media_url.dart';
import '../../utils/moe_error_copy.dart';

/// 私信气泡数据（本地缓存 + 服务端展开共用）。
class DirectChatMessage {
  const DirectChatMessage({
    required this.senderId,
    required this.content,
    required this.time,
    this.serverId,
  });

  final String senderId;
  final String content;
  final DateTime time;

  /// 与服务端行对应的去重键（REST 展开为 `id#t` / `id#i0`；WS 对齐同规则）。
  final String? serverId;
}

/// 私信会话状态与 IO（页面只负责 UI / 导航 / 控制器）。
class DirectChatViewModel extends ChangeNotifier {
  DirectChatViewModel({required this.peerUserId});

  final String peerUserId;

  static const String imagePrefix = '[IMG]';

  final List<DirectChatMessage> _messages = [];
  String? _currentUserId;
  bool _isSending = false;
  bool _isBootstrapping = true;
  bool _hasMoreServer = false;
  bool _loadingServerPage = false;
  String? _oldestServerCursorId;
  DateTime? _clearedAt;
  Object? _bootstrapError;
  String? _historySyncWarning;
  bool _disposed = false;

  /// 页面在 initState 赋值；VM 在消息变更后请求滚到底。
  void Function()? onScrollToBottom;

  List<DirectChatMessage> get messages => List.unmodifiable(_messages);
  String? get currentUserId => _currentUserId;
  bool get isSending => _isSending;
  bool get isBootstrapping => _isBootstrapping;
  bool get hasMoreServer => _hasMoreServer;
  bool get loadingServerPage => _loadingServerPage;
  Object? get bootstrapError => _bootstrapError;
  String? get historySyncWarning => _historySyncWarning;
  bool get isEmpty => _messages.isEmpty;

  bool isImageContent(String content) =>
      content.startsWith(imagePrefix) && content.length > imagePrefix.length;

  String imageUrlOf(String content) => resolveMediaUrl(
        content.substring(imagePrefix.length).trim(),
      );

  Future<void> bootstrap() async {
    _isBootstrapping = true;
    _bootstrapError = null;
    _historySyncWarning = null;
    _notify();
    try {
      final userId = await AuthService.getUserId();
      if (_disposed) return;
      _currentUserId = userId;
      _clearedAt = await _loadClearedAt(userId);
      await _loadLocalMessages(userId);
      await _fetchInitialServerHistory();
      mergePendingWsMessages();
      _notify();
      onScrollToBottom?.call();
    } catch (e) {
      if (_disposed) return;
      _bootstrapError = e;
      _notify();
    } finally {
      if (!_disposed) {
        _isBootstrapping = false;
        _notify();
      }
    }
  }

  void consumeHistorySyncWarning() {
    _historySyncWarning = null;
  }

  void mergePendingWsMessages() {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      final pending = ChatPushService.takePendingMessages(peerUserId);
      if (pending.isEmpty) return;

      final existingKeys = <String>{};
      for (final m in _messages) {
        existingKeys
            .add('${m.senderId}|${m.time.toIso8601String()}|${m.content}');
      }

      var changed = false;
      for (final map in pending) {
        final from = map['from']?.toString();
        final content = map['content']?.toString();
        final ts = map['timestamp'];
        if (from == null || from.isEmpty || content == null) continue;
        if (from != peerUserId) continue;

        DateTime time;
        if (ts is int) {
          time = DateTime.fromMillisecondsSinceEpoch(ts);
        } else {
          time = DateTime.now();
        }
        if (!_isAfterClearMarker(time)) continue;

        final hasSimilar = _messages.any((m) {
          if (m.senderId != from) return false;
          if (m.content != content) return false;
          final diff = m.time.difference(time).inMinutes.abs();
          return diff <= 5;
        });
        if (hasSimilar) continue;

        final key = '$from|${time.toIso8601String()}|$content';
        if (existingKeys.contains(key)) continue;
        existingKeys.add(key);
        _messages.add(
          DirectChatMessage(senderId: from, content: content, time: time),
        );
        changed = true;
      }

      if (changed) {
        _messages.sort((a, b) => a.time.compareTo(b.time));
        unawaited(_saveMessages());
        _notify();
        onScrollToBottom?.call();
      }
      ChatPushService.markSenderRead(peerUserId);
    } catch (_) {}
  }

  Future<void> loadOlderServerPage() async {
    final cursor = _oldestServerCursorId;
    if (cursor == null || cursor.isEmpty || !_hasMoreServer) return;
    if (_loadingServerPage) return;
    _loadingServerPage = true;
    _historySyncWarning = null;
    _notify();
    try {
      final page = await ChatService.listPrivateMessages(
        peerUserId: peerUserId,
        beforeId: cursor,
        limit: 30,
      );
      if (_disposed) return;
      final add = <DirectChatMessage>[];
      for (final m in page.items) {
        add.addAll(_expandServerItem(m));
      }
      add.removeWhere((m) => !_isAfterClearMarker(m.time));
      final existing = <String>{};
      for (final x in _messages) {
        if (x.serverId != null) existing.add(x.serverId!);
      }
      final novel = <DirectChatMessage>[];
      for (final x in add) {
        if (x.serverId != null && existing.contains(x.serverId!)) continue;
        if (x.serverId != null) existing.add(x.serverId!);
        novel.add(x);
      }
      _messages.insertAll(0, novel);
      _messages.sort((a, b) => a.time.compareTo(b.time));
      _hasMoreServer = page.hasMore;
      if (page.items.isNotEmpty) {
        _oldestServerCursorId = page.items.first.id;
      }
      await _saveMessages();
    } catch (e) {
      if (!_disposed) {
        _historySyncWarning =
            MoeErrorCopy.toast(e, scene: MoeErrorScene.messages);
      }
    } finally {
      if (!_disposed) {
        _loadingServerPage = false;
        _notify();
      }
    }
  }

  void handleIncomingMap(Map<String, dynamic> map) {
    try {
      final from = map['from']?.toString();
      final content = map['content']?.toString();
      final timestamp = map['timestamp'];
      if (from == null || from.isEmpty || content == null) return;
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;
      if (from != peerUserId) return;

      DateTime time;
      if (timestamp is int) {
        time = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is num) {
        time = DateTime.fromMillisecondsSinceEpoch(timestamp.round());
      } else if (map['time'] is String) {
        time = DateTime.tryParse(map['time'] as String) ?? DateTime.now();
      } else {
        time = DateTime.now();
      }
      if (!_isAfterClearMarker(time)) return;
      final sid = _serverSlotFromWsId(map['server_message_id'], content);
      _messages.add(
        DirectChatMessage(
          senderId: from,
          content: content,
          time: time,
          serverId: sid,
        ),
      );
      unawaited(_saveMessages());
      _notify();
      onScrollToBottom?.call();
      ChatPushService.markSenderRead(peerUserId);
    } catch (_) {}
  }

  /// 成功返回 null；失败返回用户可读错误文案。
  Future<String?> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return null;
    final currentUserId = _currentUserId;
    if (currentUserId == null) return '请先登录';

    _isSending = true;
    _messages.add(
      DirectChatMessage(
        senderId: currentUserId,
        content: trimmed,
        time: DateTime.now(),
      ),
    );
    _notify();
    await _saveMessages();
    onScrollToBottom?.call();
    final optimisticIdx = _messages.length - 1;

    try {
      final saved = await ChatService.sendPrivateMessage(
        receiverId: peerUserId,
        body: trimmed,
      );
      if (_disposed) return null;
      if (optimisticIdx < _messages.length &&
          _messages[optimisticIdx].senderId == currentUserId &&
          _messages[optimisticIdx].content == trimmed) {
        _messages[optimisticIdx] = DirectChatMessage(
          senderId: currentUserId,
          content: trimmed,
          time: _messages[optimisticIdx].time,
          serverId: _serverSlotFromWsId(saved.id, trimmed),
        );
      }
      _isSending = false;
      await _saveMessages();
      _notify();
      return null;
    } on ApiException catch (e) {
      _rollbackOptimistic(optimisticIdx, currentUserId, trimmed);
      return MoeErrorCopy.toast(e, scene: MoeErrorScene.messages);
    } catch (e) {
      _rollbackOptimistic(optimisticIdx, currentUserId, trimmed);
      return MoeErrorCopy.toast(e, scene: MoeErrorScene.messages);
    }
  }

  /// 成功返回 null；失败返回用户可读错误文案。
  Future<String?> sendImageFile(File file) async {
    if (_isSending) return null;
    final currentUserId = _currentUserId;
    if (currentUserId == null) return '请先登录';
    if (!await file.exists()) return '图片文件不存在';

    _isSending = true;
    _notify();
    try {
      final url = await ChatService.uploadImage(file);
      final content = '$imagePrefix$url';
      if (_disposed) return null;

      _messages.add(
        DirectChatMessage(
          senderId: currentUserId,
          content: content,
          time: DateTime.now(),
        ),
      );
      await _saveMessages();
      _notify();
      onScrollToBottom?.call();

      final optimisticIdx = _messages.length - 1;
      try {
        final saved = await ChatService.sendPrivateMessage(
          receiverId: peerUserId,
          body: content,
        );
        if (_disposed) return null;
        if (optimisticIdx < _messages.length &&
            _messages[optimisticIdx].senderId == currentUserId &&
            _messages[optimisticIdx].content == content) {
          _messages[optimisticIdx] = DirectChatMessage(
            senderId: currentUserId,
            content: content,
            time: _messages[optimisticIdx].time,
            serverId: _serverSlotFromWsId(saved.id, content),
          );
        }
        _isSending = false;
        await _saveMessages();
        _notify();
        return null;
      } on ApiException catch (e) {
        _rollbackOptimistic(optimisticIdx, currentUserId, content);
        return MoeErrorCopy.toast(e, scene: MoeErrorScene.messages);
      } catch (e) {
        _rollbackOptimistic(optimisticIdx, currentUserId, content);
        return MoeErrorCopy.toast(e, scene: MoeErrorScene.messages);
      }
    } catch (e) {
      if (!_disposed) {
        _isSending = false;
        _notify();
      }
      return MoeErrorCopy.toast(e, scene: MoeErrorScene.messages);
    }
  }

  Future<String?> clearLocalChatHistory() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return '请先登录';
    try {
      await ChatService.clearPrivateChatHistory(peerUserId: peerUserId);
    } catch (_) {
      // 服务端清理失败仍清本地，避免卡死。
    }
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clearMarkerKey(currentUserId),
      now.toIso8601String(),
    );
    await prefs.remove(_storageKey(currentUserId));
    if (_disposed) return null;
    _clearedAt = now;
    _messages.clear();
    _hasMoreServer = false;
    _oldestServerCursorId = null;
    DirectChatSyncBus.bump();
    _notify();
    return null;
  }

  void _rollbackOptimistic(int idx, String userId, String content) {
    if (_disposed) return;
    if (idx < _messages.length &&
        _messages[idx].senderId == userId &&
        _messages[idx].content == content) {
      _messages.removeAt(idx);
    }
    _isSending = false;
    unawaited(_saveMessages());
    _notify();
  }

  Future<void> _fetchInitialServerHistory() async {
    try {
      final page = await ChatService.listPrivateMessages(
        peerUserId: peerUserId,
        limit: 40,
      );
      if (_disposed) return;
      final expanded = <DirectChatMessage>[];
      for (final m in page.items) {
        expanded.addAll(_expandServerItem(m));
      }
      expanded.removeWhere((m) => !_isAfterClearMarker(m.time));
      final localCopy = List<DirectChatMessage>.from(_messages);
      _applyMergedLocalAndServer(localCopy, expanded);
      _hasMoreServer = page.hasMore;
      _oldestServerCursorId =
          page.items.isNotEmpty ? page.items.first.id : null;
      await _saveMessages();
    } on ApiException catch (e) {
      _historySyncWarning =
          '服务端聊天记录同步失败：${e.message}\n若刚升级后端，请确认已部署 /api/private-messages 并执行迁移。';
    } catch (_) {}
  }

  Future<void> _loadLocalMessages(String currentUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(currentUserId));
    if (raw == null || raw.isEmpty) return;
    final list = json.decode(raw) as List<dynamic>;
    final messages = list
        .map((item) {
          final map = item as Map<String, dynamic>;
          final sid = map['serverId']?.toString();
          return DirectChatMessage(
            senderId: map['senderId'] as String,
            content: map['content'] as String,
            time: DateTime.tryParse(map['time'] as String? ?? '') ??
                DateTime.now(),
            serverId: sid != null && sid.isNotEmpty ? sid : null,
          );
        })
        .where((m) => _isAfterClearMarker(m.time))
        .toList();
    if (_disposed) return;
    _messages
      ..clear()
      ..addAll(messages);
  }

  Future<void> _saveMessages() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final list = _messages
        .map((m) => {
              'senderId': m.senderId,
              'content': m.content,
              'time': m.time.toIso8601String(),
              if (m.serverId != null) 'serverId': m.serverId,
            })
        .toList();
    await prefs.setString(_storageKey(currentUserId), json.encode(list));
    DirectChatSyncBus.bump();
  }

  List<DirectChatMessage> _expandServerItem(PrivateMessageItem m) {
    final t = DateTime.tryParse(m.createdAt) ?? DateTime.now();
    final out = <DirectChatMessage>[];
    final body = m.body.trim();
    if (body.isNotEmpty) {
      out.add(DirectChatMessage(
        senderId: m.senderId,
        content: body,
        time: t,
        serverId: '${m.id}#t',
      ));
    }
    for (var i = 0; i < m.imagePaths.length; i++) {
      final name = m.imagePaths[i].trim();
      if (name.isEmpty) continue;
      final url = resolveMediaUrl('/api/images/$name');
      out.add(DirectChatMessage(
        senderId: m.senderId,
        content: '$imagePrefix$url',
        time: t,
        serverId: '${m.id}#i$i',
      ));
    }
    return out;
  }

  void _applyMergedLocalAndServer(
    List<DirectChatMessage> local,
    List<DirectChatMessage> serverExpanded,
  ) {
    final merged = <DirectChatMessage>[];
    final seen = <String>{};
    for (final s in serverExpanded) {
      merged.add(s);
      if (s.serverId != null) seen.add(s.serverId!);
    }
    for (final l in local) {
      if (l.serverId != null) {
        if (seen.contains(l.serverId!)) continue;
        seen.add(l.serverId!);
        merged.add(l);
        continue;
      }
      final dup = serverExpanded.any((s) =>
          s.senderId == l.senderId &&
          s.content == l.content &&
          s.time.difference(l.time).inSeconds.abs() < 120);
      if (dup) continue;
      merged.add(l);
    }
    merged.sort((a, b) => a.time.compareTo(b.time));
    _messages
      ..clear()
      ..addAll(merged);
  }

  String? _serverSlotFromWsId(dynamic rawId, String content) {
    if (rawId == null) return null;
    final id = rawId.toString();
    if (id.isEmpty) return null;
    if (content.startsWith(imagePrefix)) return '$id#i0';
    return '$id#t';
  }

  String _storageKey(String currentUserId) {
    final ids = [currentUserId, peerUserId]..sort();
    return 'direct_chat_${ids.join('_')}';
  }

  String _clearMarkerKey(String currentUserId) {
    final ids = [currentUserId, peerUserId]..sort();
    return 'direct_chat_cleared_${ids.join('_')}';
  }

  Future<DateTime?> _loadClearedAt(String currentUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clearMarkerKey(currentUserId));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool _isAfterClearMarker(DateTime time) {
    final clearedAt = _clearedAt;
    if (clearedAt == null) return true;
    return time.isAfter(clearedAt);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    onScrollToBottom = null;
    super.dispose();
  }
}
