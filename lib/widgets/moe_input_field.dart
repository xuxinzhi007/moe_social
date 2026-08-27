import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:moe_social/theme/moe_tokens.dart';

/// 萌社交统一输入框组件 — 渐变背景 + 聚焦发光 + 图标渐变圆圈。
///
/// 作为项目唯一标准输入框，覆盖登录/注册/发帖/搜索等全部场景。
/// 所有视觉参数基于 [MoeTokens]，保持全局一致性。
class MoeInputField extends StatefulWidget {
  // ─── 核心参数（向后兼容） ──────────────────────────────────────────
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final bool isPassword;
  final Color primaryColor;
  final VoidCallback? onEditingComplete;

  // ─── 扩展参数 ────────────────────────────────────────────────────
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool filled;
  final Color? fillColor;
  final AutovalidateMode? autovalidateMode;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextStyle? hintStyle;

  const MoeInputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.isPassword = false,
    this.primaryColor = const Color(0xFF7F7FD5),
    this.onEditingComplete,
    // 扩展参数
    this.maxLines,
    this.minLines,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.prefixIcon,
    this.filled = true,
    this.fillColor,
    this.autovalidateMode,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
    this.inputFormatters,
    this.style,
    this.hintStyle,
  });

  @override
  State<MoeInputField> createState() => _MoeInputFieldState();
}

class _MoeInputFieldState extends State<MoeInputField> {
  bool _obscurePassword = true;
  late FocusNode _internalFocus;
  bool _isFocused = false;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocus;

  @override
  void initState() {
    super.initState();
    _internalFocus = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant MoeInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (oldWidget.focusNode == null) _internalFocus.dispose();
      _internalFocus = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode == null) _internalFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MoeTokens.motionMedium,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MoeTokens.radiusInput + 4),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: widget.primaryColor.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        maxLines: widget.maxLines ?? (widget.isPassword ? 1 : null),
        minLines: widget.minLines,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        focusNode: _focusNode,
        textInputAction: widget.textInputAction ??
            (widget.isPassword ? TextInputAction.done : TextInputAction.next),
        keyboardType: widget.keyboardType ??
            (widget.isPassword ? TextInputType.visiblePassword : null),
        onFieldSubmitted: widget.onFieldSubmitted,
        onChanged: widget.onChanged,
        inputFormatters: widget.inputFormatters,
        onEditingComplete: widget.onEditingComplete,
        validator: widget.validator,
        autovalidateMode:
            widget.autovalidateMode ?? AutovalidateMode.disabled,
        obscureText: widget.isPassword && _obscurePassword,
        style: widget.style ??
            TextStyle(
              fontSize: MoeTokens.textBase,
              color: MoeTokens.titleText,
            ),
        decoration: _buildDecoration(),
      ),
    );
  }

  InputDecoration _buildDecoration() {
    // 前缀图标：渐变圆形容器内的图标
    Widget? prefix = widget.prefixIcon;
    if (prefix == null && widget.icon != null) {
      prefix = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: _isFocused
              ? MoeTokens.gradientPrimary
              : LinearGradient(
                  colors: [
                    widget.primaryColor.withValues(alpha: 0.10),
                    widget.primaryColor.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          color: _isFocused ? Colors.white : widget.primaryColor.withValues(alpha: 0.6),
          size: 16,
        ),
      );
    }

    // 后缀图标：优先 suffixIcon > 密码切换按钮
    Widget? suffix = widget.suffixIcon;
    if (suffix == null && widget.isPassword) {
      suffix = IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: Colors.grey[400],
          size: 20,
        ),
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      );
    }

    return InputDecoration(
      filled: widget.filled,
      fillColor: widget.fillColor ?? Colors.white.withValues(alpha: 0.6),

      // 默认状态：半透明边框
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
        borderSide: BorderSide(color: MoeTokens.surfaceBorder.withAlpha(20)),
      ),

      // 聚焦状态：渐变边框色
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
        borderSide: BorderSide(
          color: widget.primaryColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),

      // 错误状态：红色 1.5px 边框
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),

      // 聚焦+错误：红色 1.5px 边框
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),

      contentPadding: EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg,
        vertical: MoeTokens.spaceMd,
      ),

      hintText: widget.hintText,
      hintStyle: widget.hintStyle ??
          TextStyle(color: MoeTokens.hintText, fontSize: MoeTokens.textBase),

      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(
        minWidth: 42,
        minHeight: 42,
      ),
      suffixIcon: suffix,
    );
  }
}
