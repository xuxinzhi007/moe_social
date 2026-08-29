// Hallmark · layout: conversation-bubble · tone: kawaii-soft · scroll: list-view

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../moe_toast.dart';
import '../../theme/moe_tokens.dart';
import 'ai_brand_tokens.dart';
import 'ai_theme.dart';
import 'ai_rich_message_body.dart';
import '../motion/moe_motion.dart';

// 消息内容类型
enum MessageContentType {
  text, // 纯文本
  thinking, // 思考状态
  code, // 代码块
}

// 消息气泡组件
class AiMessageBubble extends StatefulWidget {
  final String content;
  final MessageContentType contentType;
  final String? language; // 代码语言
  final bool isUser;
  final bool isLoading;
  final VoidCallback? onContentExpanded;
  final String? agentLabel;
  final Widget? assistantAvatar;
  final Widget? bubbleAction;
  final bool richFormat;
  final bool hideAvatar;
  final bool compactTop;

  /// 陪伴对话气泡：雾面表面、不对称圆角、轻色影（Airy Moe）。
  final bool airyCompanion;
  final bool isError;
  final VoidCallback? onErrorAction;
  final String errorActionLabel;

  const AiMessageBubble({
    super.key,
    required this.content,
    required this.contentType,
    this.language,
    required this.isUser,
    this.isLoading = false,
    this.onContentExpanded,
    this.agentLabel,
    this.assistantAvatar,
    this.bubbleAction,
    this.richFormat = false,
    this.hideAvatar = false,
    this.compactTop = false,
    this.airyCompanion = false,
    this.isError = false,
    this.onErrorAction,
    this.errorActionLabel = '重试',
  });

  @override
  State<AiMessageBubble> createState() => _AiMessageBubbleState();
}

class _AiMessageBubbleState extends State<AiMessageBubble> {
  bool _isExpanded = false;
  bool _isCopying = false;

  // 复制代码到剪贴板
  Future<void> _copyCode() async {
    setState(() => _isCopying = true);
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    MoeToast.success(context, '代码已复制到剪贴板');
    setState(() => _isCopying = false);
  }

