import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
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
    // 反转消息列表用于显示（最新的在最前面）
    final reversedMessages = List<_DirectMessage>.from(_messages.reversed);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
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
                children: [
                  Text(
                    widget.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _peerOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _peerOnline ? '在线' : '离线',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA), // 浅灰背景色
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                reverse: true, // 反向列表，从底部开始
                itemCount: reversedMessages.length,
                itemBuilder: (context, index) {
                  final message = reversedMessages[index];
                  final isMe =
                      currentUserId != null && message.senderId == currentUserId;
                  
                  // 检查是否显示时间
                  bool showTime = false;
                  if (index == reversedMessages.length - 1) {
                    showTime = true; // 第一条（最旧的）显示时间
                  } else {
                    final nextMessage = reversedMessages[index + 1];
                    final diff = message.time.difference(nextMessage.time).inMinutes.abs();
                    if (diff > 5) {
                      showTime = true; // 间隔超过5分钟显示时间
                    }
                  }

                  return Column(
                    children: [
                      if (showTime) _buildTimeTag(message.time),
                      _buildMessageBubble(message, isMe),
                    ],
                  );
                },
              ),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTimeTag(DateTime time) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatTime(time),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
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

  Widget _buildMessageBubble(_DirectMessage message, bool isMe) {
    final alignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final bgColor = isMe ? const Color(0xFF7F7FD5) : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            NetworkAvatarImage(
              imageUrl: widget.avatar,
              radius: 18,
              placeholderIcon: Icons.person,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            // 这里可以添加自己的头像，如果需要的话
            // 目前保持简洁，只显示对方头像
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: Colors.grey[600],
              onPressed: () {
                // TODO: 添加更多功能，如图片、文件等
              },
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (!_isSending) {
                      _sendMessage();
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: '发送消息...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSending 
                      ? Colors.grey[300] 
                      : const Color(0xFF7F7FD5),
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
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
