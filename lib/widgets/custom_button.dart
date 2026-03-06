import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final primary = backgroundColor ?? theme.primaryColor;
    final onPrimary = textColor ?? Colors.white;
    final radius = borderRadius ?? BorderRadius.circular(25); // 默认为圆角胶囊形

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: isOutline
          ? OutlinedButton(
              onPressed: (isLoading || isDisabled) ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary, width: 1.5),
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: radius),
                splashFactory: InkRipple.splashFactory,
              ),
              child: _buildContent(primary),
            )
          : ElevatedButton(
              onPressed: (isLoading || isDisabled) ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: onPrimary,
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
                elevation: elevation ?? (isDisabled ? 0 : 4),
                shadowColor: shadowColor ?? primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: radius),
                splashFactory: InkRipple.splashFactory,
              ),
              child: _buildContent(onPrimary),
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
        letterSpacing: 0.5,
      ),
    );
  }
}
