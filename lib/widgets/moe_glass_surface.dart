import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_motion.dart';

/// 统一毛玻璃容器 — ClipRRect + BackdropFilter + 半透明底色 + 描边。
///
/// 仅用于固定位置元素（导航栏/底栏/浮层），不用于滚动列表项。
class MoeGlassSurface extends StatelessWidget {
  final Widget child;
  final double sigma;
  final Color? tint;
  final BorderRadius? borderRadius;
  final bool showBorder;

  const MoeGlassSurface({
    super.key,
    required this.child,
    this.sigma = MoeTokens.blurLight,
    this.tint,
    this.borderRadius,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = moeReduceMotion(context);
    final effectiveTint = tint ?? MoeTokens.surface1.withValues(alpha: 0.82);
    final radius = borderRadius ?? BorderRadius.zero;

    // reduceMotion 降级：不使用 BackdropFilter，直接半透明底色
    if (reduceMotion) {
      return Container(
        decoration: BoxDecoration(
          color: effectiveTint.withValues(alpha: 0.95),
          borderRadius: radius,
          border: showBorder
              ? Border.all(color: MoeTokens.surfaceBorder)
              : null,
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: effectiveTint,
            borderRadius: radius,
            border: showBorder
                ? Border.all(color: MoeTokens.surfaceBorder)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
