part of 'direct_chat_page.dart';

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

extension _DirectChatBubbleWidgets on _DirectChatPageState {
  Widget _buildTimeTag(BuildContext context, DateTime time) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MoeTokens.spaceMd),
        child: Text(
          _formatTime(time),
          style: const TextStyle(
            color: MoeTokens.hintText,
            fontSize: MoeTokens.textXs,
            fontWeight: MoeTokens.fontWeightCaption,
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
    required bool showSent,
    required ChatSkin? chatSkin,
    required Brightness brightness,
  }) {
    final maxW = MediaQuery.sizeOf(context).width * 0.74;
    final peerFallback =
        brightness == Brightness.dark ? const Color(0xFF32324F) : Colors.white;
    final bubbleBg = isMe
        ? MoeTokens.primary
        : chatSkin?.peerColorFor(brightness) ?? peerFallback;
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
      final imageW =
          (MediaQuery.sizeOf(context).width * 0.55).clamp(160.0, 280.0);
      bubbleChild = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: imageW,
          maxHeight: 280,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          child: CachedNetworkImage(
            imageUrl: _chat.imageUrlOf(message.content),
            fit: BoxFit.cover,
            width: imageW,
            memCacheWidth: (imageW * 2).round(),
            maxWidthDiskCache: 800,
            placeholder: (context, url) => SizedBox(
              width: imageW,
              height: imageW * 0.75,
              child: const Center(
                child: MoeSmallLoading(
                  size: 24,
                  color: MoeTokens.primary,
                ),
              ),
            ),
            errorWidget: (context, url, error) => SizedBox(
              width: imageW,
              height: 80,
              child: Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: isMe ? Colors.white70 : MoeTokens.hintText,
              ),
            ),
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
    final skinGradient = (chatSkin ?? ChatSkins.lavender).bubbleMeGradient;
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
                    (brightness == Brightness.dark
                        ? const Color(0x33FFFFFF)
                        : const Color(0x337F7FD5)),
              ),
        boxShadow: isMe ? MoeTokens.shadowSm() : null,
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
                  const SizedBox(height: MoeTokens.spaceXs),
                  const Text(
                    '发送中...',
                    style: TextStyle(
                      fontSize: MoeTokens.textXs,
                      color: MoeTokens.hintText,
                    ),
                  ),
                ] else if (showSent) ...[
                  const SizedBox(height: MoeTokens.spaceXs),
                  const Text(
                    '已发送',
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
}
