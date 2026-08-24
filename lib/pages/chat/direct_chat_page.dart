import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../utils/moe_error_copy.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../services/voice_message_service.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/chat/voice_bubble.dart';
import '../../widgets/moe_glass_surface.dart';
import '../../constants/feature_flags.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/chat_theme_provider.dart';
import '../../services/chat_push_service.dart';
import '../../services/presence_service.dart';
import '../../theme/moe_tokens.dart';
import '../../theme/chat_skin.dart';
import '../../widgets/motion/moe_motion.dart';
import '../../widgets/motion/moe_chat_motion.dart';
import '../../widgets/moe_action_row.dart';
import 'direct_chat_viewmodel.dart';
import 'chat_skin_picker_page.dart';
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

  // ── 语音消息（[FeatureFlags.chatVoiceMessage]）────────────────
  bool _isRecording = false;
  int _recordSeconds = 0;
  bool _recordCancelled = false;
  double? _recordStartDy;
  Timer? _recordTimer;

  /// 长按手势是否仍在进行中；权限弹窗 / 异步 await 期间手势可能已失效，
  /// 异步恢复后据此守卫，避免手势已取消仍启动录音。
  bool _voicePressActive = false;

  /// 品牌动效（[FeatureFlags.chatBrandMotion]）的 OverlayEntry，dispose 时清理。
  final List<OverlayEntry> _fxEntries = [];

  /// 首屏历史消息不播入场动画；bootstrap 后的首帧渲染完成后置 true，
  /// 之后新增的消息才走入场动效。
  bool _initialRenderDone = false;

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
    // 首帧（含历史消息）渲染完后才允许入场动画，避免历史消息闪动。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialRenderDone = true;
    });
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
    // 对方新消息到达：触发新消息弹跳动效（定位在头像 / 气泡附近）。
    if (map['from']?.toString() == widget.userId) {
      _showMessagePopFx();
    }
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
    } else {
      // 发送成功（消息已加入列表）：触发品牌对勾动效。
      _showSendSuccessFx();
    }
    _inputFocusNode.requestFocus();
  }

  // ── 语音消息（FeatureFlags.chatVoiceMessage）：长按录音 → 松开发送 ───

  static const int _maxRecordSeconds = 60;
  static const double _cancelSlideThreshold = 80.0;

  Future<void> _startVoiceRecord(double startDy) async {
    if (_chat.isSending || _isRecording) return;
    PermissionStatus status;
    try {
      status = await Permission.microphone.request();
    } catch (_) {
      if (mounted) MoeToast.error(context, '请求麦克风权限失败');
      return;
    }
    if (!status.isGranted) {
      if (mounted) MoeToast.show(context, '需要麦克风权限才能发送语音');
      return;
    }
    // 权限弹窗期间长按手势可能已失效：不再启动录音，并幂等清理在途录音。
    if (!mounted || !_voicePressActive) {
      unawaited(VoiceMessageService().cancelRecording());
      return;
    }
    try {
      await VoiceMessageService().startRecording();
    } catch (_) {
      if (mounted) MoeToast.error(context, '启动录音失败，请重试');
      return;
    }
    // startRecording 异步期间手势同样可能失效（如页面已 dispose）。
    if (!mounted || !_voicePressActive) {
      unawaited(VoiceMessageService().cancelRecording());
      return;
    }
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _recordCancelled = false;
      _recordStartDy = startDy;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      setState(() => _recordSeconds++);
      if (_recordSeconds >= _maxRecordSeconds) {
        timer.cancel();
        // 达到上限自动发送。
        unawaited(_finishVoiceRecord(cancel: false));
      }
    });
  }

  void _updateVoiceRecordDrag(double dy) {
    final start = _recordStartDy;
    if (start == null || !_isRecording) return;
    final cancelled = start - dy > _cancelSlideThreshold;
    if (cancelled != _recordCancelled) {
      setState(() => _recordCancelled = cancelled);
    }
  }

  Future<void> _finishVoiceRecord({required bool cancel}) async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final wasRecording = _isRecording;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordStartDy = null;
      });
    }
    if (!wasRecording) return;

    if (cancel) {
      await VoiceMessageService().cancelRecording();
      return;
    }

    final result = await VoiceMessageService().stopRecording();
    if (result == null) {
      if (mounted) MoeToast.show(context, '说话时间太短');
      return;
    }
    final (path, duration) = result;
    final err = await _chat.sendVoiceFile(File(path), durationSec: duration);
    if (err == null) {
      // 发送成功后清理本地临时音频：文件清理不受 mounted 检查阻挡。
      await _deleteTempFile(path);
    }
    if (!mounted) return;
    if (err != null) {
      // 发送失败（如 busy 竞态）保留临时文件，提示用户可重试，避免录音丢失。
      MoeToast.show(
        context,
        err == '语音文件不存在' ? err : '$err，可稍后重试',
        duration: const Duration(seconds: 4),
        icon: Icons.cloud_off_outlined,
      );
    } else {
      _showSendSuccessFx();
    }
  }

  /// 删除本地临时音频文件（静默失败）。
  Future<void> _deleteTempFile(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 录音中提示条（半透明 overlay，显示在输入区上方）。
  Widget _buildRecordingBar() {
    final cancelHint = _recordCancelled;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: MoeTokens.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: MoeTokens.textMd,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cancelHint ? '松开取消' : '松开发送，上滑取消',
              style: TextStyle(
                color: cancelHint ? MoeTokens.danger : Colors.white70,
                fontSize: MoeTokens.textSm,
              ),
            ),
          ),
          Icon(
            cancelHint
                ? Icons.cancel_rounded
                : Icons.keyboard_arrow_up_rounded,
            size: 18,
            color: cancelHint ? MoeTokens.danger : Colors.white54,
          ),
          const SizedBox(width: 4),
          // 兜底取消入口：手势异常时仍可显式取消录音。
          IconButton(
            tooltip: '取消录音',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => unawaited(_finishVoiceRecord(cancel: true)),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── 品牌动效（FeatureFlags.chatBrandMotion）───────────────────────

  /// 发送成功✓：定位在发送按钮附近（右下角），播完自动移除。
  void _showSendSuccessFx() {
    if (!FeatureFlags.chatBrandMotion || !mounted) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 80,
        right: 20,
        child: MoeSendSuccessFx(onComplete: () => _removeFx(entry)),
      ),
    );
    _insertFx(entry);
  }

  /// 新消息弹跳：定位在对方头像 / 气泡附近（左下角），播完自动移除。
  void _showMessagePopFx() {
    if (!FeatureFlags.chatBrandMotion || !mounted) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 96,
        left: 12,
        child: MoeMessagePopFx(onComplete: () => _removeFx(entry)),
      ),
    );
    _insertFx(entry);
  }

  void _insertFx(OverlayEntry entry) {
    _fxEntries.add(entry);
    Overlay.of(context).insert(entry);
  }

  void _removeFx(OverlayEntry entry) {
    if (!_fxEntries.remove(entry)) return;
    entry.remove();
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
    _recordTimer?.cancel();
    _voicePressActive = false;
    if (_isRecording) {
      // 页面销毁时仍在按住录音才丢弃未发送的录音（cancelRecording 幂等）；
      // 松手后的发送阶段（stopRecording 挂起窗口）交给 _finishVoiceRecord 自然完成，
      // 避免误 cancel 删除在途音频。
      unawaited(VoiceMessageService().cancelRecording());
    }
    _incomingSub?.cancel();
    _incomingSub = null;
    for (final entry in _fxEntries) {
      entry.remove();
    }
    _fxEntries.clear();
    if (_presenceListening) {
      PresenceService.online.removeListener(_onPresenceUpdate);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _chat.currentUserId;
    final reversedMessages = _chat.reversedMessages;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final glassNav = FeatureFlags.glassNavigation;

    // 聊天主题皮肤（flag 开启时背景 / 气泡渐变跟随所选皮肤，并按亮度取深浅变体）。
    final chatSkin = FeatureFlags.chatThemeSkins
        ? context.watch<ChatThemeProvider>().currentSkin
        : null;
    final brightness = Theme.of(context).brightness;
    final scaffoldBg = chatSkin?.backgroundFor(brightness) ?? MoeTokens.surface0;

    return Scaffold(
      backgroundColor: scaffoldBg,
      extendBodyBehindAppBar: glassNav,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: glassNav ? 0 : 0.5,
        backgroundColor: glassNav ? Colors.transparent : MoeTokens.surface1,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        shape: glassNav
            ? null
            : const ContinuousRectangleBorder(
                side: BorderSide(color: MoeTokens.surfaceBorder),
              ),
        flexibleSpace: glassNav
            ? MoeGlassSurface(
                tint: MoeTokens.surface1.withValues(alpha: 0.78),
                showBorder: false,
                child: Container(),
              )
            : null,
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
          // glass 模式下 body 延伸到 AppBar 后方，顶部补偿状态栏+工具栏高度，
          // 避免告警横幅 / 分页进度条被毛玻璃 AppBar 遮挡；flag 关闭时高度为 0。
          SizedBox(
            height: glassNav
                ? MediaQuery.paddingOf(context).top + kToolbarHeight
                : 0,
          ),
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

                              return RepaintBoundary(
                                child: Column(
                                  children: [
                                    if (showTime)
                                      _buildTimeTag(context, message.time),
                                    _MessageEntranceAnimation(
                                      // 键策略：服务端消息用稳定的 serverId；
                                      // 本地乐观消息（serverId 为 null）用位置键，
                                      // 避免内容重复撞键触发 Duplicate keys 断言。
                                      key: ValueKey(
                                        message.serverId ?? 'local-$index',
                                      ),
                                      isMe: isMe,
                                      animate:
                                          FeatureFlags.chatGradientBubbles &&
                                              _initialRenderDone,
                                      child: _buildMessageBubble(
                                        context,
                                        message,
                                        isMe,
                                        index: index,
                                        showPeerAvatar: showPeerAvatar,
                                        tightBottom: index > 0 &&
                                            reversedMessages[index - 1]
                                                    .senderId ==
                                                message.senderId,
                                        showSending: isMe &&
                                            index == 0 &&
                                            _chat.isSending,
                                        chatSkin: chatSkin,
                                        brightness: brightness,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
          if (_isRecording) _buildRecordingBar(),
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
              if (FeatureFlags.chatThemeSkins) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MoeActionRow(
                    icon: Icons.palette_outlined,
                    iconColor: MoeTokens.secondary,
                    title: '聊天主题',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ChatSkinPickerPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
    required int index,
    required bool showPeerAvatar,
    required bool tightBottom,
    required bool showSending,
    required ChatSkin? chatSkin,
    required Brightness brightness,
  }) {
    final maxW = MediaQuery.sizeOf(context).width * 0.74;
    final bubbleBg = isMe
        ? MoeTokens.primary
        : chatSkin?.peerColorFor(brightness) ?? MoeTokens.surface1;
    // flag 开启时我方气泡改用窗口级连续渐变（按 index 微偏移）；对方气泡保持纯色。
    final useMeGradient = FeatureFlags.chatGradientBubbles && isMe;
    final textColor = isMe ? Colors.white : MoeTokens.titleText;
    const avatarCol = 36.0;

    Widget bubbleChild;
    // 格式非法（voiceInfoOf 返回 null）时降级为普通文本气泡，不渲染播放器。
    final voiceInfo = _chat.isVoiceContent(message.content)
        ? _chat.voiceInfoOf(message.content)
        : null;
    if (voiceInfo != null) {
      final (url, duration) = voiceInfo;
      bubbleChild = VoiceBubble(
        // 用内容作 key：同一语音消息复用播放器状态。
        key: ValueKey('voice|${message.content}'),
        url: url,
        durationSec: duration,
        isMe: isMe,
      );
    } else if (_chat.isImageContent(message.content)) {
      bubbleChild = ClipRRect(
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
          );
    } else {
      bubbleChild = Text(
            message.content,
            style: TextStyle(
              color: textColor,
              fontSize: MoeTokens.textMd,
              height: 1.45,
            ),
          );
    }

    // 气泡圆角：第一条消息有“尾巴”效果，连续消息底部圆角统一
    final tailRadius = tightBottom ? MoeTokens.radiusMd : 4.0;
    // 气泡渐变采样：开启皮肤功能时取当前所选皮肤（build 顶部已解析，
    // 避免重复 Provider 查找），否则仍为默认薰衣草。
    final skinGradient =
        (chatSkin ?? ChatSkins.lavender).bubbleMeGradient;
    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: useMeGradient ? null : bubbleBg,
        gradient: useMeGradient
            ? LinearGradient(
                colors: skinGradient.colors,
                stops: skinGradient.stops,
                begin: skinGradient.begin,
                end: skinGradient.end,
                tileMode: skinGradient.tileMode,
                transform: _GradientShiftTransform(index),
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 18 : 6),
          topRight: Radius.circular(isMe ? 6 : 18),
          bottomLeft: Radius.circular(isMe ? 18 : tailRadius),
          bottomRight: Radius.circular(isMe ? tailRadius : 18),
        ),
        border: isMe
            ? null
            : Border.all(
                color: chatSkin?.peerBorderFor(brightness) ??
                    MoeTokens.surfaceBorder,
              ),
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
              if (FeatureFlags.chatVoiceMessage) ...[
                const SizedBox(width: 8),
                // 麦克风：长按录音 → 松开发送，上滑取消。
                GestureDetector(
                  onLongPressStart: (details) {
                    _voicePressActive = true;
                    unawaited(_startVoiceRecord(details.globalPosition.dy));
                  },
                  onLongPressMoveUpdate: (details) =>
                      _updateVoiceRecordDrag(details.globalPosition.dy),
                  onLongPressEnd: (_) {
                    _voicePressActive = false;
                    unawaited(_finishVoiceRecord(cancel: _recordCancelled));
                  },
                  onLongPressCancel: () {
                    _voicePressActive = false;
                    if (_isRecording) {
                      unawaited(_finishVoiceRecord(cancel: true));
                    }
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? MoeTokens.danger.withValues(alpha: 0.12)
                          : MoeTokens.surface0,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecording
                            ? MoeTokens.danger.withValues(alpha: 0.4)
                            : MoeTokens.surfaceBorder,
                      ),
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      size: 22,
                      color: _isRecording
                          ? MoeTokens.danger
                          : MoeTokens.hintText,
                    ),
                  ),
                ),
              ],
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

/// 按消息 index 平移渐变起点，让整窗口气泡渐变色彩随位置流动。
class _GradientShiftTransform extends GradientTransform {
  final int index;

  const _GradientShiftTransform(this.index);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // 每 5 条消息循环一次，微移渐变起点。
    final shift = (index % 5) * 0.08;
    return Matrix4.translationValues(
      shift * bounds.width * 0.1,
      shift * bounds.height * 0.1,
      0,
    );
  }
}

/// 新消息入场微动效（仅 animate=true 时播放，历史消息直接展示）。
///
/// - 我方：缩放 0.92→1.0 + 淡入，200ms
/// - 对方：上滑 0.05→0 + 淡入，240ms
class _MessageEntranceAnimation extends StatefulWidget {
  const _MessageEntranceAnimation({
    super.key,
    required this.child,
    required this.isMe,
    required this.animate,
  });

  final Widget child;
  final bool isMe;
  final bool animate;

  @override
  State<_MessageEntranceAnimation> createState() =>
      _MessageEntranceAnimationState();
}

class _MessageEntranceAnimationState extends State<_MessageEntranceAnimation>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  /// 随 controller 创建，避免 build 中每次新建导致监听器累积泄漏。
  CurvedAnimation? _curved;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 仅在首次创建且需要动画时启动；减少动态效果时直接跳过。
    if (_controller == null && widget.animate && !moeReduceMotion(context)) {
      _controller = AnimationController(
        vsync: this,
        duration: widget.isMe
            ? const Duration(milliseconds: 200)
            : const Duration(milliseconds: 240),
      )..forward();
      _curved = CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _curved?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final curved = _curved;
    if (controller == null || curved == null) return widget.child;
    if (widget.isMe) {
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          alignment: Alignment.bottomRight,
          child: widget.child,
        ),
      );
    }
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
