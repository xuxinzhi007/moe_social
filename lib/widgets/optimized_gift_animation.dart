import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gift.dart';

/// Deterministic particle data (pre-seeded, no setState required)
class _ParticleData {
  final double angle;    // launch angle
  final double speed;    // 0.5–1.5
  final double size;     // base radius
  final Color color;
  final int shape;       // 0=circle, 1=star, 2=heart, 3=ray

  const _ParticleData({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.shape,
  });
}

List<_ParticleData> _buildParticles(Gift gift, int seed) {
  final rng = math.Random(seed);
  final count = gift.particleCount;
  final level = gift.level;
  final baseColors = [
    gift.color,
    gift.color.withValues(alpha: 0.8),
    Colors.white.withValues(alpha: 0.9),
    const Color(0xFFFFD700),
    const Color(0xFFFF69B4),
  ];

  return List.generate(count, (i) {
    final angle = (i / count) * 2 * math.pi + rng.nextDouble() * 0.4;
    final speed = 0.6 + rng.nextDouble() * 0.9;
    final size = (level == GiftLevel.basic ? 3.0 : level == GiftLevel.medium ? 4.5 : level == GiftLevel.advanced ? 5.5 : 7.0) *
        (0.7 + rng.nextDouble() * 0.6);
    final colorIdx = rng.nextInt(baseColors.length);
    final shape = level == GiftLevel.basic
        ? 0
        : level == GiftLevel.medium
            ? (i % 2 == 0 ? 0 : 1)
            : level == GiftLevel.advanced
                ? (i % 3 == 0 ? 2 : i % 3 == 1 ? 1 : 0)
                : (i % 4);
    return _ParticleData(
      angle: angle,
      speed: speed,
      size: size,
      color: baseColors[colorIdx],
      shape: shape,
    );
  });
}

/// ───────────────────────────────────────────────────────────────────────────
/// OptimizedGiftAnimation
/// ───────────────────────────────────────────────────────────────────────────
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
  State<OptimizedGiftAnimation> createState() =>
      _OptimizedGiftAnimationState();
}

