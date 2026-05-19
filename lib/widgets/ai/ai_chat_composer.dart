import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai_brand_tokens.dart';
import 'ai_theme.dart';

/// 角色聊天底部输入区：主输入框占满宽度，工具栏在下方。
class AiChatComposer extends StatefulWidget {
  const AiChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isListening,
    required this.isSending,
    required this.showQuickReplies,
    required this.onToggleListening,
    required this.onToggleQuickReplies,
    required this.onSend,
    this.onStop,
    this.quickRepliesPanel,
    this.canSend = true,
    this.agentName,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final bool isSending;
  final bool showQuickReplies;
  final bool canSend;
  final VoidCallback onToggleListening;
  final VoidCallback onToggleQuickReplies;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final Widget? quickRepliesPanel;
  final String? agentName;

  @override
  State<AiChatComposer> createState() => _AiChatComposerState();
}

class _AiChatComposerState extends State<AiChatComposer> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  void _onTextChange() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  String get _hintText {
    if (widget.isListening) return '正在聆听…';
    return '输入消息…';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.quickRepliesPanel != null) widget.quickRepliesPanel!,
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: AiBrandTokens.primary.withValues(alpha: 0.1),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AiBrandTokens.primary.withValues(alpha: 0.07),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(12, 10, 12, bottom + 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _focused
                        ? AiBrandTokens.primary.withValues(alpha: 0.45)
                        : AiBrandTokens.primary.withValues(alpha: 0.14),
                    width: _focused ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        maxLines: 8,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: AiTheme.body.copyWith(
                          fontSize: 16,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: _hintText,
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            14,
                            8,
                            14,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (!widget.isSending &&
                              widget.canSend &&
                              _hasText) {
                            widget.onSend();
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
                      child: _SendButton(
                        size: 40,
                        isSending: widget.isSending,
                        enabled:
                            widget.canSend && (_hasText || widget.isSending),
                        onSend: widget.onSend,
                        onStop: widget.onStop,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ToolbarIcon(
                    icon: widget.isListening
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    label: '语音',
                    active: widget.isListening,
                    activeColor: AiTheme.danger,
                    onPressed: widget.onToggleListening,
                  ),
                  const SizedBox(width: 4),
                  _ToolbarIcon(
                    icon: widget.showQuickReplies
                        ? Icons.keyboard_alt_outlined
                        : Icons.bolt_outlined,
                    label: widget.showQuickReplies ? '键盘' : '快捷',
                    active: widget.showQuickReplies,
                    onPressed: widget.onToggleQuickReplies,
                  ),
                  const Spacer(),
                  if (widget.agentName != null &&
                      widget.agentName!.trim().isNotEmpty)
                    Flexible(
                      child: Text(
                        widget.agentName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? (activeColor ?? AiBrandTokens.primary) : Colors.grey.shade600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.size,
    required this.isSending,
    required this.enabled,
    required this.onSend,
    this.onStop,
  });

  final double size;
  final bool isSending;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    if (isSending) {
      return Tooltip(
        message: '停止生成',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onStop,
            customBorder: const CircleBorder(),
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AiTheme.danger.withValues(alpha: 0.12),
                border: Border.all(
                  color: AiTheme.danger.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                Icons.stop_rounded,
                color: AiTheme.danger,
                size: size * 0.52,
              ),
            ),
          ),
        ),
      );
    }

    final active = enabled;
    return Tooltip(
      message: '发送',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active
              ? () {
                  HapticFeedback.lightImpact();
                  onSend();
                }
              : null,
          customBorder: const CircleBorder(),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: active ? 1 : 0.4,
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active
                    ? AiBrandTokens.heroGradient
                    : LinearGradient(
                        colors: [
                          Colors.grey.shade400,
                          Colors.grey.shade500,
                        ],
                      ),
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
