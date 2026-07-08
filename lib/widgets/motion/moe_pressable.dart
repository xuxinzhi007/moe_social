import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/moe_tokens.dart';
import 'moe_motion.dart';

class MoePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final HitTestBehavior behavior;
  final bool enableHaptics;
  final double pressedScale;
  final double pressedOpacity;
  final Duration duration;
  final Curve curve;

  const MoePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.behavior = HitTestBehavior.opaque,
    this.enableHaptics = true,
    this.pressedScale = MoeTokens.motionPressScale,
    this.pressedOpacity = 0.96,
    this.duration = MoeTokens.motionFast,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<MoePressable> createState() => _MoePressableState();
}

class _MoePressableState extends State<MoePressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
    );
    _scale = Tween<double>(
      begin: 1,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _opacity = Tween<double>(
      begin: 1,
      end: widget.pressedOpacity,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressIn() {
    if (!_enabled) return;
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    _controller.forward();
  }

  void _pressOut() {
    if (!_enabled) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      return widget.child;
    }

    if (moeReduceMotion(context)) {
      return GestureDetector(
        behavior: widget.behavior,
        onLongPress: widget.onLongPress,
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    final radius =
        widget.borderRadius ?? BorderRadius.circular(MoeTokens.radiusLg);

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _pressIn(),
      onTapUp: (_) => _pressOut(),
      onTapCancel: _pressOut,
      onLongPress: widget.onLongPress,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: ClipRRect(
                borderRadius: radius,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
