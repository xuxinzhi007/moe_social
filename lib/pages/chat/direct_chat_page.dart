import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../utils/moe_error_copy.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../widgets/avatar_image.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/chat_push_service.dart';
import '../../services/presence_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_action_row.dart';
import 'direct_chat_viewmodel.dart';
import 'voice_call_launcher.dart';

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
  late final DirectChatViewModel _chat;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  bool _peerOnline = false;
  Timer? _onlineTimer;
  bool _presenceListening = false;
  late final VoidCallback _scrollLoadOlderListener;
  double _sendBtnScale = 1.0;
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    _chat = DirectChatViewModel(peerUserId: widget.userId);
    _chat.addListener(_onChatChanged);
    _chat.onScrollToBottom = _scrollToBottom;
    _scrollLoadOlderListener = () {
      if (!_scrollController.hasClients) return;
      if (!_chat.hasMoreServer || _chat.loadingServerPage) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 100) {
        unawaited(_chat.loadOlderServerPage());
      }
    };
    _scrollController.addListener(_scrollLoadOlderListener);
    _controller.addListener(_handleDraftChanged);
    _initChat();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
  }

  void _handleDraftChanged() {
    final next = _controller.text.trim().isNotEmpty;
    if (next == _hasDraft) return;
    setState(() => _hasDraft = next);
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
    await _chat.bootstrap();
    if (!mounted) return;
    final warning = _chat.historySyncWarning;
    if (warning != null) {
      MoeToast.show(
        context,
        warning,
        duration: const Duration(seconds: 5),
        icon: Icons.cloud_off_outlined,
      );
      _chat.consumeHistorySyncWarning();
    }
    try {
      await context
          .read<NotificationProvider>()
          .markDirectMessagesAsRead(widget.userId);
    } catch (_) {}
    ChatPushService.markSenderRead(widget.userId);
    await _connectWebSocket();
    await _ensurePeerOnline();
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

  Future<void> _startVoiceCall() async {
    final currentUserId = _chat.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;
    try {
      final callData = await ChatService.voiceCall(widget.userId);
      final channelName = callData['channel_name']?.toString() ??
          callData['call_id']?.toString();
      if (channelName == null || channelName.isEmpty) {
        throw Exception('invalid channel');
      }
      if (!mounted) return;
      await openVoiceCallPage(
        context,
        channelName: channelName,
        userName: widget.username,
        userAvatar: widget.avatar,
      );
    } catch (_) {
      if (!mounted) return;
      MoeToast.error(context, '发起通话失败，请重试');
    }
  }

  Future<void> _clearLocalChatHistory() async {
    final err = await _chat.clearLocalChatHistory();
    if (!mounted) return;
    ChatPushService.markSenderRead(widget.userId);
    if (err != null) {
      MoeToast.error(context, err);
      return;
    }
    MoeToast.success(context, '聊天记录已清空');
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
      final map = await UserService.getChatOnlineBatch([widget.userId]);
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
    _chat.handleIncomingMap(map);
  }

  Future<void> _pickAndSendImage() async {
    if (_chat.isSending) return;
    if (_chat.currentUserId == null) return;

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

      final file = File(path);
      final err = await _chat.sendImageFile(file);
      if (!mounted) return;
      if (err != null) {
        MoeToast.show(
          context,
          err,
          duration: const Duration(seconds: 4),
          icon: Icons.cloud_off_outlined,
        );
      }
    } catch (_) {
      if (mounted) {
        MoeToast.error(context, '发送图片失败，请重试');
      }
    } finally {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_chat.isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _hasDraft = false);
    final err = await _chat.sendText(text);
    if (!mounted) return;
    if (err != null) {
      if (_controller.text.trim().isEmpty) {
        _controller.text = text;
        setState(() => _hasDraft = true);
      }
      MoeToast.show(
        context,
        '$err，内容已恢复，可直接重试',
        duration: const Duration(seconds: 4),
        icon: Icons.cloud_off_outlined,
      );
    }
    _inputFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _chat.dispose();
    _controller.removeListener(_handleDraftChanged);
    _controller.dispose();
    _scrollController.removeListener(_scrollLoadOlderListener);
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
    final currentUserId = _chat.currentUserId;
    final reversedMessages =
        List<DirectChatMessage>.from(_chat.messages.reversed);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: MoeTokens.surface0,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: MoeTokens.surface1,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        shape: const ContinuousRectangleBorder(
          side: BorderSide(color: MoeTokens.surfaceBorder),
        ),
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
              // 头像 + 渐变环
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: MoeTokens.gradientSoft,
                ),
                padding: const EdgeInsets.all(2),
                child: widget.avatar.trim().isNotEmpty
                    ? NetworkAvatarImage(
                        imageUrl: widget.avatar,
                        radius: 18,
                        placeholderIcon: null,
                      )
                    : ClipOval(
                        child: Image.asset(
                          'assets/chat/avatar_placeholder.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              SizedBox(width: MoeTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.username,
                      style: TextStyle(
                        fontSize: MoeTokens.textMd,
                        fontWeight: MoeTokens.fontWeightTitle,
                        color: MoeTokens.titleText,
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
                                ? MoeTokens.success
                                : MoeTokens.hintText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _peerOnline ? '在线' : '离线',
                          style: const TextStyle(
                            fontSize: MoeTokens.textSm,
                            color: MoeTokens.hintText,
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
            icon: const Icon(Icons.phone_rounded, color: MoeTokens.primary),
            onPressed: _startVoiceCall,
          ),
          IconButton(
            icon:
                const Icon(Icons.more_vert_rounded, color: MoeTokens.titleText),
            onPressed: () => _showChatOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: ChatPushService.connectionLive,
            builder: (context, live, _) {
              if (live) return const SizedBox.shrink();
              return Material(
                color: MoeTokens.warning.withValues(alpha: 0.12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 16, color: MoeTokens.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '连接中断，正在重连…',
                          style: TextStyle(
                            fontSize: MoeTokens.textSm,
                            color: MoeTokens.titleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_chat.historySyncWarning != null)
            Material(
              color: MoeTokens.danger.withValues(alpha: 0.08),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: MoeTokens.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _chat.historySyncWarning!,
                        style: const TextStyle(
                          fontSize: MoeTokens.textSm,
                          color: MoeTokens.titleText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_chat.loadingServerPage)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: MoeTokens.surface0,
            ),
          Expanded(
            child: _chat.isBootstrapping && _chat.isEmpty
                ? const Center(child: MoeLoading())
                : _chat.bootstrapError != null && _chat.isEmpty
                    ? MoeErrorState.fromError(
                        _chat.bootstrapError,
                        scene: MoeErrorScene.messages,
                        onRetry: () => _chat.bootstrap(),
                      )
                    : !_chat.isBootstrapping && _chat.isEmpty
                        ? const Center(
                            child: MoeEmptyState(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: '还没有消息',
                              subtitle: '打个招呼吧',
                              showCard: false,
                              animate: false,
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            reverse: true,
                            itemCount: reversedMessages.length,
                            itemBuilder: (context, index) {
                              final message = reversedMessages[index];
                              final isMe = currentUserId != null &&
                                  message.senderId == currentUserId;

                              final showPeerAvatar = !isMe &&
                                  (index == 0 ||
                                      reversedMessages[index - 1].senderId !=
                                          message.senderId);

                              var showTime = false;
                              if (index == reversedMessages.length - 1) {
                                showTime = true;
                              } else {
                                final nextMessage = reversedMessages[index + 1];
                                final diff = message.time
                                    .difference(nextMessage.time)
                                    .inMinutes
                                    .abs();
                                if (diff > 5) showTime = true;
                              }

                              return Column(
                                children: [
                                  if (showTime)
                                    _buildTimeTag(context, message.time),
                                  _buildMessageBubble(
                                    context,
                                    message,
                                    isMe,
                                    showPeerAvatar: showPeerAvatar,
                                    tightBottom: index > 0 &&
                                        reversedMessages[index - 1].senderId ==
                                            message.senderId,
                                    showSending:
                                        isMe && index == 0 && _chat.isSending,
                                  ),
                                ],
                              );
                            },
                          ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? 6 : 0),
            child: _buildInputArea(context),
          ),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: MoeTokens.surfaceBorder),
          ),
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
                  color: MoeTokens.hintText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: MoeActionRow(
                  icon: Icons.person_rounded,
                  iconColor: MoeTokens.primary,
                  title: '查看对方主页',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openPeerProfile(context);
                  },
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: MoeActionRow(
                  icon: Icons.delete_outline_rounded,
                  iconColor: MoeTokens.danger,
                  iconBackgroundColor: MoeTokens.danger.withValues(alpha: 0.12),
                  title: '清空聊天记录',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('清空聊天记录'),
                        content: const Text('将删除双方的聊天记录，且无法恢复，是否继续？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _clearLocalChatHistory();
                    }
                  },
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: MoeActionRow(
                  icon: Icons.block_rounded,
                  iconColor: MoeTokens.danger,
                  iconBackgroundColor: MoeTokens.danger.withValues(alpha: 0.12),
                  title: '屏蔽此人',
                  onTap: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTag(BuildContext context, DateTime time) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: MoeTokens.surface1.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Text(
          _formatTime(time),
          style: const TextStyle(
            color: MoeTokens.hintText,
            fontSize: MoeTokens.textXs,
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

    String timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

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
    DirectChatMessage message,
    bool isMe, {
    required bool showPeerAvatar,
    required bool tightBottom,
    required bool showSending,
  }) {
    final maxW = MediaQuery.sizeOf(context).width * 0.74;
    final bubbleBg = isMe ? MoeTokens.primary : MoeTokens.surface1;
    final textColor = isMe ? Colors.white : MoeTokens.titleText;
    const avatarCol = 36.0;

    Widget bubbleChild = _chat.isImageContent(message.content)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            child: CachedNetworkImage(
              imageUrl: _chat.imageUrlOf(message.content),
              fit: BoxFit.cover,
              width: 200,
              height: 200,
              memCacheWidth: 400,
              memCacheHeight: 400,
              maxWidthDiskCache: 400,
              maxHeightDiskCache: 400,
              placeholder: (context, url) => SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: MoeSmallLoading(
                    size: 24,
                    color: MoeTokens.primary,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: Colors.white70,
              ),
            ),
          )
        : Text(
            message.content,
            style: TextStyle(
              color: textColor,
              fontSize: MoeTokens.textMd,
              height: 1.45,
            ),
          );

    // 气泡圆角：第一条消息有“尾巴”效果，连续消息底部圆角统一
    final tailRadius = tightBottom ? MoeTokens.radiusMd : 4.0;
    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: bubbleBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 18 : 6),
          topRight: Radius.circular(isMe ? 6 : 18),
          bottomLeft: Radius.circular(isMe ? 18 : tailRadius),
          bottomRight: Radius.circular(isMe ? tailRadius : 18),
        ),
        border: isMe ? null : Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: MoeTokens.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : MoeTokens.shadowSm(),
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
                    ? (widget.avatar.trim().isNotEmpty
                        ? NetworkAvatarImage(
                            imageUrl: widget.avatar,
                            radius: 16,
                            placeholderIcon: null,
                          )
                        : ClipOval(
                            child: Image.asset(
                              'assets/chat/avatar_placeholder.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ))
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: bubble,
                ),
                if (showSending) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '发送中...',
                    style: TextStyle(
                      fontSize: MoeTokens.textXs,
                      color: MoeTokens.hintText,
                    ),
                  ),
                ],
              ],
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final canSend = _hasDraft && !_chat.isSending;
    return Material(
      elevation: 0,
      color: MoeTokens.surface1,
      shadowColor: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: MoeTokens.surfaceBorder),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            MoeTokens.spaceSm,
            MoeTokens.spaceSm,
            MoeTokens.spaceSm,
            MoeTokens.spaceSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: '发送图片',
                onPressed: _chat.isSending ? null : _pickAndSendImage,
                style: IconButton.styleFrom(
                  fixedSize: const Size(42, 42),
                  backgroundColor: MoeTokens.surface0,
                  foregroundColor: MoeTokens.hintText,
                  disabledForegroundColor: MoeTokens.hintText.withValues(
                    alpha: 0.45,
                  ),
                  side: const BorderSide(color: MoeTokens.surfaceBorder),
                ),
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: MoeTokens.surface0,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
                    border: Border.all(color: MoeTokens.surfaceBorder),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (canSend) unawaited(_sendMessage());
                    },
                    decoration: const InputDecoration(
                      hintText: '消息',
                      hintStyle: TextStyle(
                        color: MoeTokens.hintText,
                        fontSize: MoeTokens.textMd,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: MoeTokens.textMd,
                      color: MoeTokens.titleText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canSend ? _sendMessage : null,
                onTapDown: canSend
                    ? (_) => setState(() => _sendBtnScale = 0.92)
                    : null,
                onTapUp:
                    canSend ? (_) => setState(() => _sendBtnScale = 1.0) : null,
                onTapCancel:
                    canSend ? () => setState(() => _sendBtnScale = 1.0) : null,
                child: AnimatedScale(
                  scale: _sendBtnScale,
                  duration: MoeTokens.motionFast,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: canSend ? MoeTokens.primary : MoeTokens.surface0,
                      shape: BoxShape.circle,
                      border: canSend
                          ? null
                          : Border.all(color: MoeTokens.surfaceBorder),
                    ),
                    child: _chat.isSending
                        ? const MoeSmallLoading(
                            size: 18,
                            color: MoeTokens.primary,
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            color: canSend ? Colors.white : MoeTokens.hintText,
                            size: 21,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
