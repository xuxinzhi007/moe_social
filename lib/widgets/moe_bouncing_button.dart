import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 弹性缩放按钮 — 点击时缩小、松开时回弹，附带轻触觉反馈。
///
/// 动画时长与缩放比例可通过构造参数覆盖。
/// 推荐默认值参考 [MoeTokens.motionFadeDuration]。
class MoeBouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;
  final Duration duration;

  const MoeBouncingButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.9,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<MoeBouncingButton> createState() => _MoeBouncingButtonState();
}

class _MoeBouncingButtonState extends State<MoeBouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
