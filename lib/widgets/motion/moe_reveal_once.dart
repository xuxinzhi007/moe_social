import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import 'moe_motion.dart';
import 'moe_reveal.dart';

/// 对 [revealKey] 仅播放一次入场动效；列表刷新或 widget 重建时跳过。
///
/// 由父级持有 [revealedKeys]（通常放在 State 里），切换会话/Feed 模式时可
/// 换用新的 Set 或按域分桶。
class MoeRevealOnce extends StatefulWidget {
  final String revealKey;
  final Set<String> revealedKeys;
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final double beginScale;
  final Curve curve;

  const MoeRevealOnce({
    super.key,
    required this.revealKey,
    required this.revealedKeys,
    required this.child,
    this.duration = MoeTokens.motionMedium,
    this.delay = Duration.zero,
    this.offsetY = MoeTokens.motionFadeOffset,
    this.beginScale = 0.985,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<MoeRevealOnce> createState() => _MoeRevealOnceState();
}

class _MoeRevealOnceState extends State<MoeRevealOnce> {
  late final bool _animateThisInstance;

  @override
  void initState() {
    super.initState();
    _animateThisInstance = !widget.revealedKeys.contains(widget.revealKey);
    if (_animateThisInstance) {
      widget.revealedKeys.add(widget.revealKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_animateThisInstance || moeReduceMotion(context)) {
      return widget.child;
    }

    return MoeReveal(
      duration: widget.duration,
      delay: widget.delay,
      offsetY: widget.offsetY,
      beginScale: widget.beginScale,
      curve: widget.curve,
      child: widget.child,
    );
  }
}
