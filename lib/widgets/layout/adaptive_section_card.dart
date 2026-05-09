import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

/// 页面内卡片区块容器：
/// - 自动根据紧凑模式收缩边距与圆角
/// - 统一白底 + 软阴影样式，避免新页面样式与间距不一致
class AdaptiveSectionCard extends StatelessWidget {
  const AdaptiveSectionCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.useCompactDensity(context);

    return Container(
      margin: margin ?? EdgeInsets.only(bottom: compact ? 10 : 12),
      padding: padding ?? EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? (compact ? 16 : 20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.08),
            blurRadius: compact ? 10 : 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
