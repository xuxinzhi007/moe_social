import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'widgets/avatar_image.dart';

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
  WebSocketChannel? _channel;
  bool _peerOnline = false;
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      final userId = await AuthService.getUserId();
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
      });
      await _loadMessages(userId);
      await _connectWebSocket();
      _startOnlinePolling();
    } catch (_) {}
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
      final position = _scrollController.position;
      final max = position.maxScrollExtent;
      final current = position.pixels;
      if (max - current <= 80) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startOnlinePolling() {
    _checkPeerOnline();
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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

  Uri _buildWebSocketUri() {
    final base = ApiService.baseUrl;
    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final token = ApiService.token;
    final query = <String, String>{};
    if (token != null && token.isNotEmpty) {
      query['token'] = token;
    }
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/ws/chat',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Future<void> _connectWebSocket() async {
    try {
      final uri = _buildWebSocketUri();
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      channel.stream.listen(
        (data) {
          _handleWebSocketMessage(data);
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void _handleWebSocketMessage(dynamic data) {
    if (!mounted) return;
    try {
      if (data is! String) return;
      final map = json.decode(data) as Map<String, dynamic>;
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
    final channel = _channel;
    if (channel != null) {
      final payload = json.encode({
        'type': 'message',
        'to': widget.userId,
        'content': text,
      });
      try {
        channel.sink.add(payload);
      } catch (_) {}
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
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            NetworkAvatarImage(
              imageUrl: widget.avatar,
              radius: 16,
              placeholderIcon: Icons.person,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.username),
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
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe =
                    currentUserId != null && message.senderId == currentUserId;
                return _buildMessageBubble(message, isMe);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_DirectMessage message, bool isMe) {
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final crossAlign = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isMe ? const Color(0xFF7F7FD5) : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : Colors.black87;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: crossAlign,
        children: [
          Align(
            alignment: alignment,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: textColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _inputFocusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!_isSending) {
                    _sendMessage();
                  }
                },
                decoration: const InputDecoration(
                  hintText: '发送消息...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Color(0xFFF5F7FA),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Color(0xFF7F7FD5)),
              onPressed: _isSending ? null : _sendMessage,
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
