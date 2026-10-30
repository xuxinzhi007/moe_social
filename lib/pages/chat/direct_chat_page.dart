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
import '../../widgets/motion/moe_sheet.dart';
import '../../widgets/moe_action_row.dart';
import 'direct_chat_viewmodel.dart';
import 'chat_skin_picker_page.dart';
import 'widgets/chat_empty_illustration.dart';

part 'direct_chat_bubble.part.dart';

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
    ChatPushService.setActiveChatPeer(widget.userId);
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
      unawaited(
        context
            .read<NotificationProvider>()
            .markDirectMessagesAsRead(widget.userId),
      );
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
            cancelHint ? Icons.cancel_rounded : Icons.keyboard_arrow_up_rounded,
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
    ChatPushService.setActiveChatPeer(null);
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

    final glassNav = FeatureFlags.glassNavigation;

    // 聊天主题皮肤（flag 开启时背景 / 气泡渐变跟随所选皮肤，并按亮度取深浅变体）。
    final chatSkin = FeatureFlags.chatThemeSkins
        ? context.watch<ChatThemeProvider>().currentSkin
        : null;
    final brightness = Theme.of(context).brightness;
    final scaffoldBg =
        chatSkin?.backgroundFor(brightness) ?? MoeTokens.surface0;

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: true,
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
                        ? Center(
                            child: MoeEmptyState(
                              image: const ChatEmptyIllustration(),
                              title: widget.username.trim().isEmpty
                                  ? '从第一句话开始'
                                  : '和 ${widget.username.trim()} 的对话，从第一句开始',
                              subtitle: '在下方输入消息，开启你们的对话',
                              compact: true,
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
                                        showSent: isMe &&
                                            index == 0 &&
                                            !_chat.isSending,
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
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording) _buildRecordingBar(),
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
    MoeSheet.show<void>(
      context,
      backgroundColor: MoeTokens.surface1,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            color: MoeTokens.surface1,
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
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 44, height: 44),
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  minimumSize: const Size(44, 44),
                  maximumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  backgroundColor: MoeTokens.surface0,
                  foregroundColor: MoeTokens.hintText,
                  disabledForegroundColor: MoeTokens.hintText.withValues(
                    alpha: 0.45,
                  ),
                  side: const BorderSide(color: MoeTokens.surfaceBorder),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
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
                    width: 44,
                    height: 44,
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
                      size: 20,
                      color:
                          _isRecording ? MoeTokens.danger : MoeTokens.hintText,
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
                      hintText: '发送消息',
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
                    width: 44,
                    height: 44,
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
                            size: 20,
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
