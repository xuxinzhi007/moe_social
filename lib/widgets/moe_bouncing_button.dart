import 'package:flutter/material.dart';

import 'motion/moe_pressable.dart';
import '../theme/moe_tokens.dart';

/// 弹性缩放按钮（遗留别名）。
///
/// 新代码请使用 [MoePressable]。
@Deprecated('Use MoePressable from lib/widgets/motion/moe_pressable.dart')
class MoeBouncingButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;
  final Duration duration;

  const MoeBouncingButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = MoeTokens.motionPressScale,
    this.duration = MoeTokens.motionFast,
  });

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: onTap,
      pressedScale: scaleFactor,
      duration: duration,
      child: child,
    );
  }
}
