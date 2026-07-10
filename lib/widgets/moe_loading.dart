import 'package:flutter/material.dart';

import 'motion/moe_motion.dart';

/// 钀岀ぞ椋庢牸鍔犺浇鍔ㄧ敾
class MoeLoading extends StatefulWidget {
  final double size;
  final Color? color;

  const MoeLoading({
    super.key,
    this.size = 40.0,
    this.color,
  });

  @override
  State<MoeLoading> createState() => _MoeLoadingState();
}

class _MoeLoadingState extends State<MoeLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  void _syncAnimationState() {
    if (moeReduceMotion(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      if (_controller.value != 1.0) {
        _controller.value = 1.0;
      }
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? const Color(0xFF7F7FD5);
    final reduceMotion = moeReduceMotion(context);

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: reduceMotion ? 1.0 : _opacityAnimation.value,
            child: Transform.scale(
              scale: reduceMotion ? 1.0 : _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      themeColor.withValues(alpha: 0.6),
                      themeColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          themeColor.withValues(alpha: reduceMotion ? 0.22 : 0.3),
                      blurRadius: widget.size / 2,
                      spreadRadius: reduceMotion ? 1 : _scaleAnimation.value * 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: widget.size * 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 鏇夸唬榛樿 CircularProgressIndicator 鐨勪究鎹峰皬缁勪欢
class MoeSmallLoading extends StatelessWidget {
  final Color? color;
  final double size;

  const MoeSmallLoading({super.key, this.color, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? const Color(0xFF7F7FD5);
    if (moeReduceMotion(context)) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: themeColor.withValues(alpha: 0.12),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.35),
            ),
          ),
          child: Icon(
            Icons.favorite_rounded,
            size: size * 0.52,
            color: themeColor,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: size <= 20 ? 2.2 : 2.5,
        strokeCap: StrokeCap.round,
        color: themeColor,
        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
        backgroundColor: themeColor.withValues(alpha: 0.1),
      ),
    );
  }
}
