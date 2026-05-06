import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth_service.dart';
import '../../widgets/moe_toast.dart';
import '../../services/api_service.dart';
import '../../widgets/avatar_image.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/chat_push_service.dart';
import '../../services/direct_chat_sync_bus.dart';
import '../../services/presence_service.dart';
import '../../services/notification_service.dart';
import '../../models/notification.dart';
import '../../utils/media_url.dart';
import '../../models/private_message_item.dart';
class DirectChatPage extends StatefulWidget {
  final String userId;
  final String username;
  final String avatar;

  const DirectChatPage({
    super.key,
    required this.userId,
    required this.username,
    required this.avatar,
  });

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage> {
  final List<_DirectMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isSending = false;
  String? _currentUserId;
  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  bool _peerOnline = false;
  Timer? _onlineTimer;
  bool _presenceListening = false;
  bool _hasMoreServer = false;
  bool _loadingServerPage = false;
  String? _oldestServerCursorId;
  late final VoidCallback _scrollLoadOlderListener;

  @override
  void initState() {
    super.initState();
    _scrollLoadOlderListener = () {
      if (!_scrollController.hasClients) return;
      if (!_hasMoreServer || _loadingServerPage) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 100) {
        unawaited(_loadOlderServerPage());
      }
    };
    _scrollController.addListener(_scrollLoadOlderListener);
    _initChat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_presenceListening) return;
    _presenceListening = true;
    PresenceService.start();
    PresenceService.online.addListener(_onPresenceUpdate);
  }

  void _onPresenceUpdate() {
    if (!mounted) return;
    final map = PresenceService.online.value;
    final online = map[widget.userId] ?? false;
    if (_peerOnline != online) {
      setState(() {
        _peerOnline = online;
      });
    }
    if (PresenceService.isConnected && map.isNotEmpty) {
      _onlineTimer?.cancel();
      _onlineTimer = null;
    }
  }

  Future<void> _initChat() async {
    try {
      final userId = await AuthService.getUserId();
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
      });

      await _loadMessages(userId);
      // 先合并离线「通知中心」里的私信摘要，再拉 REST；避免仅依赖旧本地缓存时列表为空。
      await _mergeDmNotificationsFromApi();
      await _fetchInitialServerHistory();
      _mergePendingWsMessages();

      // Now that we merged offline messages, mark them as read.
      if (!mounted) return;
      try {
        await context
            .read<NotificationProvider>()
            .markDirectMessagesAsRead(widget.userId);
      } catch (_) {}
      ChatPushService.markSenderRead(widget.userId);

      await _connectWebSocket();
      await _ensurePeerOnline();
    } catch (_) {}
  }

  void _mergePendingWsMessages() {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      final pending = ChatPushService.takePendingMessages(widget.userId);
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
        if (from != widget.userId) continue;

        DateTime time;
        if (ts is int) {
          time = DateTime.fromMillisecondsSinceEpoch(ts);
        } else {
          time = DateTime.now();
        }

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
          _DirectMessage(senderId: from, content: content, time: time),
        );
        changed = true;
      }

      if (changed && mounted) {
        setState(() {
          _messages.sort((a, b) => a.time.compareTo(b.time));
        });
        _saveMessages();
        _scrollToBottom();
      }

      // 进入会话后，不应继续对该发送者累计未读
      ChatPushService.markSenderRead(widget.userId);
    } catch (_) {}
  }

  /// 把通知中心里的私信（含已读）合并进当前会话，用于对端离线时走通知落库的场景。
  /// 不在此处标记已读，由 [_initChat] 末尾统一处理。
  Future<void> _mergeDmNotificationsFromApi() async {
    try {
      final all = <NotificationModel>[];
      for (var p = 1; p <= 3; p++) {
        final batch =
            await NotificationService.getNotifications(page: p, pageSize: 50);
        if (batch.isEmpty) break;
        all.addAll(batch);
      }

      final dms = all.where((n) {
        if (n.type != NotificationModel.directMessage) return false;
        if ((n.senderId ?? '') != widget.userId) return false;
        return n.content.trim().isNotEmpty;
      }).toList();

      if (dms.isEmpty) return;

      dms.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      var changed = false;
      final existingKeys = <String>{};
      for (final m in _messages) {
        existingKeys
            .add('${m.senderId}|${m.time.toIso8601String()}|${m.content}');
      }

      for (final n in dms) {
        final time = n.createdAt;

        final hasSimilar = _messages.any((m) {
          if (m.senderId != widget.userId) return false;
          if (m.content != n.content) return false;
          final diff = m.time.difference(time).inMinutes.abs();
          return diff <= 5;
        });
        if (hasSimilar) {
          continue;
        }

        final key = '${widget.userId}|${time.toIso8601String()}|${n.content}';
        if (existingKeys.contains(key)) {
          continue;
        }
        existingKeys.add(key);
        _messages.add(
          _DirectMessage(
            senderId: widget.userId,
            content: n.content,
            time: time,
          ),
        );
        changed = true;
      }

      if (changed && mounted) {
        setState(() {
          _messages.sort((a, b) => a.time.compareTo(b.time));
        });
        await _saveMessages();
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _ensurePeerOnline() async {
    // Prefer push presence if available.
    final map = PresenceService.online.value;
    if (PresenceService.isConnected && map.isNotEmpty) {
      final online = map[widget.userId] ?? false;
      if (mounted) {
        setState(() {
          _peerOnline = online;
        });
      }
      return;
    }
    _startOnlinePolling();
  }

  String _storageKey(String currentUserId) {
    final ids = [currentUserId, widget.userId];
    ids.sort();
    return 'direct_chat_${ids.join('_')}';
  }

  List<_DirectMessage> _expandServerItem(PrivateMessageItem m) {
    final t = DateTime.tryParse(m.createdAt) ?? DateTime.now();
    final out = <_DirectMessage>[];
    final body = m.body.trim();
    if (body.isNotEmpty) {
      out.add(_DirectMessage(
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
      out.add(_DirectMessage(
        senderId: m.senderId,
        content: '$_imgPrefix$url',
        time: t,
        serverId: '${m.id}#i$i',
      ));
    }
    return out;
  }

  void _applyMergedLocalAndServer(
    List<_DirectMessage> local,
    List<_DirectMessage> serverExpanded,
  ) {
    final merged = <_DirectMessage>[];
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

  Future<void> _fetchInitialServerHistory() async {
    try {
      final page = await ApiService.listPrivateMessages(
        peerUserId: widget.userId,
        limit: 40,
      );
      if (!mounted) return;
      final expanded = <_DirectMessage>[];
      for (final m in page.items) {
        expanded.addAll(_expandServerItem(m));
      }
      final localCopy = List<_DirectMessage>.from(_messages);
      setState(() {
        _applyMergedLocalAndServer(localCopy, expanded);
        _hasMoreServer = page.hasMore;
        _oldestServerCursorId =
            page.items.isNotEmpty ? page.items.first.id : null;
      });
      await _saveMessages();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException) {
        MoeToast.show(
          context,
          '服务端聊天记录同步失败：${e.message}\n若刚升级后端，请确认已部署 /api/private-messages 并执行迁移。',
          duration: const Duration(seconds: 5),
          icon: Icons.cloud_off_outlined,
        );
      }
    }
  }

  Future<void> _loadOlderServerPage() async {
    final cursor = _oldestServerCursorId;
    if (cursor == null || cursor.isEmpty || !_hasMoreServer) return;
    if (_loadingServerPage) return;
    setState(() => _loadingServerPage = true);
    try {
      final page = await ApiService.listPrivateMessages(
        peerUserId: widget.userId,
        beforeId: cursor,
        limit: 30,
      );
      if (!mounted) return;
      final add = <_DirectMessage>[];
      for (final m in page.items) {
        add.addAll(_expandServerItem(m));
      }
      final existing = <String>{};
      for (final x in _messages) {
        if (x.serverId != null) existing.add(x.serverId!);
      }
      final novel = <_DirectMessage>[];
      for (final x in add) {
        if (x.serverId != null && existing.contains(x.serverId!)) continue;
        if (x.serverId != null) existing.add(x.serverId!);
        novel.add(x);
      }
      setState(() {
        _messages.insertAll(0, novel);
        _messages.sort((a, b) => a.time.compareTo(b.time));
        _hasMoreServer = page.hasMore;
        if (page.items.isNotEmpty) {
          _oldestServerCursorId = page.items.first.id;
        }
        _loadingServerPage = false;
      });
      await _saveMessages();
    } catch (_) {
      if (mounted) setState(() => _loadingServerPage = false);
    } finally {
      if (mounted && _loadingServerPage) {
        setState(() => _loadingServerPage = false);
      }
    }
  }

  String? _serverSlotFromWsId(dynamic rawId, String content) {
    if (rawId == null) return null;
    final id = rawId.toString();
    if (id.isEmpty) return null;
    if (content.startsWith(_imgPrefix)) return '$id#i0';
    return '$id#t';
  }

  Future<void> _loadMessages(String currentUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(currentUserId);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    final list = json.decode(raw) as List<dynamic>;
    final messages = list.map((item) {
      final map = item as Map<String, dynamic>;
      final sid = map['serverId']?.toString();
      return _DirectMessage(
        senderId: map['senderId'] as String,
        content: map['content'] as String,
        time: DateTime.tryParse(map['time'] as String? ?? '') ?? DateTime.now(),
        serverId: sid != null && sid.isNotEmpty ? sid : null,
      );
    }).toList();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(messages);
    });
    _scrollToBottom();
  }

  Future<void> _saveMessages() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(currentUserId);
    final list = _messages
        .map((m) => {
              'senderId': m.senderId,
              'content': m.content,
              'time': m.time.toIso8601String(),
              if (m.serverId != null) 'serverId': m.serverId,
            })
        .toList();
    await prefs.setString(key, json.encode(list));
    DirectChatSyncBus.bump();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Reverse: true 意味着 offset 0 是列表底部（最新消息）
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
      );
    });
  }

  void _startOnlinePolling() {
    _checkPeerOnline();
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkPeerOnline();
    });
  }

  Future<void> _checkPeerOnline() async {
    try {
      final map = await ApiService.getChatOnlineBatch([widget.userId]);
      final online = map[widget.userId] ?? false;
      if (!mounted) return;
      setState(() {
        _peerOnline = online;
      });
    } catch (_) {}
  }

  Future<void> _connectWebSocket() async {
    try {
      // Reuse the shared chat websocket so we don't create competing connections.
      ChatPushService.start();
      // IMPORTANT: Do NOT listen to ChatPushService.channel.stream here.
      // The underlying websocket stream is typically single-subscription and is
      // already listened by ChatPushService internally. We subscribe to the
      // broadcast stream exposed by ChatPushService instead.
      _incomingSub?.cancel();
      _incomingSub = ChatPushService.incomingMessages.listen((map) {
        _handleIncomingMap(map);
      });
    } catch (_) {}
  }

  void _handleIncomingMap(Map<String, dynamic> map) {
    if (!mounted) return;
    try {
      // 与 ChatPushService 一致：from/content 可能是 JSON 数字，强转 String? 会失败并被 catch 吞掉。
      final from = map['from']?.toString();
      final content = map['content']?.toString();
      final timestamp = map['timestamp'];
      if (from == null || from.isEmpty || content == null) {
        return;
      }
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        return;
      }
      if (from != widget.userId) {
        return;
      }
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
      final sid = _serverSlotFromWsId(map['server_message_id'], content);
      setState(() {
        _messages.add(
          _DirectMessage(
            senderId: from,
            content: content,
            time: time,
            serverId: sid,
          ),
        );
      });
      _saveMessages();
      _scrollToBottom();

      // When chat is open, don't count messages from this peer as unread.
      ChatPushService.markSenderRead(widget.userId);
    } catch (_) {}
  }

  /// 图片消息前缀，用于区分文本与图片
  static const String _imgPrefix = '[IMG]';

  bool _isImageContent(String content) =>
      content.startsWith(_imgPrefix) && content.length > _imgPrefix.length;

  String _getImageUrl(String content) => resolveMediaUrl(
        content.substring(_imgPrefix.length).trim(),
      );

  Future<void> _pickAndSendImage() async {
    if (_isSending) return;
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (xFile == null || !mounted) return;

      final path = xFile.path;
      if (path.isEmpty) {
        if (mounted) {
          MoeToast.error(context, '暂不支持在网页端发送图片');
        }
        return;
      }

      setState(() => _isSending = true);

      final file = File(path);
      if (!await file.exists()) return;
      final url = await ApiService.uploadImage(file);
      final content = '$_imgPrefix$url';

      if (!mounted) return;
      setState(() {
        _messages.add(
          _DirectMessage(
            senderId: currentUserId,
            content: content,
            time: DateTime.now(),
          ),
        );
        _isSending = false;
      });
      await _saveMessages();
      _scrollToBottom();

      final optimisticIdx = _messages.length - 1;
      try {
        final saved = await ApiService.sendPrivateMessage(
          receiverId: widget.userId,
          body: content,
        );
        if (!mounted) return;
        setState(() {
          if (optimisticIdx < _messages.length &&
              _messages[optimisticIdx].senderId == currentUserId &&
              _messages[optimisticIdx].content == content) {
            _messages[optimisticIdx] = _DirectMessage(
              senderId: currentUserId,
              content: content,
              time: _messages[optimisticIdx].time,
              serverId: _serverSlotFromWsId(saved.id, content),
            );
          }
        });
        await _saveMessages();
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          if (optimisticIdx < _messages.length &&
              _messages[optimisticIdx].senderId == currentUserId &&
              _messages[optimisticIdx].content == content) {
            _messages.removeAt(optimisticIdx);
          }
        });
        await _saveMessages();
        if (!mounted) return;
        MoeToast.show(
          context,
          '图片发送失败：${e.message}',
          duration: const Duration(seconds: 4),
          icon: Icons.cloud_off_outlined,
        );
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          if (optimisticIdx < _messages.length &&
              _messages[optimisticIdx].senderId == currentUserId &&
              _messages[optimisticIdx].content == content) {
            _messages.removeAt(optimisticIdx);
          }
        });
        await _saveMessages();
        if (!mounted) return;
        MoeToast.error(context, '图片发送失败，请检查网络');
        return;
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, '发送图片失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _inputFocusNode.requestFocus();
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    setState(() {
      _isSending = true;
      _messages.add(
        _DirectMessage(
          senderId: currentUserId,
          content: text,
          time: DateTime.now(),
        ),
      );
      _controller.clear();
    });
    await _saveMessages();
    _scrollToBottom();
    final optimisticIdx = _messages.length - 1;
    try {
      final saved = await ApiService.sendPrivateMessage(
        receiverId: widget.userId,
        body: text,
      );
      if (!mounted) return;
      setState(() {
        if (optimisticIdx < _messages.length &&
            _messages[optimisticIdx].senderId == currentUserId &&
            _messages[optimisticIdx].content == text) {
          _messages[optimisticIdx] = _DirectMessage(
            senderId: currentUserId,
            content: text,
            time: _messages[optimisticIdx].time,
            serverId: _serverSlotFromWsId(saved.id, text),
          );
        }
        _isSending = false;
      });
      await _saveMessages();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (optimisticIdx < _messages.length &&
            _messages[optimisticIdx].senderId == currentUserId &&
            _messages[optimisticIdx].content == text) {
          _messages.removeAt(optimisticIdx);
        }
        _isSending = false;
      });
      await _saveMessages();
      if (!mounted) return;
      MoeToast.show(
        context,
        '发送失败：${e.message}',
        duration: const Duration(seconds: 4),
        icon: Icons.cloud_off_outlined,
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (optimisticIdx < _messages.length &&
            _messages[optimisticIdx].senderId == currentUserId &&
            _messages[optimisticIdx].content == text) {
          _messages.removeAt(optimisticIdx);
        }
        _isSending = false;
      });
      await _saveMessages();
      if (!mounted) return;
      MoeToast.error(context, '发送失败，请检查网络');
      return;
    }
    if (!mounted) return;
    _inputFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _onlineTimer?.cancel();
    _incomingSub?.cancel();
    _incomingSub = null;
    _scrollController.removeListener(_scrollLoadOlderListener);
    if (_presenceListening) {
      PresenceService.online.removeListener(_onPresenceUpdate);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;
    final scheme = Theme.of(context).colorScheme;
    final reversedMessages = List<_DirectMessage>.from(_messages.reversed);
    final chatBg = Color.alphaBlend(
      scheme.primary.withOpacity(0.04),
      scheme.surfaceContainerLowest,
    );

    return Scaffold(
      backgroundColor: chatBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: () => _openPeerProfile(context),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              NetworkAvatarImage(
                imageUrl: widget.avatar,
                radius: 20,
                placeholderIcon: Icons.person,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.username,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _peerOnline
                                ? const Color(0xFF34C759)
                                : scheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _peerOnline ? '在线' : '离线',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: scheme.onSurface),
            onPressed: () => _showChatOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingServerPage)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              reverse: true,
              itemCount: reversedMessages.length,
              itemBuilder: (context, index) {
                final message = reversedMessages[index];
                final isMe =
                    currentUserId != null && message.senderId == currentUserId;

                final showPeerAvatar = !isMe &&
                    (index == 0 ||
                        reversedMessages[index - 1].senderId != message.senderId);

                var showTime = false;
                if (index == reversedMessages.length - 1) {
                  showTime = true;
                } else {
                  final nextMessage = reversedMessages[index + 1];
                  final diff =
                      message.time.difference(nextMessage.time).inMinutes.abs();
                  if (diff > 5) showTime = true;
                }

                return Column(
                  children: [
                    if (showTime) _buildTimeTag(context, message.time),
                    _buildMessageBubble(
                      context,
                      message,
                      isMe,
                      showPeerAvatar: showPeerAvatar,
                      tightBottom: index > 0 &&
                          reversedMessages[index - 1].senderId ==
                              message.senderId,
                    ),
                  ],
                );
              },
            ),
          ),
          _buildInputArea(context),
        ],
      ),
    );
  }

  void _openPeerProfile(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/user-profile',
      arguments: {
        'userId': widget.userId,
        'userName': widget.username,
        'userAvatar': widget.avatar,
        'heroTag': 'dm_header_${widget.userId}',
      },
    );
  }

  void _showChatOptions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.person_rounded, color: scheme.primary),
                title: const Text('查看对方主页'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPeerProfile(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: scheme.error),
                title: const Text('清空聊天记录'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Icon(Icons.block_rounded, color: scheme.error),
                title: const Text('屏蔽此人'),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTag(BuildContext context, DateTime time) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          _formatTime(time),
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(time.year, time.month, time.day);

    String timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (msgDate == today) {
      return timeStr;
    } else if (msgDate == yesterday) {
      return '昨天 $timeStr';
    } else {
      return '${time.month}/${time.day} $timeStr';
    }
  }

  Widget _buildMessageBubble(
    BuildContext context,
    _DirectMessage message,
    bool isMe, {
    required bool showPeerAvatar,
    required bool tightBottom,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final maxW = MediaQuery.sizeOf(context).width * 0.74;
    final bubbleBg = isMe
        ? scheme.primary
        : scheme.surfaceContainerHighest;
    final textColor = isMe ? scheme.onPrimary : scheme.onSurface;
    const avatarCol = 36.0;

    Widget bubbleChild = _isImageContent(message.content)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: _getImageUrl(message.content),
              fit: BoxFit.cover,
              width: 200,
              height: 200,
              placeholder: (context, url) => SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: textColor.withOpacity(0.6),
              ),
            ),
          )
        : Text(
            message.content,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              height: 1.45,
            ),
          );

    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: bubbleBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 18 : 6),
          topRight: Radius.circular(isMe ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(isMe ? 0.12 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: bubbleChild,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: tightBottom ? 4 : 10),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              SizedBox(
                width: avatarCol,
                child: showPeerAvatar
                    ? NetworkAvatarImage(
                        imageUrl: widget.avatar,
                        radius: 16,
                        placeholderIcon: Icons.person,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: bubble,
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      shadowColor: scheme.shadow.withOpacity(0.12),
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: _isSending ? null : _pickAndSendImage,
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: scheme.outline.withOpacity(0.15),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!_isSending) _sendMessage();
                    },
                    decoration: InputDecoration(
                      hintText: '发消息…',
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withOpacity(0.8),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: FilledButton(
                  onPressed: _isSending ? null : _sendMessage,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    maximumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: _isSending
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Icon(Icons.send_rounded, color: scheme.onPrimary, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectMessage {
  final String senderId;
  final String content;
  final DateTime time;
  /// 与服务端行对应的去重键（REST 展开为 `id#t` / `id#i0` 等；WS 对齐同规则）。
  final String? serverId;

  _DirectMessage({
    required this.senderId,
    required this.content,
    required this.time,
    this.serverId,
  });
}
