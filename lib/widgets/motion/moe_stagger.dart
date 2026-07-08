import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import 'moe_reveal.dart';
import 'moe_reveal_once.dart';

/// 列表交错入场：仅前 [maxAnimated] 项播放动效，其余直接渲染。
///
/// 传入 [itemKey] + [revealedKeys] 时，同一 key 刷新后不再重播动画。
class MoeStaggerReveal extends StatelessWidget {
  final Widget child;
  final int index;
  final int maxAnimated;
  final Duration staggerStep;
  final Duration duration;
  final double offsetY;
  final double beginScale;
  final String? itemKey;
  final Set<String>? revealedKeys;

  const MoeStaggerReveal({
    super.key,
    required this.child,
    required this.index,
    this.maxAnimated = 6,
    this.staggerStep = MoeTokens.motionStaggerStep,
    this.duration = MoeTokens.motionMedium,
    this.offsetY = MoeTokens.motionFadeOffset,
    this.beginScale = 0.985,
    this.itemKey,
    this.revealedKeys,
  });

  void _markSeen() {
    final key = itemKey;
    final keys = revealedKeys;
    if (key != null && keys != null) {
      keys.add(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (itemKey != null &&
        revealedKeys != null &&
        revealedKeys!.contains(itemKey!)) {
      return child;
    }

    if (index < 0 || index >= maxAnimated) {
      _markSeen();
      return child;
    }

    final delay = staggerStep * index;

    if (itemKey != null && revealedKeys != null) {
      return MoeRevealOnce(
        revealKey: itemKey!,
        revealedKeys: revealedKeys!,
        duration: duration,
        delay: delay,
        offsetY: offsetY,
        beginScale: beginScale,
        child: child,
      );
    }

    return MoeReveal(
      delay: delay,
      duration: duration,
      offsetY: offsetY,
      beginScale: beginScale,
      child: child,
    );
  }
}
