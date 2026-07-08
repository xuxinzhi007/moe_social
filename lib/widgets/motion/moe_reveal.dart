import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import 'moe_motion.dart';

class MoeReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final double beginScale;
  final Curve curve;

  const MoeReveal({
    super.key,
    required this.child,
    this.duration = MoeTokens.motionMedium,
    this.delay = Duration.zero,
    this.offsetY = MoeTokens.motionFadeOffset,
    this.beginScale = 0.985,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<MoeReveal> createState() => _MoeRevealState();
}

class _MoeRevealState extends State<MoeReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translateY;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void reassemble() {
    super.reassemble();
    _controller.dispose();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _translateY = Tween<double>(begin: widget.offsetY, end: 0).animate(curved);
    _scale = Tween<double>(begin: widget.beginScale, end: 1).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (moeReduceMotion(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _translateY.value),
            child: Transform.scale(
              scale: _scale.value,
              alignment: Alignment.topCenter,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
