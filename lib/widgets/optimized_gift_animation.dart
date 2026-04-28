import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import '../models/gift.dart';
import '../utils/gift_effect_manager.dart';
import '../utils/particle_pool.dart';

class GiftAnimationData {
  final double scale;
  final double fade;
  final double rotation;
  final double slide;
  final double glow;
  final double entry;

  GiftAnimationData({
    required this.scale,
    required this.fade,
    required this.rotation,
    required this.slide,
    required this.glow,
    required this.entry,
  });
}

class OptimizedGiftAnimation extends StatefulWidget {
  final Gift gift;
  final VoidCallback? onAnimationComplete;
  final Duration? duration;
  final int comboCount;

  const OptimizedGiftAnimation({
    super.key,
    required this.gift,
    this.onAnimationComplete,
    this.duration,
    this.comboCount = 1,
  });

  @override
  State<OptimizedGiftAnimation> createState() => _OptimizedGiftAnimationState();
}

class _OptimizedGiftAnimationState extends State<OptimizedGiftAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _entryAnimation;
  late Animation<double> _comboScaleAnimation;

  final ParticleSystem _particleSystem = ParticleSystem();
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    final duration = widget.duration ?? widget.gift.animationDuration;

    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    _entryAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _getScaleCurve(),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: _getRotationEnd()).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _comboScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2 + widget.comboCount * 0.05),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2 + widget.comboCount * 0.05, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.3, curve: Curves.easeInOut),
      ),
    );

    _controller.addListener(_updateParticles);
    _controller.forward().then((_) {
      _particleSystem.clear();
      widget.onAnimationComplete?.call();
    });

    _initParticles();
  }

  Curve _getScaleCurve() {
    switch (widget.gift.level) {
      case GiftLevel.basic:
        return Curves.easeOut;
      case GiftLevel.medium:
      case GiftLevel.advanced:
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

  void _initParticles() {
    final count = widget.gift.particleCount;
    final center = Offset.zero;
    _particleSystem.emit(
      center: center,
      color: widget.gift.color,
      count: count,
      speed: widget.gift.level.index + 1,
      life: widget.gift.animationDuration.inMilliseconds / 1000,
      size: _getParticleSize(),
    );
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

  void _updateParticles() {
    _particleSystem.update(0.016);
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleSystem.clear();
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
        final data = GiftAnimationData(
          scale: _scaleAnimation.value * _comboScaleAnimation.value,
          fade: _fadeAnimation.value,
          rotation: _rotationAnimation.value,
          slide: _slideAnimation.value,
          glow: _glowAnimation.value,
          entry: _entryAnimation.value,
        );

        return Opacity(
          opacity: data.fade,
          child: Transform.translate(
            offset: Offset(0, data.slide * 50),
            child: Transform.scale(
              scale: data.scale,
              child: Transform.rotate(
                angle: data.rotation,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (level.index >= GiftLevel.advanced.index)
                      _buildGlowEffect(iconSize, glowRadius, data.glow),
                    if (widget.comboCount > 1)
                      _buildComboEffect(iconSize, widget.comboCount),
                    CustomPaint(
                      painter: _ParticleEffectPainter(
                        particleSystem: _particleSystem,
                        progress: _controller.value,
                        size: Size(iconSize * 2.5, iconSize * 2.5),
                      ),
                      size: Size(iconSize * 2.5, iconSize * 2.5),
                    ),
                    _buildGiftIcon(iconSize),
                    _buildGiftName(iconSize, data.entry),
                    if (level == GiftLevel.luxury)
                      _buildLuxuryEffect(iconSize, data.glow),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlowEffect(double iconSize, double glowRadius, double glowValue) {
    return Transform.scale(
      scale: 1 + glowValue * 0.3,
      child: Container(
        width: iconSize * 1.5,
        height: iconSize * 1.5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.gift.color.withOpacity(0.3 * glowValue),
              widget.gift.color.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComboEffect(double iconSize, int comboCount) {
    return Positioned(
      top: -iconSize * 0.3,
      child: Transform.scale(
        scale: _comboScaleAnimation.value,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: iconSize * 0.2,
            vertical: iconSize * 0.08,
          ),
          decoration: BoxDecoration(
            color: Colors.orange[500],
            borderRadius: BorderRadius.circular(iconSize * 0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '${comboCount}x 连击!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: iconSize * 0.18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiftIcon(double iconSize) {
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: widget.gift.color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.gift.color,
          width: 3 + widget.gift.level.index.toDouble(),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.gift.color.withOpacity(0.5),
            blurRadius: widget.gift.glowRadius,
            spreadRadius: widget.gift.glowRadius * 0.3,
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
                style: TextStyle(fontSize: iconSize * 0.6),
              ),
      ),
    );
  }

  Widget _buildGiftName(double iconSize, double entryValue) {
    return Positioned(
      bottom: -iconSize * 0.4,
      child: Transform.scale(
        scale: entryValue,
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
                color: widget.gift.color.withOpacity(0.3),
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
    );
  }

  Widget _buildLuxuryEffect(double iconSize, double glowValue) {
    return Transform.scale(
      scale: 1 + glowValue * 0.2,
      child: Container(
        width: iconSize * 2,
        height: iconSize * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.gift.color.withOpacity(0.3 * glowValue),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _ParticleEffectPainter extends CustomPainter {
  final ParticleSystem particleSystem;
  final double progress;
  final Size size;

  _ParticleEffectPainter({
    required this.particleSystem,
    required this.progress,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(this.size.width / 2, this.size.height / 2);
    particleSystem.paint(canvas, Offset.zero, progress);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ParticleEffectPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class GiftRainWidget extends StatefulWidget {
  final List<Gift> gifts;
  final Duration duration;

  const GiftRainWidget({
    super.key,
    required this.gifts,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<GiftRainWidget> createState() => _GiftRainWidgetState();
}

class _GiftRainWidgetState extends State<GiftRainWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_FallingGiftData> _fallingGifts = [];

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
    final maxGifts = math.min(widget.gifts.length * 3, 15);
    for (int i = 0; i < maxGifts; i++) {
      final gift = widget.gifts[random.nextInt(widget.gifts.length)];
      _fallingGifts.add(_FallingGiftData(
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
          painter: _GiftRainPainter(
            gifts: _fallingGifts,
            progress: _controller.value,
          ),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }
}

class _FallingGiftData {
  final Gift gift;
  final double startX;
  final double delay;
  final double speed;
  final double rotation;
  final double rotationSpeed;
  final double size;

  _FallingGiftData({
    required this.gift,
    required this.startX,
    required this.delay,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
  });
}

class _GiftRainPainter extends CustomPainter {
  final List<_FallingGiftData> gifts;
  final double progress;

  _GiftRainPainter({
    required this.gifts,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final fallingGift in gifts) {
      final adjustedProgress =
          ((progress - fallingGift.delay / 5.0) * 5.0).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final x = fallingGift.startX * size.width;
      final y = (adjustedProgress * fallingGift.speed) * size.height - 50;

      if (y > size.height) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(
          fallingGift.rotation + adjustedProgress * fallingGift.rotationSpeed);

      final giftSize = fallingGift.size;

      final backgroundPaint = Paint()
        ..color = fallingGift.gift.color.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset.zero, giftSize, backgroundPaint);

      final borderPaint = Paint()
        ..color = fallingGift.gift.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset.zero, giftSize, borderPaint);

      final emojiPainter = TextPainter(
        text: TextSpan(
          text: fallingGift.gift.emoji,
          style: TextStyle(fontSize: giftSize * 1.2),
        ),
        textDirection: TextDirection.ltr,
      );

      emojiPainter.layout();
      emojiPainter.paint(
        canvas,
        Offset(-emojiPainter.width / 2, -emojiPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GiftRainPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
