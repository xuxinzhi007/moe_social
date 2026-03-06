import 'package:flutter/material.dart';
import 'dart:math' as math;

// 带有炫酷粒子动画的点赞按钮
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback onTap;
  final double size; // 图标大小
  final Color? likedColor; // 点赞后的颜色
  final Color? unlikedColor; // 未点赞的颜色
  final bool showCount; // 是否显示数字

  const LikeButton({
    super.key,
    required this.isLiked,
    this.likeCount = 0,
    required this.onTap,
    this.size = 24.0,
    this.likedColor = Colors.pinkAccent,
    this.unlikedColor,
    this.showCount = true,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late AnimationController _particleController;
  
  bool _isLiked = false;
  
  // 粒子动画参数
  final int _particleCount = 6;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    
    // 缩放动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // 弹性缩放效果：放大 -> 缩小回弹
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.5).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    // 粒子动画控制器
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _initParticles();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_Particle(
        angle: (2 * math.pi / _particleCount) * i,
        distance: 0.0,
        size: 0.0,
        color: widget.likedColor ?? Colors.pinkAccent,
      ));
    }
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != _isLiked) {
      _isLiked = widget.isLiked;
      if (_isLiked) {
        _animateLike();
      }
    }
  }

  void _animateLike() {
    _controller.reset();
    _controller.forward();
    
    _particleController.reset();
    _particleController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlikedColor = widget.unlikedColor ?? theme.iconTheme.color?.withOpacity(0.6) ?? Colors.grey[600];
    final likedColor = widget.likedColor ?? Colors.pinkAccent;

    return GestureDetector(
      onTap: () {
        widget.onTap();
        if (!widget.isLiked) {
          // 如果原本是未点赞状态，点击后变成点赞，触发动画
          // 注意：实际状态更新由父组件控制，这里只是为了即时反馈
          _animateLike();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size + 10, // 预留粒子空间
              height: widget.size + 10,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 粒子层
                  AnimatedBuilder(
                    animation: _particleController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _ParticlePainter(
                          progress: _particleController.value,
                          particles: _particles,
                          color: likedColor,
                          centerSize: widget.size,
                        ),
                        size: Size(widget.size * 2, widget.size * 2),
                      );
                    },
                  ),
                  // 图标层
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Icon(
                      widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: widget.isLiked ? likedColor : unlikedColor,
                      size: widget.size,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showCount && widget.likeCount > 0) ...[
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.isLiked ? likedColor : unlikedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                ),
                child: Text('${widget.likeCount}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  double distance;
  double size;
  final Color color;

  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final Color color;
  final double centerSize;

  _ParticlePainter({
    required this.progress,
    required this.particles,
    required this.color,
    required this.centerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0 || progress == 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // 粒子扩散距离和大小随进度变化
    final maxDistance = centerSize * 0.8;
    
    for (var particle in particles) {
      // 距离：从中心向外扩散
      final currentDistance = centerSize * 0.5 + (maxDistance * progress);
      
      // 大小：先变大后变小
      double currentSize;
      if (progress < 0.5) {
        currentSize = 3.0 * (progress * 2); // 0 -> 3
      } else {
        currentSize = 3.0 * (1.0 - (progress - 0.5) * 2); // 3 -> 0
      }

      final dx = center.dx + currentDistance * math.cos(particle.angle);
      final dy = center.dy + currentDistance * math.sin(particle.angle);

      // 颜色透明度随进度降低
      paint.color = color.withOpacity(1.0 - progress);

      // 绘制圆形粒子
      canvas.drawCircle(Offset(dx, dy), currentSize, paint);
      
      // 绘制微小的随机辅助粒子（增加丰富度）
      if (progress > 0.2 && progress < 0.8) {
         paint.color = color.withOpacity((1.0 - progress) * 0.5);
         canvas.drawCircle(
           Offset(dx + 4, dy + 4), 
           currentSize * 0.5, 
           paint
         );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