class _OptimizedGiftAnimationState extends State<OptimizedGiftAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Phase 0–15%: fly-in
  late Animation<double> _flyY;    // translateY: 220 → 0
  late Animation<double> _flyScale; // scale: 0 → 1.08

  // Phase 15–60%: breathe/float
  late Animation<double> _floatY;   // sinusoidal via CurvedAnimation trick
  late Animation<double> _glow;     // glow pulse

  // Phase 15–85%: sway (light rotation ±15°)
  late Animation<double> _sway;

  // Phase 60–85%: name label fade-in
  late Animation<double> _nameFade;

  // Phase 85–100%: fade-out
  late Animation<double> _exit;    // opacity 1→0
  late Animation<double> _exitScale; // scale 1→0.8

  // Luxury flash
  late Animation<double> _luxuryFlash; // 0→1→0 over 0–10%

  late List<_ParticleData> _particles;

  @override
  void initState() {
    super.initState();

    final dur = widget.duration ?? widget.gift.animationDuration;
    _controller = AnimationController(duration: dur, vsync: this);

    _particles = _buildParticles(widget.gift, widget.gift.id.hashCode);

    // ── fly-in phase 0–15 ──
    final flyIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.15, curve: Curves.easeOutCubic),
    );
    _flyY = Tween<double>(begin: 220.0, end: 0.0).animate(flyIn);
    _flyScale = Tween<double>(begin: 0.0, end: 1.08).animate(flyIn);

    // ── float/breathe 15–60: single up-down arch ──
    _floatY = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.60, curve: Curves.easeInOut),
      ),
    );

    // ── glow pulse 15–85 ──
    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.85, curve: Curves.easeInOut),
      ),
    );

    // ── sway 15–85: oscillate ±15° ──
    _sway = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 15 * math.pi / 180), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: 15 * math.pi / 180, end: -15 * math.pi / 180),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: -15 * math.pi / 180, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.85, curve: Curves.easeInOut),
      ),
    );

    // ── name label 60–85 ──
    _nameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
      ),
    );

    // ── exit 85–100 ──
    _exit = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 0.78).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );

    // ── luxury flash 0–12 ──
    _luxuryFlash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.12, curve: Curves.easeOut),
      ),
    );

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
    final screenSize = MediaQuery.of(context).size;
    final iconSize = widget.gift.iconSize;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // Composite scale: fly-in scale + exit scale merge
        final compositeScale = (t < 0.15
                ? _flyScale.value
                : t < 0.85
                    ? 1.08
                    : _exitScale.value)
            .clamp(0.0, 2.0);

        // Y offset: fly-in drives Y; then float gives subtle bob
        final flyOffset = _flyY.value;
        final floatBob = t >= 0.15 && t <= 0.60
            ? math.sin(_floatY.value * math.pi) * -12.0
            : 0.0;
        final totalY = flyOffset + floatBob;

        final sway = _sway.value;
        final opacity = _exit.value;
        final glow = _glow.value;
        final nameFade = _nameFade.value;

        // Particle burst progress: active during 15-70%
        final particleProg = t < 0.15
            ? 0.0
            : t > 0.70
                ? ((t - 0.70) / 0.30).clamp(0.0, 1.0)
                : (t - 0.15) / 0.55;

        return Stack(
          children: [
            // ─── Luxury full-screen flash ───
            if (widget.gift.level == GiftLevel.luxury)
              IgnorePointer(
                child: Opacity(
                  opacity: _luxuryFlash.value * 0.45,
                  child: Container(
                    width: screenSize.width,
                    height: screenSize.height,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          widget.gift.color.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ─── Combo label (fixed, not inside rotating transform) ───
            if (widget.comboCount > 1)
              Positioned(
                top: screenSize.height * 0.2,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: opacity,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFFAD00)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35)
                                .withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.comboCount}x 连击 🔥',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ─── Main gift animation ───
            Positioned.fill(
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, totalY),
                    child: Transform.scale(
                      scale: compositeScale,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Particles
                          CustomPaint(
                            painter: _LevelParticlePainter(
                              particles: _particles,
                              progress: particleProg,
                              iconSize: iconSize,
                            ),
                            size: Size(iconSize * 3, iconSize * 3),
                          ),

                          // Glow
                          if (widget.gift.level.index >=
                              GiftLevel.advanced.index)
                            _GlowRing(
                              color: widget.gift.color,
                              radius: iconSize * 0.75,
                              glow: glow,
                            ),

                          // Gift icon circle with sway
                          Transform.rotate(
                            angle: sway,
                            child: _GiftIconCircle(
                              gift: widget.gift,
                              iconSize: iconSize,
                            ),
                          ),

                          // Gift name label
                          Positioned(
                            bottom: -iconSize * 0.55,
                            child: Opacity(
                              opacity: nameFade,
                              child: Transform.translate(
                                offset: Offset(0, (1 - nameFade) * 8),
                                child: _GiftNameLabel(gift: widget.gift),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────────────

class _GlowRing extends StatelessWidget {
  final Color color;
  final double radius;
  final double glow;

  const _GlowRing({
    required this.color,
    required this.radius,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2 * (1 + glow * 0.12),
      height: radius * 2 * (1 + glow * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.35 * glow),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _GiftIconCircle extends StatelessWidget {
  final Gift gift;
  final double iconSize;

  const _GiftIconCircle({required this.gift, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gift.color.withValues(alpha: 0.18),
        border: Border.all(
          color: gift.color,
          width: 2.5 + gift.level.index.toDouble(),
        ),
        boxShadow: [
          BoxShadow(
            color: gift.color.withValues(alpha: 0.55),
            blurRadius: gift.glowRadius,
            spreadRadius: gift.glowRadius * 0.25,
          ),
        ],
      ),
      child: Center(
        child: Text(
          gift.emoji,
          style: TextStyle(fontSize: iconSize * 0.52),
        ),
      ),
    );
  }
}

class _GiftNameLabel extends StatelessWidget {
  final Gift gift;

  const _GiftNameLabel({required this.gift});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: gift.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gift.color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        gift.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level-aware particle painter
// ─────────────────────────────────────────────────────────────────────────────

class _LevelParticlePainter extends CustomPainter {
  final List<_ParticleData> particles;
  final double progress; // 0→1 across burst window
  final double iconSize;

  const _LevelParticlePainter({
    required this.particles,
    required this.progress,
    required this.iconSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = iconSize * 1.3;
    final fade = progress > 0.7 ? (1.0 - (progress - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;

    for (final p in particles) {
      final dist = radius * p.speed * progress;
      final x = center.dx + math.cos(p.angle) * dist;
      final y = center.dy + math.sin(p.angle) * dist -
          dist * dist * 0.004; // slight arc

      final alpha = (p.color.a / 255.0) * fade;
      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      final r = p.size * (1.0 - progress * 0.5).clamp(0.1, 1.5);

      switch (p.shape) {
        case 0: // circle
          canvas.drawCircle(Offset(x, y), r, paint);
        case 1: // star
          _drawStar(canvas, Offset(x, y), r * 1.5, paint);
        case 2: // heart
          _drawHeart(canvas, Offset(x, y), r * 1.2, paint);
        default: // ray (luxury firework)
          _drawRay(canvas, center, Offset(x, y), p.color, fade);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    const points = 5;
    const innerRatio = 0.4;
    for (int i = 0; i < points * 2; i++) {
      final a = (i * math.pi / points) - math.pi / 2;
      final cr = i.isEven ? r : r * innerRatio;
      final pt = Offset(
        center.dx + math.cos(a) * cr,
        center.dy + math.sin(a) * cr,
      );
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + r * 0.7);
    path.cubicTo(
      center.dx - r * 1.5, center.dy - r * 0.4,
      center.dx - r * 1.5, center.dy - r * 1.5,
      center.dx, center.dy - r * 0.6,
    );
    path.cubicTo(
      center.dx + r * 1.5, center.dy - r * 1.5,
      center.dx + r * 1.5, center.dy - r * 0.4,
      center.dx, center.dy + r * 0.7,
    );
    canvas.drawPath(path, paint);
  }

  void _drawRay(Canvas canvas, Offset from, Offset to, Color color,
      double fade) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7 * fade)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(_LevelParticlePainter old) =>
      progress != old.progress;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// GiftRainWidget (kept from original, minor cleanup)
/// ─────────────────────────────────────────────────────────────────────────────
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
    _controller =
        AnimationController(duration: widget.duration, vsync: this);
    _generateFallingGifts();
    _controller.forward();
  }

  void _generateFallingGifts() {
    final rng = math.Random();
    final maxGifts = math.min(widget.gifts.length * 3, 15);
    for (int i = 0; i < maxGifts; i++) {
      final gift = widget.gifts[rng.nextInt(widget.gifts.length)];
      _fallingGifts.add(_FallingGiftData(
        gift: gift,
        startX: rng.nextDouble(),
        delay: rng.nextDouble() * 2.0,
        speed: rng.nextDouble() * 0.5 + 0.5,
        rotation: rng.nextDouble() * 2 * math.pi,
        rotationSpeed: (rng.nextDouble() - 0.5) * 4,
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
      builder: (_, __) => CustomPaint(
        painter: _GiftRainPainter(
          gifts: _fallingGifts,
          progress: _controller.value,
        ),
        size: MediaQuery.of(context).size,
      ),
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

  const _FallingGiftData({
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

  const _GiftRainPainter({required this.gifts, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fg in gifts) {
      final adj =
          ((progress - fg.delay / 5.0) * 5.0).clamp(0.0, 1.0);
      if (adj <= 0) continue;

      final x = fg.startX * size.width;
      final y = (adj * fg.speed) * size.height - 50;
      if (y > size.height) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(fg.rotation + adj * fg.rotationSpeed);

      final bg = Paint()
        ..color = fg.gift.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, fg.size, bg);

      final border = Paint()
        ..color = fg.gift.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset.zero, fg.size, border);

      final tp = TextPainter(
        text: TextSpan(
          text: fg.gift.emoji,
          style: TextStyle(fontSize: fg.size * 1.2),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GiftRainPainter old) => progress != old.progress;
}
