import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../utils/ai_message_format_parser.dart';
import '../moe_toast.dart';
import 'ai_brand_tokens.dart';

/// 酒馆 / flai 风格：Markdown 段落 + 代码/JSON 围栏块。
class AiRichMessageBody extends StatelessWidget {
  const AiRichMessageBody({
    super.key,
    required this.content,
    required this.isUser,
    this.onExpanded,
  });

  final String content;
  final bool isUser;
  final VoidCallback? onExpanded;

  @override
  Widget build(BuildContext context) {
    final blocks = parseAiMessageContent(content);
    final textColor = isUser ? Colors.white : Colors.black87;

    if (blocks.length == 1 && blocks.first.kind == AiMessageBlockKind.text) {
      return _MarkdownSegment(
        text: blocks.first.content,
        textColor: textColor,
        isUser: isUser,
        onExpanded: onExpanded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          switch (blocks[i].kind) {
            AiMessageBlockKind.text => _MarkdownSegment(
                text: blocks[i].content,
                textColor: textColor,
                isUser: isUser,
                onExpanded: onExpanded,
              ),
            AiMessageBlockKind.json => _CodeFenceBlock(
                content: formatJsonForDisplay(blocks[i].content),
                language: 'json',
                isUser: isUser,
              ),
            AiMessageBlockKind.code => _CodeFenceBlock(
                content: blocks[i].content,
                language: blocks[i].language,
                isUser: isUser,
              ),
          },
        ],
      ],
    );
  }
}

class _MarkdownSegment extends StatelessWidget {
  const _MarkdownSegment({
    required this.text,
    required this.textColor,
    required this.isUser,
    this.onExpanded,
  });

  final String text;
  final Color textColor;
  final bool isUser;
  final VoidCallback? onExpanded;

  @override
  Widget build(BuildContext context) {
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(color: textColor, fontSize: 15, height: 1.55),
      strong: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      em: TextStyle(
        color: textColor.withValues(alpha: 0.92),
        fontStyle: FontStyle.italic,
      ),
      code: TextStyle(
        color: isUser ? Colors.white : AiBrandTokens.primary,
        backgroundColor: isUser
            ? Colors.white.withValues(alpha: 0.15)
            : AiBrandTokens.primary.withValues(alpha: 0.08),
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      blockquote: TextStyle(
        color: textColor.withValues(alpha: 0.85),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isUser
                ? Colors.white.withValues(alpha: 0.5)
                : AiBrandTokens.primary.withValues(alpha: 0.35),
            width: 3,
          ),
        ),
      ),
      listBullet: TextStyle(color: textColor, fontSize: 15),
      h1: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w800),
      h2: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
      h3: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
    );

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: sheet,
      shrinkWrap: true,
      softLineBreak: true,
    );
  }
}

class _CodeFenceBlock extends StatefulWidget {
  const _CodeFenceBlock({
    required this.content,
    required this.isUser,
    this.language,
  });

  final String content;
  final bool isUser;
  final String? language;

  @override
  State<_CodeFenceBlock> createState() => _CodeFenceBlockState();
}

class _CodeFenceBlockState extends State<_CodeFenceBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
    MoeToast.success(context, '已复制');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.language?.trim();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.white.withValues(alpha: 0.06),
            child: Row(
              children: [
                if (label != null && label.isNotEmpty)
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                const Spacer(),
                InkWell(
                  onTap: _copy,
                  child: Text(
                    _copied ? '已复制' : '复制',
                    style: TextStyle(
                      color: _copied ? Colors.greenAccent : Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                widget.content,
                style: const TextStyle(
                  color: Color(0xFFE8E8E8),
                  fontSize: 13,
                  height: 1.45,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
