import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'widgets/moe_toast.dart';
import 'services/api_service.dart';
import 'widgets/avatar_image.dart';
import 'package:provider/provider.dart';
import 'providers/notification_provider.dart';
import 'services/chat_push_service.dart';
import 'services/presence_service.dart';
import 'services/notification_service.dart';
import 'models/notification.dart';
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

  @override
  void initState() {
    super.initState();
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
      _mergePendingWsMessages();
      await _syncOfflineMessages();

      // Now that we merged offline messages, mark them as read.
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

  Future<void> _syncOfflineMessages() async {
    // Pull unread direct-message notifications from backend and merge into local chat history.
    try {
      final list =
          await NotificationService.getNotifications(page: 1, pageSize: 100);
      final dms = list.where((n) {
        return n.type == NotificationModel.directMessage &&
            !n.isRead &&
            (n.senderId ?? '') == widget.userId;
      }).toList();

      if (dms.isEmpty) return;

      // Oldest first
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

      // Mark as read so they won't be pulled again.
      try {
        await context
            .read<NotificationProvider>()
            .markDirectMessagesAsRead(widget.userId);
      } catch (_) {}
      ChatPushService.markSenderRead(widget.userId);
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

  Future<void> _loadMessages(String currentUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(currentUserId);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    final list = json.decode(raw) as List<dynamic>;
    final messages = list.map((item) {
      final map = item as Map<String, dynamic>;
      return _DirectMessage(
        senderId: map['senderId'] as String,
        content: map['content'] as String,
        time: DateTime.tryParse(map['time'] as String? ?? '') ?? DateTime.now(),
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
            })
        .toList();
    await prefs.setString(key, json.encode(list));
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
      final from = map['from'] as String?;
      final content = map['content'] as String?;
      final timestamp = map['timestamp'];
      if (from == null || content == null) {
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
      } else {
        time = DateTime.now();
      }
      setState(() {
        _messages.add(
          _DirectMessage(
            senderId: from,
            content: content,
            time: time,
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

  String _getImageUrl(String content) =>
      content.substring(_imgPrefix.length).trim();

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

      final channel = ChatPushService.channel;
      if (channel != null) {
        final payload = json.encode({
          'type': 'message',
          'to': widget.userId,
          'content': content,
          'sender_name': widget.username,
          'sender_avatar': widget.avatar,
        });
        try {
          channel.sink.add(payload);
        } catch (_) {}
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
    final channel = ChatPushService.channel;
    if (channel != null) {
      final payload = json.encode({
        'type': 'message',
        'to': widget.userId,
        'content': text,
        'sender_name': widget.username,
        'sender_avatar': widget.avatar,
      });
      try {
        channel.sink.add(payload);
      } catch (_) {}
    } else {
      // If websocket isn't ready yet, try to reconnect (message already shown locally).
      ChatPushService.start();
    }
    if (!mounted) return;
    setState(() {
      _isSending = false;
    });
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

  _DirectMessage({
    required this.senderId,
    required this.content,
    required this.time,
  });
}
