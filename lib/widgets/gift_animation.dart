import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import '../models/gift.dart';
import '../utils/svg_gift_manager.dart';
import '../utils/gift_effect_manager.dart';

/// 礼物发送成功的动画效果
class GiftSendAnimation extends StatefulWidget {
  final Gift gift;
  final VoidCallback? onAnimationComplete;
  final Duration? duration;

  const GiftSendAnimation({
    super.key,
    required this.gift,
    this.onAnimationComplete,
    this.duration,
  });

  @override
  State<GiftSendAnimation> createState() => _GiftSendAnimationState();
}

class _GiftSendAnimationState extends State<GiftSendAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _particleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _entryAnimation;

  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    final duration = widget.duration ?? widget.gift.animationDuration;

    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    // 粒子动画控制器
    _particleController = AnimationController(
      duration: Duration(milliseconds: (duration.inMilliseconds * 0.8).round()),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: Duration(milliseconds: (duration.inMilliseconds * 0.5).round()),
      vsync: this,
    );

    _entryAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: _getScaleCurve(),
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
      end: _getRotationEnd(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));

    // 滑动动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // 生成粒子
    _generateParticles();

    // 开始动画
    _controller.forward().then((_) {
      widget.onAnimationComplete?.call();
    });

    _particleController.forward();
    _glowController.repeat(reverse: true);
  }

  Curve _getScaleCurve() {
    switch (widget.gift.level) {
      case GiftLevel.basic:
        return Curves.easeOut;
      case GiftLevel.medium:
        return Curves.elasticOut;
      case GiftLevel.advanced:
        return Curves.elasticOut;
      case GiftLevel.luxury:
        return Curves.elasticOut;
    }
  }

  double _getRotationEnd() {
    switch (widget.gift.level) {
      case GiftLevel.basic:
        return math.pi * 0.5;
      case GiftLevel.medium:
        return math.pi;
      case GiftLevel.advanced:
        return math.pi * 1.5;
      case GiftLevel.luxury:
        return math.pi * 2;
    }
  }

  void _generateParticles() {
    final count = widget.gift.particleCount;
    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        position: Offset(
          _random.nextDouble() * 200 - 100,
          _random.nextDouble() * 200 - 100,
        ),
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 4,
          -(_random.nextDouble() * 3 + 1),
        ),
        life: _random.nextDouble() * 0.5 + 0.5,
        color: widget.gift.color,
        size: _getParticleSize(),
      ));
    }
  }

  double _getParticleSize() {
    switch (widget.gift.level) {
      case GiftLevel.basic:
        return 3.0;
      case GiftLevel.medium:
        return 4.0;
      case GiftLevel.advanced:
        return 5.0;
      case GiftLevel.luxury:
        return 6.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.gift.iconSize;
    final glowRadius = widget.gift.glowRadius;
    final level = widget.gift.level;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _slideAnimation.value.dy) * 50),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (level.index >= GiftLevel.advanced.index)
                      _buildGlowEffect(iconSize, glowRadius),

                    CustomPaint(
                      painter: ParticlePainter(
                        particles: _particles,
                        progress: _particleController.value,
                        particleSize: _getParticleSize(),
                      ),
                      size: Size(iconSize * 2.5, iconSize * 2.5),
                    ),

                    // 礼物图标
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: widget.gift.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.gift.color,
                          width: 3 + level.index.toDouble(),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.gift.color.withValues(alpha: 0.5),
                            blurRadius: glowRadius,
                            spreadRadius: glowRadius * 0.3,
                          ),
                        ],
                      ),
                      child: Center(
                        child: widget.gift.svgPath != null
                            ? GiftEffectManager.getGiftEffect(
                                widget.gift,
                                animation: _controller,
                              )
                            : Text(
                                widget.gift.emoji,
                                style: const TextStyle(fontSize: 40),
                              ),
                      ),
                    ),

                    // 礼物名称
                    Positioned(
                      bottom: -iconSize * 0.4,
                      child: Transform.scale(
                        scale: _entryAnimation.value,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: iconSize * 0.2,
                            vertical: iconSize * 0.1,
                          ),
                          decoration: BoxDecoration(
                            color: widget.gift.color,
                            borderRadius: BorderRadius.circular(iconSize * 0.25),
                            boxShadow: [
                              BoxShadow(
                                color: widget.gift.color.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.gift.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: iconSize * 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (level == GiftLevel.luxury)
                      _buildLuxuryEffect(iconSize),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlowEffect(double iconSize, double glowRadius) {
    return Transform.scale(
      scale: 1 + _glowAnimation.value * 0.3,
      child: Container(
        width: iconSize * 1.5,
        height: iconSize * 1.5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.gift.color.withValues(alpha: 0.3 * _glowAnimation.value),
              widget.gift.color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryEffect(double iconSize) {
    return Transform.scale(
      scale: 1 + _glowAnimation.value * 0.2,
      child: Container(
        width: iconSize * 2,
        height: iconSize * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.gift.color.withValues(alpha: 0.3 * _glowAnimation.value),
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// 粒子类
class Particle {
  Offset position;
  Offset velocity;
  double life;
  double maxLife;
  Color color;
  double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.color,
    this.size = 4.0,
  }) : maxLife = life;

  void update(double deltaTime) {
    position += velocity * deltaTime * 60;
    velocity += const Offset(0, 0.5); // 重力效果
    life -= deltaTime;
  }

  bool get isAlive => life > 0;

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
}

/// 粒子绘制器
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final double particleSize;

  ParticlePainter({
    required this.particles,
    required this.progress,
    this.particleSize = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      if (particle.isAlive) {
        particle.update(0.016);

        final paint = Paint()
          ..color = particle.color.withValues(alpha: particle.alpha * 0.8)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          center + particle.position * progress,
          particle.size * particle.alpha,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

/// 礼物飘屏动画
class GiftRainAnimation extends StatefulWidget {
  final List<Gift> gifts;
  final Duration duration;

  const GiftRainAnimation({
    super.key,
    required this.gifts,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<GiftRainAnimation> createState() => _GiftRainAnimationState();
}

class _GiftRainAnimationState extends State<GiftRainAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<FallingGift> _fallingGifts = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _generateFallingGifts();
    _controller.forward();
  }

  void _generateFallingGifts() {
    final random = math.Random();
    final maxGifts = math.min(widget.gifts.length, 10);
    for (int i = 0; i < maxGifts; i++) {
      final gift = widget.gifts[random.nextInt(widget.gifts.length)];
      _fallingGifts.add(FallingGift(
        gift: gift,
        startX: random.nextDouble(),
        delay: random.nextDouble() * 2.0,
        speed: random.nextDouble() * 0.5 + 0.5,
        rotation: random.nextDouble() * 2 * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 4,
        size: gift.iconSize * 0.2,
      ));
    }
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
        return CustomPaint(
          painter: GiftRainPainter(
            gifts: _fallingGifts,
            progress: _controller.value,
          ),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }
}

/// 下落的礼物
class FallingGift {
  final Gift gift;
  final double startX;
  final double delay;
  final double speed;
  final double rotation;
  final double rotationSpeed;
  final double size;

  FallingGift({
    required this.gift,
    required this.startX,
    required this.delay,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    this.size = 20,
  });
}

/// 礼物雨绘制器
class GiftRainPainter extends CustomPainter {
  final List<FallingGift> gifts;
  final double progress;

  GiftRainPainter({
    required this.gifts,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final fallingGift in gifts) {
      final adjustedProgress = ((progress - fallingGift.delay / 5.0) * 5.0).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final x = fallingGift.startX * size.width;
      final y = (adjustedProgress * fallingGift.speed) * size.height - 50;

      if (y > size.height) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(fallingGift.rotation + adjustedProgress * fallingGift.rotationSpeed);

      final giftSize = fallingGift.size;

      final backgroundPaint = Paint()
        ..color = fallingGift.gift.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset.zero, giftSize, backgroundPaint);

      // 绘制礼物边框
      final borderPaint = Paint()
        ..color = fallingGift.gift.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset.zero, giftSize, borderPaint);

      // 绘制礼物图标（优先使用SVG）
      if (fallingGift.gift.svgPath != null) {
        // 注意：在CustomPaint中绘制SVG需要特殊处理
        // 这里暂时使用emoji作为替代，实际项目中可以使用flutter_svg的PictureRecorder
        final textPainter = TextPainter(
          text: TextSpan(
            text: fallingGift.gift.emoji,
            style: const TextStyle(fontSize: 24),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
      } else {
        final textPainter = TextPainter(
          text: TextSpan(
            text: fallingGift.gift.emoji,
            style: const TextStyle(fontSize: 24),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(GiftRainPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

/// 徽章解锁动画
class BadgeUnlockAnimation extends StatefulWidget {
  final String badgeName;
  final String badgeEmoji;
  /// 若提供则优先显示矢量图标，否则显示 [badgeEmoji]
  final IconData? badgeIcon;
  final Color badgeColor;
  final VoidCallback? onAnimationComplete;

  const BadgeUnlockAnimation({
    super.key,
    required this.badgeName,
    required this.badgeEmoji,
    this.badgeIcon,
    required this.badgeColor,
    this.onAnimationComplete,
  });

  @override
  State<BadgeUnlockAnimation> createState() => _BadgeUnlockAnimationState();
}

class _BadgeUnlockAnimationState extends State<BadgeUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
    ));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward().then((_) {
      widget.onAnimationComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 徽章图标
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: widget.badgeColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.badgeColor,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.badgeColor.withValues(alpha: _glowAnimation.value * 0.6),
                        blurRadius: 30 * _glowAnimation.value,
                        spreadRadius: 10 * _glowAnimation.value,
                      ),
                    ],
                  ),
                  child: Center(
                    child: widget.badgeIcon != null
                        ? Icon(
                            widget.badgeIcon,
                            size: 64,
                            color: widget.badgeColor,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          )
                        : Text(
                            widget.badgeEmoji,
                            style: const TextStyle(fontSize: 60),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 解锁文本
              Opacity(
                opacity: _textAnimation.value,
                child: Column(
                  children: [
                    const Text(
                      '🎉 徽章解锁 🎉',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.badgeName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
