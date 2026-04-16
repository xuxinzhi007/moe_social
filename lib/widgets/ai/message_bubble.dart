import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 消息内容类型
enum MessageContentType {
  text,      // 纯文本
  thinking,  // 思考状态
  code,      // 代码块
}

// 消息气泡组件
class AiMessageBubble extends StatefulWidget {
  final String content;
  final MessageContentType contentType;
  final String? language; // 代码语言
  final bool isUser;
  final bool isLoading;
  final VoidCallback? onContentExpanded;

  const AiMessageBubble({
    Key? key,
    required this.content,
    required this.contentType,
    this.language,
    required this.isUser,
    this.isLoading = false,
    this.onContentExpanded,
  }) : super(key: key);

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('代码已复制到剪贴板')),
    );
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

  // 渲染纯文本内容
  Widget _renderTextContent() {
    final textColor = widget.isUser ? Colors.white : Colors.black87;
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
                      ? Colors.white.withOpacity(0.8)
                      : Colors.blue,
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
                      ? Colors.white.withOpacity(0.8)
                      : Colors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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
      children: [
        const Text('AI is thinking...', style: TextStyle(color: Colors.grey)),
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
                  color: Colors.grey.withOpacity(0.2),
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
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _isCopying
                    ? const Text('已复制', style: TextStyle(color: Colors.green, fontSize: 12))
                    : const Text('复制', style: TextStyle(color: Colors.grey, fontSize: 12)),
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(Icons.smart_toy_rounded, size: 18, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : widget.contentType == MessageContentType.code
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: isUser || widget.contentType == MessageContentType.code
                        ? [
                            BoxShadow(
                              color: (isUser ? const Color(0xFFE94057) : Colors.black).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: widget.contentType == MessageContentType.text
                      ? _renderTextContent()
                      : widget.contentType == MessageContentType.thinking
                          ? _renderThinkingContent()
                          : _renderCodeContent(),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE94057),
              child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
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

class _TypingDotsIndicatorState extends State<_TypingDotsIndicator> with SingleTickerProviderStateMixin {
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
  const Dot({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}
