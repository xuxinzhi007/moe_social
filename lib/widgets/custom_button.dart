import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_pressable.dart';

/// 萌社交统一按钮组件 — 渐变背景 + 光晕阴影 + 弹性按压。
///
/// 支持三种模式：
/// - 默认（渐变填充 + 光晕）
/// - [isOutline]（半透明描边 + 微背景）
/// - 自定义 [backgroundColor]（纯色覆盖渐变）
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final double? fontSize;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final bool isOutline;
  final double? elevation;
  final Color? shadowColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.fontSize,
    this.padding,
    this.borderRadius,
    this.isOutline = false,
    this.elevation,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = backgroundColor ?? MoeTokens.primary;
    final onPrimary = textColor ?? Colors.white;
    final radius = borderRadius ?? BorderRadius.circular(MoeTokens.radiusButton);
    final enabled = !(isLoading || isDisabled) && onPressed != null;
    final useGradient = backgroundColor == null && !isOutline;

    Widget button;
    if (isOutline) {
      button = _buildOutlineButton(primary, onPrimary, radius, enabled);
    } else {
      button = _buildFilledButton(primary, onPrimary, radius, enabled, useGradient);
    }

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: enabled
          ? MoePressable(
              onTap: onPressed,
              borderRadius: radius,
              child: IgnorePointer(child: button),
            )
          : button,
    );
  }

  /// 填充按钮 — 渐变背景 + 光晕阴影
  Widget _buildFilledButton(
    Color primary,
    Color onPrimary,
    BorderRadius radius,
    bool enabled,
    bool useGradient,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: useGradient ? MoeTokens.gradientPrimary : null,
        color: useGradient ? null : primary,
        borderRadius: radius,
        boxShadow: (!isDisabled && enabled)
            ? MoeTokens.shadowGlow(primary)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Center(child: _buildContent(onPrimary)),
        ),
      ),
    );
  }

  /// 轮廓按钮 — 半透明背景 + 品牌色描边
  Widget _buildOutlineButton(
    Color primary,
    Color onPrimary,
    BorderRadius radius,
    bool enabled,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: radius,
        border: Border.all(
          color: primary.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Center(child: _buildContent(primary)),
        ),
      ),
    );
  }

  Widget _buildContent(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 2.5,
        ),
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize ?? 16,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}
