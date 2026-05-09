import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/gift.dart';

/// 赛博艺术风格的礼物动画
class CyberGiftAnimation extends StatefulWidget {
  final Gift gift;
  final VoidCallback? onAnimationComplete;
  final Duration duration;

  const CyberGiftAnimation({
    super.key,
    required this.gift,
    this.onAnimationComplete,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<CyberGiftAnimation> createState() => _CyberGiftAnimationState();
}

class _CyberGiftAnimationState extends State<CyberGiftAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;

  final List<CyberParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    // 主动画控制器
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete?.call();
        }
      });

    // 粒子动画控制器
    _particleController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // 缩放动画
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    // 淡出动画
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    ));

    // 旋转动画
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.linear),
    ));

    // 滑动动画
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -1.5),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    // 光晕动画
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
      curve: Curves.easeInOut,
    ).animate(_controller);

    // 生成粒子
    _generateParticles();

    // 开始动画
    _controller.forward();
    _particleController.forward();
  }

  void _generateParticles() {
    for (int i = 0; i < 30; i++) {
      _particles.add(CyberParticle(
        position: Offset.zero,
        angle: (3.14159 * 2 / 30) * i,
        speed: 2.0 + (i % 5) * 0.5,
        size: 1.0 + (i % 3) * 0.5,
        color: widget.gift.color,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value * 100,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 粒子效果
                    CustomPaint(
                      painter: CyberParticlePainter(
                        particles: _particles,
                        progress: _particleController.value,
                      ),
                      size: const Size(200, 200),
                    ),

                    // 礼物图标
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            widget.gift.color.withAlpha(100),
                            widget.gift.color.withAlpha(0),
                          ],
                          center: Alignment.center,
                          radius: 0.8,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.gift.color.withAlpha(200),
                            blurRadius: 20 * _glowAnimation.value,
                            spreadRadius: 10 * _glowAnimation.value,
                          ),
                        ],
                      ),
                      child: Center(
                        child: widget.gift.svgPath != null
                            ? SvgPicture.asset(
                                widget.gift.svgPath!,
                                width: 64,
                                height: 64,
                                color: widget.gift.color,
                              )
                            : Text(
                                widget.gift.emoji,
                                style: const TextStyle(fontSize: 40),
                              ),
                      ),
                    ),

                    // 数字网格背景
                    _buildDigitalGrid(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDigitalGrid() {
    return Opacity(
      opacity: 0.3 * _glowAnimation.value,
      child: Container(
        width: 120,
        height: 120,
        child: Stack(
          children: [
            // 水平网格线
            for (int i = 0; i < 10; i++)
              Positioned(
                top: i * 12.0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: widget.gift.color.withAlpha(50),
                ),
              ),
            // 垂直网格线
            for (int i = 0; i < 10; i++)
              Positioned(
                left: i * 12.0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: widget.gift.color.withAlpha(50),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 赛博粒子类
class CyberParticle {
  Offset position;
  final double angle;
  final double speed;
  final double size;
  final Color color;
  double life;
  final double maxLife;

  CyberParticle({
    required this.position,
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  })  : life = 1.0,
        maxLife = 1.0;

  void update(double progress) {
    final distance = progress * speed * 50;
    position = Offset(
      distance * (angle.cos()),
      distance * (angle.sin()),
    );
    life = 1.0 - progress;
  }

  bool get isAlive => life > 0;

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
}

/// 赛博粒子绘制器
class CyberParticlePainter extends CustomPainter {
  final List<CyberParticle> particles;
  final double progress;

  CyberParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      if (particle.isAlive) {
        particle.update(progress);

        final paint = Paint()
          ..color = particle.color.withAlpha((particle.alpha * 200).toInt())
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.gaussian, 2.0);

        canvas.drawCircle(
          center + particle.position,
          particle.size * particle.alpha,
          paint,
        );

        // 粒子轨迹
        final trailPaint = Paint()
          ..color = particle.color.withAlpha((particle.alpha * 50).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = MaskFilter.blur(BlurStyle.gaussian, 1.0);

        final trailEnd = center + particle.position * 0.5;
        canvas.drawLine(center, trailEnd, trailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(CyberParticlePainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
