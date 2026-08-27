import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'moe_loading.dart';
import 'motion/moe_pressable.dart';

/// 萌社交统一按钮组件 — 渐变背景 + 光晕阴影 + 弹性按压。
///
/// 支持三种模式：
/// - 默认（渐变填充 + 光晕）
/// - [isOutline]（半透明描边 + 微背景）
/// - 自定义 [backgroundColor]（纯色覆盖渐变）
///
/// 尺寸优先使用 [size] 档位（读取 [MoeTokens] 按钮 token），
/// 显式 [height]/[padding] 仍优先，保持向后兼容。
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

  /// 尺寸档位；不传默认 [MoeButtonSize.medium]（高 48）。
  final MoeButtonSize? size;

  /// 可选图标，非空时渲染在文字左侧，颜色继承文字色。
  final IconData? icon;

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
    this.size,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primary = backgroundColor ?? MoeTokens.primary;
    final onPrimary = textColor ?? Colors.white;
    final radius = borderRadius ?? BorderRadius.circular(MoeTokens.radiusButton);
    final enabled = !(isLoading || isDisabled) && onPressed != null;
    final useGradient = backgroundColor == null && !isOutline;
    // 不可点（onPressed: null / isLoading / isDisabled）时降透明度提示禁用态。
    final disabled = !enabled;

    // 尺寸解析：显式 height > size 档位 > 默认 medium（48，与历史行为一致）
    final effectiveSize = size ?? MoeButtonSize.medium;
    final effectiveHeight = height ?? effectiveSize.height;
    final effectivePadding =
        padding ?? EdgeInsets.symmetric(horizontal: effectiveSize.horizontalPadding);

    Widget button;
    if (isOutline) {
      button = _buildOutlineButton(primary, onPrimary, radius, enabled, disabled, effectivePadding);
    } else {
      button = _buildFilledButton(primary, onPrimary, radius, enabled, disabled, useGradient, effectivePadding);
    }

    return SizedBox(
      width: width,
      height: effectiveHeight,
      child: enabled
          ? MoePressable(
              onTap: onPressed,
              borderRadius: radius,
              child: IgnorePointer(child: button),
            )
          : button,
    );
  }

  /// 填充按钮 — 渐变背景 + 光晕阴影；disabled 时装饰降透明度。
  Widget _buildFilledButton(
    Color primary,
    Color onPrimary,
    BorderRadius radius,
    bool enabled,
    bool disabled,
    bool useGradient,
    EdgeInsets padding,
  ) {
    const disabledAlpha = 0.45;
    return Container(
      decoration: BoxDecoration(
        gradient: useGradient
            ? (disabled
                ? LinearGradient(
                    colors: MoeTokens.gradientPrimary.colors
                        .map((c) => c.withValues(alpha: disabledAlpha))
                        .toList(),
                    begin: MoeTokens.gradientPrimary.begin,
                    end: MoeTokens.gradientPrimary.end,
                  )
                : MoeTokens.gradientPrimary)
            : null,
        color: useGradient
            ? null
            : primary.withValues(alpha: disabled ? disabledAlpha : 1.0),
        borderRadius: radius,
        // 不可点时移除光晕阴影，弱化视觉权重。
        boxShadow: enabled ? MoeTokens.shadowGlow(primary) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Center(child: Padding(
            padding: padding,
            child: _buildContent(onPrimary),
          )),
        ),
      ),
    );
  }

  /// 轮廓按钮 — 半透明背景 + 品牌色描边；disabled 时描边/底色减弱。
  Widget _buildOutlineButton(
    Color primary,
    Color onPrimary,
    BorderRadius radius,
    bool enabled,
    bool disabled,
    EdgeInsets padding,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: disabled ? 0.03 : 0.06),
        borderRadius: radius,
        border: Border.all(
          color: primary.withValues(alpha: disabled ? 0.15 : 0.30),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Center(child: Padding(
            padding: padding,
            child: _buildContent(primary),
          )),
        ),
      ),
    );
  }

  Widget _buildContent(Color color) {
    if (isLoading) {
      return MoeSmallLoading(
        size: 20,
        color: color,
      );
    }

    final textStyle = TextStyle(
      fontSize: fontSize ?? MoeTokens.fontSizeButton,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: 0.5,
    );

    // 固定 width + 长文案保护：单行省略，避免撑破按钮。
    final label = Text(
      text,
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (icon == null) {
      return label;
    }

    // 图标 + 文字：图标颜色继承文字色，间距用 spaceSm；
    // 文字用 Flexible 包裹保证溢出时省略而非撑破布局。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: textStyle.fontSize, color: color),
        SizedBox(width: MoeTokens.spaceSm),
        Flexible(child: label),
      ],
    );
  }
}

/// 按钮尺寸档位 — 高度/水平内边距均读取 [MoeTokens] 按钮 token。
enum MoeButtonSize {
  /// 40 高 / 16 内边距 — 紧凑列表、弹窗次级操作
  small,

  /// 48 高 / 20 内边距 — 默认档位
  medium,

  /// 56 高 / 24 内边距 — 登录/注册等主 CTA
  large;

  double get height => switch (this) {
    small => MoeTokens.btnHeightSm,
    medium => MoeTokens.btnHeightMd,
    large => MoeTokens.btnHeightLg,
  };

  double get horizontalPadding => switch (this) {
    small => MoeTokens.btnPadSm,
    medium => MoeTokens.btnPadMd,
    large => MoeTokens.btnPadLg,
  };
}
