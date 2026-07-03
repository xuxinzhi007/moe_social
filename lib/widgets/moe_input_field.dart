import 'package:flutter/material.dart';
import 'package:moe_social/theme/moe_tokens.dart';

/// 萌社交统一输入框组件。
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
    this.style,
    this.hintStyle,
  });

  @override
  State<MoeInputField> createState() => _MoeInputFieldState();
}

class _MoeInputFieldState extends State<MoeInputField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      maxLines: widget.maxLines ?? (widget.isPassword ? 1 : null),
      minLines: widget.minLines,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction ??
          (widget.isPassword ? TextInputAction.done : TextInputAction.next),
      keyboardType: widget.keyboardType ??
          (widget.isPassword ? TextInputType.visiblePassword : null),
      onFieldSubmitted: widget.onFieldSubmitted,
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
    );
  }

  InputDecoration _buildDecoration() {
    // 前缀图标：优先 prefixIcon > icon 参数
    Widget? prefix = widget.prefixIcon;
    if (prefix == null && widget.icon != null) {
      prefix = Icon(
        widget.icon,
        color: widget.primaryColor.withValues(alpha: 0.6),
        size: 22,
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
          color: Colors.grey[300],
          size: 20,
        ),
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      );
    }

    return InputDecoration(
      filled: widget.filled,
      fillColor: widget.fillColor ?? MoeTokens.pageBackground,

      // 默认状态：无边框，圆角背景
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
        borderSide: BorderSide.none,
      ),

      // 聚焦状态：紫色 1.5px 边框
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
        borderSide: BorderSide(color: MoeTokens.primary, width: 1.5),
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
      suffixIcon: suffix,
    );
  }
}