  // 切换展开/折叠状态
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded && widget.onContentExpanded != null) {
        widget.onContentExpanded!();
      }
    });
  }

  Widget _buildAssistantAvatar() {
    if (widget.assistantAvatar != null) return widget.assistantAvatar!;
    final label = widget.agentLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AiBrandTokens.heroGradient,
        ),
        child: Text(
          label.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AiBrandTokens.primary.withValues(alpha: 0.12),
      ),
      child: const Icon(
        Icons.smart_toy_rounded,
        size: 18,
        color: AiBrandTokens.primary,
      ),
    );
  }

  // 渲染纯文本内容
  Widget _renderTextContent() {
    if (widget.richFormat) {
      return AiRichMessageBody(
        content: widget.content,
        isUser: widget.isUser,
        onExpanded: widget.onContentExpanded,
      );
    }

    final textColor = widget.isUser ? Colors.white : MoeTokens.titleText;
    final text = widget.content;
    // 助手长文默认全文展示（由外层 ListView 滚动）；仅用户侧保留「多行折叠 + 展开」省屏。
    final collapseUserLongText =
        widget.isUser && !_isExpanded && text.length > 200;
    final maxLines = collapseUserLongText ? 5 : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.5,
          ),
          maxLines: maxLines,
        ),
        if (collapseUserLongText)
          GestureDetector(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '展开',
                style: TextStyle(
                  color: widget.isUser
                      ? Colors.white.withValues(alpha: 0.85)
                      : AiBrandTokens.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (widget.isUser && _isExpanded && text.length > 200)
          GestureDetector(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '收起',
                style: TextStyle(
                  color: widget.isUser
                      ? Colors.white.withValues(alpha: 0.85)
                      : AiBrandTokens.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _renderErrorContent() {
    final errorColor = AiTheme.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
              ),
              child: Icon(
                Icons.sync_problem_rounded,
                size: 17,
                color: errorColor,
              ),
            ),
            const SizedBox(width: MoeTokens.spaceSm),
            Expanded(
              child: Text(
                '回复没有送达',
                style: const TextStyle(
                  fontSize: MoeTokens.textMd,
                  fontWeight: MoeTokens.fontWeightSubtitle,
                  color: AiBrandTokens.titleColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MoeTokens.spaceSm),
        SelectableText(
          widget.content,
          style: AiTheme.body.copyWith(
            color: AiBrandTokens.titleColor.withValues(alpha: 0.82),
            height: 1.45,
          ),
        ),
        if (widget.onErrorAction != null)
          Padding(
            padding: const EdgeInsets.only(top: MoeTokens.spaceSm),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onErrorAction,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(widget.errorActionLabel),
                style: TextButton.styleFrom(
                  foregroundColor: errorColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MoeTokens.spaceSm,
                    vertical: MoeTokens.spaceXs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 渲染思考状态
  Widget _renderThinkingContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '正在输入',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        const _TypingDotsIndicator(),
      ],
    );
  }

  // 渲染代码块
  Widget _renderCodeContent() {
    final textColor = Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 代码语言标签和复制按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.language != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.language!,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            GestureDetector(
              onTap: _copyCode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _isCopying
                    ? const Text('已复制',
                        style: TextStyle(color: Colors.green, fontSize: 12))
                    : const Text('复制',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 代码内容
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: Text(
                widget.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontFamily: 'Monaco',
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.isUser;
    final isError = widget.isError && !isUser;
    final maxBubbleWidth = MediaQuery.sizeOf(context).width *
        (isUser
            ? (widget.airyCompanion ? 0.74 : 0.78)
            : (widget.airyCompanion ? 0.80 : 0.82));
    final showCompanionAccent = widget.airyCompanion &&
        !isUser &&
        !isError &&
        widget.contentType != MessageContentType.code;
    final bubblePadding = isError
        ? const EdgeInsets.fromLTRB(
            MoeTokens.spaceMd,
            MoeTokens.spaceMd,
            MoeTokens.spaceSm,
            MoeTokens.spaceSm,
          )
        : EdgeInsets.symmetric(
            horizontal:
                widget.airyCompanion ? MoeTokens.spaceMd : MoeTokens.spaceLg,
            vertical:
                widget.airyCompanion ? MoeTokens.spaceMd : MoeTokens.spaceMd,
          );

    return Container(
      margin: EdgeInsets.only(top: widget.compactTop ? 2 : 8, bottom: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            widget.hideAvatar
                ? const SizedBox(width: 40)
                : _buildAssistantAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: bubblePadding,
                    decoration: BoxDecoration(
                      gradient: isUser ? MoeTokens.primaryGradient : null,
                      color: isUser
                          ? null
                          : isError
                              ? AiTheme.danger.withValues(alpha: 0.06)
                              : widget.contentType == MessageContentType.code
                                  ? const Color(0xFF1E1E1E)
                                  : widget.airyCompanion
                                      ? AiBrandTokens.companionSurface
                                      : MoeTokens.cardBackground,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                          isError
                              ? MoeTokens.radiusLg
                              : widget.airyCompanion && !isUser
                                  ? MoeTokens.radiusMd
                                  : MoeTokens.radiusXl,
                        ),
                        topRight: const Radius.circular(MoeTokens.radiusXl),
                        bottomLeft: isUser
                            ? const Radius.circular(MoeTokens.radiusXl)
                            : Radius.circular(
                                isError
                                    ? MoeTokens.radiusLg
                                    : widget.airyCompanion
                                        ? MoeTokens.radiusXl
                                        : MoeTokens.radiusSm,
                              ),
                        bottomRight: isUser
                            ? const Radius.circular(MoeTokens.radiusMd)
                            : const Radius.circular(MoeTokens.radiusXl),
                      ),
                      border: !isUser &&
                              (isError ||
                                  widget.contentType != MessageContentType.code)
                          ? Border.all(
                              color: isError
                                  ? AiTheme.danger.withValues(alpha: 0.22)
                                  : widget.airyCompanion
                                      ? MoeTokens.primary
                                          .withValues(alpha: 0.16)
                                      : AiBrandTokens.primary
                                          .withValues(alpha: 0.08),
                              width: isError
                                  ? 1
                                  : widget.airyCompanion
                                      ? 1.2
                                      : 1,
                            )
                          : null,
                      boxShadow: isUser ||
                              widget.contentType == MessageContentType.code
                          ? MoeTokens.shadowMd()
                          : MoeTokens.shadowSm(),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (showCompanionAccent)
                          Positioned(
                            left: -MoeTokens.spaceSm + MoeTokens.spaceXs / 2,
                            top: MoeTokens.spaceSm,
                            bottom: MoeTokens.spaceSm,
                            child: Container(
                              width: 3,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(MoeTokens.radiusFull),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    MoeTokens.primary.withValues(alpha: 0.55),
                                    MoeTokens.accent.withValues(alpha: 0.35),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: showCompanionAccent ? MoeTokens.spaceSm : 0,
                            right: widget.bubbleAction == null
                                ? 0
                                : MoeTokens.space3xl,
                          ),
                          child: isError
                              ? _renderErrorContent()
                              : (!widget.isUser &&
                                      widget.isLoading &&
                                      widget.content.trim().isEmpty)
                                  ? _renderThinkingContent()
                                  : widget.contentType ==
                                          MessageContentType.text
                                      ? _renderTextContent()
                                      : widget.contentType ==
                                              MessageContentType.thinking
                                          ? _renderThinkingContent()
                                          : _renderCodeContent(),
                        ),
                        if (widget.bubbleAction != null)
                          Positioned(
                            top: -MoeTokens.spaceSm,
                            right: -MoeTokens.spaceSm,
                            child: widget.bubbleAction!,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser && !widget.hideAvatar) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AiBrandTokens.secondary,
              child: Icon(Icons.person_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.95)),
            ),
          ],
        ],
      ),
    );
  }
}

// 打字指示器组件
class _TypingDotsIndicator extends StatefulWidget {
  const _TypingDotsIndicator();

  @override
  State<_TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<_TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _animation1 = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.33)),
    );
    _animation2 = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.33, 0.66)),
    );
    _animation3 = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.66, 1.0)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (moeReduceMotion(context)) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Dot(),
          SizedBox(width: 4),
          Dot(),
          SizedBox(width: 4),
          Dot(),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation1,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation1.value,
              child: child,
            );
          },
          child: const Dot(),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: _animation2,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation2.value,
              child: child,
            );
          },
          child: const Dot(),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: _animation3,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation3.value,
              child: child,
            );
          },
          child: const Dot(),
        ),
      ],
    );
  }
}

// 点组件
class Dot extends StatelessWidget {
  const Dot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AiBrandTokens.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
