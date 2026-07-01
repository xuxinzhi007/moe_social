import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';

class FadeInUp extends StatefulWidget {
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
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateYAnimation;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  /// 热重载时 AnimationController 可能已 dispose，需重建避免 Transition addListener 断言。
  @override
  void reassemble() {
    super.reassemble();
    _controller.dispose();
    _setupController();
  }

  void _setupController() {
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _translateYAnimation = Tween<double>(begin: widget.offset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
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
    return FadeTransition(
      opacity: _opacityAnimation,
      child: AnimatedBuilder(
        animation: _translateYAnimation,
        child: widget.child,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _translateYAnimation.value),
            child: child,
          );
        },
      ),
    );
  }
}
