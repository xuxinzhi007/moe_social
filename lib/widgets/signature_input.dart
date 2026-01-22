import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 个性签名输入组件
/// 支持多行文本输入，最大100字符限制
class SignatureInput extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;

  const SignatureInput({
    super.key,
    this.initialValue = '',
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  State<SignatureInput> createState() => _SignatureInputState();
}

class _SignatureInputState extends State<SignatureInput> {
  late TextEditingController _controller;
  static const int _maxLength = 100;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(SignatureInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.errorText != null
                  ? theme.colorScheme.error
                  : theme.dividerColor,
              width: 1.5,
            ),
            color: widget.enabled
                ? theme.cardColor
                : theme.disabledColor.withValues(alpha: 0.1),
          ),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                enabled: widget.enabled,
                maxLength: _maxLength,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: '写下你的个性签名...',
                  hintStyle: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  counterText: '', // 隐藏默认计数器，使用自定义计数器
                ),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: widget.enabled
                      ? theme.textTheme.bodyMedium?.color
                      : theme.disabledColor,
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_maxLength),
                ],
                onChanged: (value) {
                  widget.onChanged(value);
                  setState(() {}); // 更新字符计数器
                },
              ),
              // 自定义字符计数器
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_controller.text.length}/$_maxLength',
                      style: TextStyle(
                        fontSize: 12,
                        color: _controller.text.length >= _maxLength
                            ? theme.colorScheme.error
                            : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 错误提示
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              widget.errorText!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],

        // 友好提示
        if (widget.errorText == null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '个性签名将在你的个人资料中展示',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
