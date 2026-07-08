import 'package:flutter/material.dart';

import 'motion/moe_reveal.dart';
import '../theme/moe_tokens.dart';

/// 入场动效（遗留别名）。
///
/// 新代码请使用 [MoeReveal]；本组件仅为存量页面保留兼容。
@Deprecated('Use MoeReveal from lib/widgets/motion/moe_reveal.dart')
class FadeInUp extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;

  const FadeInUp({
    super.key,
    required this.child,
    this.duration = MoeTokens.motionFadeDuration,
    this.delay = Duration.zero,
    this.offset = MoeTokens.motionFadeOffset,
  });

  @override
  Widget build(BuildContext context) {
    return MoeReveal(
      duration: duration,
      delay: delay,
      offsetY: offset,
      beginScale: 1,
      child: child,
    );
  }
}
