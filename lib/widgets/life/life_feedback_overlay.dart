import 'package:flutter/material.dart';

/// 反馈动画数据项。
class FeedbackItem {
  final int key;
  final String emoji;
  final double entityX;
  final double entityY;

  const FeedbackItem({
    required this.key,
    required this.emoji,
    required this.entityX,
    required this.entityY,
  });
}

/// 操作反馈 emoji 上浮动画组件。
class LifeFeedbackOverlay extends StatefulWidget {
  final String emoji;
  final double pixelX;
  final double pixelY;

  const LifeFeedbackOverlay({
    super.key,
    required this.emoji,
    required this.pixelX,
    required this.pixelY,
  });

  @override
  State<LifeFeedbackOverlay> createState() => _LifeFeedbackOverlayState();
}

class _LifeFeedbackOverlayState extends State<LifeFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offsetAnim = Tween<double>(begin: 0.0, end: -40.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.pixelX - 12,
          top: widget.pixelY - 30 + _offsetAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value.clamp(0.0, 1.0),
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      },
    );
  }
}
