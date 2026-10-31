// Hallmark · layout: conversation-bubble · tone: kawaii-soft · scroll: list-view

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/ai_chat_message_utils.dart';
import '../../utils/ai_message_format_parser.dart';
import '../moe_toast.dart';
import '../motion/moe_motion.dart';
import 'ai_brand_tokens.dart';
import 'ai_draw_card.dart';
import 'ai_rich_message_body.dart';
import 'ai_theme.dart';

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
  final bool isStreamingContent;
  final VoidCallback? onContentExpanded;
  final String? agentLabel;
  final Widget? assistantAvatar;
  final Widget? userAvatar;
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
    this.isStreamingContent = false,
    this.onContentExpanded,
    this.agentLabel,
    this.assistantAvatar,
    this.userAvatar,
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

  Future<void> _copyMessage() async {
    final text = widget.content.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    MoeToast.success(context, '已复制');
  }

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
  Widget _renderTextContent({List<AiMessageBlock>? preparsedBlocks}) {
    if (widget.richFormat) {
      return AiRichMessageBody(
        content: widget.content,
        isUser: widget.isUser,
        isStreaming: widget.isStreamingContent,
        onExpanded: widget.onContentExpanded,
        preparsedBlocks: preparsedBlocks,
      );
    }

    final textColor = widget.isUser ? Colors.white : MoeTokens.titleText;
    final text = widget.content;
    final compact = widget.airyCompanion;
    // 助手长文默认全文展示（由外层 ListView 滚动）；仅用户侧保留「多行折叠 + 展开」省屏。
    final collapseUserLongText =
        widget.isUser && !_isExpanded && text.length > 200;
    final maxLines = collapseUserLongText ? 5 : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: compact ? 14 : 15,
            height: compact ? 1.4 : 1.5,
          ),
          maxLines: maxLines,
          overflow: collapseUserLongText ? TextOverflow.ellipsis : null,
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
            const Expanded(
              child: Text(
                '回复没有送达',
                style: TextStyle(
                  fontSize: MoeTokens.textMd,
                  fontWeight: MoeTokens.fontWeightSubtitle,
                  color: AiBrandTokens.titleColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MoeTokens.spaceSm),
        Text(
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
    const textColor = Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: Text(
                widget.content,
                style: const TextStyle(
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

  Widget _buildBubbleRow({
    required BuildContext context,
    required Widget bubbleChild,
    required double maxBubbleWidth,
    required bool isError,
    required bool showAvatar,
  }) {
    final isUser = widget.isUser;
    final bubblePadding = isError
        ? const EdgeInsets.fromLTRB(
            MoeTokens.spaceMd,
            MoeTokens.spaceMd,
            MoeTokens.spaceSm,
            MoeTokens.spaceSm,
          )
        : EdgeInsets.symmetric(
            horizontal: widget.airyCompanion ? 14 : MoeTokens.spaceLg,
            vertical: widget.airyCompanion ? 10 : MoeTokens.spaceMd,
          );

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          (!showAvatar || widget.hideAvatar)
              ? const SizedBox(width: 32)
              : _buildAssistantAvatar(),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: GestureDetector(
            onLongPress: widget.isLoading || widget.content.trim().isEmpty
                ? null
                : _copyMessage,
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
                          isError ? MoeTokens.radiusLg : MoeTokens.radiusXl,
                        ),
                        topRight: const Radius.circular(MoeTokens.radiusXl),
                        bottomLeft: isUser
                            ? const Radius.circular(MoeTokens.radiusXl)
                            : Radius.circular(
                                isError
                                    ? MoeTokens.radiusLg
                                    : MoeTokens.radiusSm,
                              ),
                        bottomRight: isUser
                            ? const Radius.circular(MoeTokens.radiusSm)
                            : const Radius.circular(MoeTokens.radiusXl),
                      ),
                      border: !isUser &&
                              (isError ||
                                  widget.contentType != MessageContentType.code)
                          ? Border.all(
                              color: isError
                                  ? AiTheme.danger.withValues(alpha: 0.22)
                                  : MoeTokens.surfaceBorder,
                              width: 1,
                            )
                          : null,
                      boxShadow: MoeTokens.shadowSm(),
                    ),
                    child: bubbleChild,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isUser && widget.bubbleAction != null) ...[
          const SizedBox(width: 6),
          widget.bubbleAction!,
        ],
        if (isUser && !widget.hideAvatar) ...[
          const SizedBox(width: 8),
          widget.userAvatar ??
              CircleAvatar(
                radius: 16,
                backgroundColor: AiBrandTokens.secondary,
                child: Icon(Icons.person_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.95)),
              ),
        ],
      ],
    );
  }

  /// 独立渲染图片/媒体消息行：外层不套聊天气泡，直接展示圆角图片卡片。
  Widget _buildStandaloneDrawRow({
    required AiMessageBlock drawBlock,
    required double maxMediaWidth,
    required bool showAvatar,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        (!showAvatar || widget.hideAvatar)
            ? const SizedBox(width: 32)
            : _buildAssistantAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxMediaWidth),
            child: AiDrawCard(
              prompt: drawBlock.content,
              isIncomplete: drawBlock.isIncomplete,
              autoGenerateOnMount: widget.isStreamingContent,
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

    // 当助手富文本中包含 <draw> 绘画指令时，将「文字消息」与「图片消息」拆成独立的两条消息，
    // 且图片消息外层不再包裹聊天气泡。
    if (!isUser &&
        !isError &&
        !widget.isLoading &&
        widget.contentType == MessageContentType.text &&
        widget.richFormat &&
        widget.content.trim().isNotEmpty) {
      final formatted =
          AiChatMessageUtils.formatRoleplayContent(widget.content);
      final blocks = parseAiMessageContent(formatted);
      final hasDraw = blocks.any((b) => b.kind == AiMessageBlockKind.draw);

      if (hasDraw) {
        final rows = <Widget>[];
        var pendingTextBlocks = <AiMessageBlock>[];

        void flushTextBlocks() {
          if (pendingTextBlocks.isEmpty) return;
          final chunk = List<AiMessageBlock>.from(pendingTextBlocks);
          pendingTextBlocks.clear();
          rows.add(
            _buildBubbleRow(
              context: context,
              bubbleChild: _renderTextContent(preparsedBlocks: chunk),
              maxBubbleWidth: maxBubbleWidth,
              isError: false,
              showAvatar: true,
            ),
          );
        }

        for (final block in blocks) {
          if (block.kind == AiMessageBlockKind.draw) {
            flushTextBlocks();
            rows.add(
              _buildStandaloneDrawRow(
                drawBlock: block,
                maxMediaWidth: maxBubbleWidth,
                showAvatar: true,
              ),
            );
          } else if (block.content.trim().isNotEmpty) {
            pendingTextBlocks.add(block);
          }
        }
        flushTextBlocks();

        if (rows.isNotEmpty) {
          return Container(
            margin: EdgeInsets.only(top: widget.compactTop ? 2 : 8, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  rows[i],
                ],
              ],
            ),
          );
        }
      }
    }

    final Widget innerChild = isError
        ? _renderErrorContent()
        : (!widget.isUser && widget.isLoading && widget.content.trim().isEmpty)
            ? _renderThinkingContent()
            : widget.contentType == MessageContentType.text
                ? _renderTextContent()
                : widget.contentType == MessageContentType.thinking
                    ? _renderThinkingContent()
                    : _renderCodeContent();

    return Container(
      margin: EdgeInsets.only(top: widget.compactTop ? 2 : 8, bottom: 6),
      child: _buildBubbleRow(
        context: context,
        bubbleChild: innerChild,
        maxBubbleWidth: maxBubbleWidth,
        isError: isError,
        showAvatar: true,
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
