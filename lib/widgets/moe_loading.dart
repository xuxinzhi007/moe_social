import 'package:flutter/material.dart';

/// 萌社风格加载动画
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

class _MoeLoadingState extends State<MoeLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? const Color(0xFF7F7FD5);
    
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      themeColor.withOpacity(0.6),
                      themeColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.3),
                      blurRadius: widget.size / 2,
                      spreadRadius: _scaleAnimation.value * 2,
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

/// 替代默认 CircularProgressIndicator 的便捷小组件
class MoeSmallLoading extends StatelessWidget {
  final Color? color;
  final double size;
  
  const MoeSmallLoading({super.key, this.color, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? const Color(0xFF7F7FD5);
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
        backgroundColor: themeColor.withOpacity(0.1),
      ),
    );
  }
}