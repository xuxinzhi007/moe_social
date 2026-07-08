import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gift.dart';
import 'motion/category_particle_vfx.dart';
import 'motion/moe_vfx_profile.dart';

/// Deterministic particle data (pre-seeded, no setState required)
class _ParticleData {
  final double angle; // launch angle
  final double speed; // 0.5–1.5
  final double size; // base radius
  final Color color;
  final int shape; // 0=circle, 1=star, 2=heart, 3=ray

  const _ParticleData({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.shape,
  });
}

List<_ParticleData> _buildParticles(
  Gift gift,
  int seed,
  MoeVfxProfile profile, {
  double displayBoost = 1.0,
}) {
  final rng = math.Random(seed);
  final count = (profile.scaledBurstCount(gift.particleCount) * displayBoost)
      .round()
      .clamp(0, 80);
  if (count <= 0) return const [];
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
    final size = (level == GiftLevel.basic
            ? 3.0
            : level == GiftLevel.medium
                ? 4.5
                : level == GiftLevel.advanced
                    ? 5.5
                    : 7.0) *
        (0.7 + rng.nextDouble() * 0.6);
    final colorIdx = rng.nextInt(baseColors.length);
    final baseShape = CategoryParticleVfx.dominantShape(gift.category);
    final shape = level == GiftLevel.basic
        ? baseShape == 2
            ? 2
            : 0
        : level == GiftLevel.medium
            ? (baseShape + (i % 2)) % 3
            : level == GiftLevel.advanced
                ? (baseShape + (i % 3)) % 4
                : (baseShape + i) % 4;
    return _ParticleData(
      angle: angle,
      speed: speed,
      size: size,
      color: baseColors[colorIdx],
      shape: shape,
    );
  });
}

/// 全屏直播感倍率：低档礼物全屏展示时需放大，否则只有几颗粒子。
double _liveDisplayScale(GiftLevel level) {
  switch (level) {
    case GiftLevel.basic:
      return 1.7;
    case GiftLevel.medium:
      return 1.35;
    case GiftLevel.advanced:
      return 1.15;
    case GiftLevel.luxury:
      return 1.05;
  }
}

/// 直播式飞入轨迹：右下 → 略偏上中心，带弧线。
Offset _liveFlyOffset(Size screen, double t) {
  final flyT = Curves.easeOutCubic.transform((t / 0.18).clamp(0.0, 1.0));
  final start = Offset(screen.width * 0.44, screen.height * 0.42);
  final end = Offset(0, -screen.height * 0.08);
  // 二次弧线：中点抬高，模拟礼物抛出
  final midLift = Offset(0, -screen.height * 0.18 * math.sin(flyT * math.pi));
  final base = Offset.lerp(start, end, flyT)!;
  return t < 0.18 ? base + midLift * (1 - flyT) : end;
}

/// ───────────────────────────────────────────────────────────────────────────
/// OptimizedGiftAnimation
/// ───────────────────────────────────────────────────────────────────────────
class OptimizedGiftAnimation extends StatefulWidget {
  final Gift gift;
  final VoidCallback? onAnimationComplete;
  final Duration? duration;
  final int comboCount;
  final MoeVfxProfile? vfxProfile;

  const OptimizedGiftAnimation({
    super.key,
    required this.gift,
    this.onAnimationComplete,
    this.duration,
    this.comboCount = 1,
    this.vfxProfile,
  });

  @override
  State<OptimizedGiftAnimation> createState() => _OptimizedGiftAnimationState();
}

class _OptimizedGiftAnimationState extends State<OptimizedGiftAnimation>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  late Animation<double> _flyScale;
  late Animation<double> _floatY;
  late Animation<double> _glow;
  late Animation<double> _sway;
  late Animation<double> _nameFade;
  late Animation<double> _exit;
  late Animation<double> _exitScale;
  late Animation<double> _luxuryFlash;

  late MoeVfxProfile _profile;
  late List<_ParticleData> _particles;
  late List<Offset> _coreShapePoints;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _profile = widget.vfxProfile ?? MoeVfxProfile.fromContext(context);
    _setupAnimation();
    _ready = true;
  }

  void _setupAnimation() {
    final dur = _profile.scaledDuration(
      widget.duration ?? widget.gift.animationDuration,
    );
    final controller = AnimationController(duration: dur, vsync: this);
    _controller = controller;

    final displayBoost = _liveDisplayScale(widget.gift.level);
    _particles = _buildParticles(
      widget.gift,
      widget.gift.id.hashCode,
      _profile,
      displayBoost: displayBoost,
    );
    final coreCount = (_profile.scaledCoreCount(
      18 + widget.gift.level.index * 6,
    ) *
            displayBoost)
        .round()
        .clamp(0, 48);
    _coreShapePoints = coreCount > 0
        ? CategoryParticleVfx.shapePoints(widget.gift.category, coreCount)
        : const [];

    final flyIn = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.18, curve: Curves.easeOutCubic),
    );
    _flyScale = Tween<double>(begin: 0.15, end: 1.15).animate(flyIn);

    _floatY = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.18, 0.60, curve: Curves.easeInOut),
      ),
    );

    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.18, 0.85, curve: Curves.easeInOut),
      ),
    );

    _sway = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 15 * math.pi / 180),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 15 * math.pi / 180,
          end: -15 * math.pi / 180,
        ),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -15 * math.pi / 180, end: 0.0),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.18, 0.85, curve: Curves.easeInOut),
      ),
    );

    _nameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
      ),
    );

    _exit = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 0.78).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );

    _luxuryFlash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.12, curve: Curves.easeOut),
      ),
    );

    controller.forward().then((_) {
      widget.onAnimationComplete?.call();
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _controller == null) {
      return const SizedBox.shrink();
    }

    if (_profile.reduceMotion) {
      return _ReduceMotionGiftView(
        gift: widget.gift,
        comboCount: widget.comboCount,
        onComplete: widget.onAnimationComplete,
        layoutScale: _profile.layoutScale,
      );
    }

    final screenSize = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final displayBoost = _liveDisplayScale(widget.gift.level);
    final iconSize =
        widget.gift.iconSize * _profile.layoutScale * displayBoost;
    final controller = _controller!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;

        // Composite scale: fly-in scale + exit scale merge
        final compositeScale = (t < 0.18
                ? _flyScale.value
                : t < 0.85
                    ? 1.12
                    : _exitScale.value)
            .clamp(0.0, 2.5);

        final flyPos = _liveFlyOffset(screenSize, t);
        final floatBob = t >= 0.18 && t <= 0.60
            ? math.sin(_floatY.value * math.pi) * -14.0
            : 0.0;
        final totalOffset = Offset(
          flyPos.dx,
          flyPos.dy + floatBob,
        );

        final sway = _sway.value;
        final opacity = _exit.value;
        final glow = _glow.value;
        final nameFade = _nameFade.value;

        // Particle burst progress: active during 18-70%
        final particleProg = t < 0.18
            ? 0.0
            : t > 0.70
                ? ((t - 0.70) / 0.30).clamp(0.0, 1.0)
                : (t - 0.18) / 0.52;

        // 落点冲击波
        final shockProg = t < 0.16
            ? 0.0
            : t > 0.50
                ? ((0.50 - t) / 0.34).clamp(0.0, 1.0)
                : ((t - 0.16) / 0.34).clamp(0.0, 1.0);

        // 飞行拖尾
        final trailProg = t < 0.18 ? (t / 0.18) : 0.0;

        return Stack(
          children: [
            // ─── 直播感暗角（突出礼物主体）───
            IgnorePointer(
              child: Opacity(
                opacity: opacity * 0.55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.12),
                      radius: 1.1,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // ─── 飞行拖尾火花 ───
            if (trailProg > 0 && _particles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FlyTrailPainter(
                      color: widget.gift.color,
                      progress: trailProg,
                      start: Offset(
                        screenSize.width * 0.44,
                        screenSize.height * 0.42,
                      ),
                      end: Offset(
                        screenSize.width / 2,
                        screenSize.height / 2 - screenSize.height * 0.08,
                      ),
                      seed: widget.gift.id.hashCode,
                    ),
                  ),
                ),
              ),

            // ─── 落点冲击波环 ───
            if (shockProg > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ImpactShockwavePainter(
                      color: widget.gift.color,
                      progress: shockProg,
                      center: Offset(
                        screenSize.width / 2,
                        screenSize.height / 2 - screenSize.height * 0.08,
                      ),
                      maxRadius: iconSize * 2.8,
                    ),
                  ),
                ),
              ),
            // ─── Luxury full-screen flash ───
            if (widget.gift.level == GiftLevel.luxury &&
                _profile.enableLuxuryFlash)
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
                top: topInset + screenSize.height * 0.12,
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
                            color:
                                const Color(0xFFFF6B35).withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.comboCount}x 连击',
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
                    offset: totalOffset,
                    child: Transform.scale(
                      scale: compositeScale,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (_particles.isNotEmpty)
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

                          if (_coreShapePoints.isNotEmpty)
                            Transform.rotate(
                              angle: sway,
                              child: _GiftParticleCore(
                                gift: widget.gift,
                                iconSize: iconSize,
                                shapePoints: _coreShapePoints,
                                converge: t < 0.18 ? t / 0.18 : 1.0,
                                pulse: glow,
                                expand: particleProg,
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

class _ReduceMotionGiftView extends StatefulWidget {
  final Gift gift;
  final int comboCount;
  final VoidCallback? onComplete;
  final double layoutScale;

  const _ReduceMotionGiftView({
    required this.gift,
    required this.comboCount,
    this.onComplete,
    required this.layoutScale,
  });

  @override
  State<_ReduceMotionGiftView> createState() => _ReduceMotionGiftViewState();
}

class _ReduceMotionGiftViewState extends State<_ReduceMotionGiftView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.gift.iconSize * widget.layoutScale;
    final topInset = MediaQuery.paddingOf(context).top;

    return FadeTransition(
      opacity: _opacity,
      child: Stack(
        children: [
          if (widget.comboCount > 1)
            Positioned(
              top: topInset + 12,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${widget.comboCount}x 连击',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.gift.color.withValues(alpha: 0.22),
                    border: Border.all(color: widget.gift.color, width: 2),
                  ),
                ),
                SizedBox(height: iconSize * 0.35),
                _GiftNameLabel(gift: widget.gift),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

class _GiftParticleCore extends StatelessWidget {
  final Gift gift;
  final double iconSize;
  final List<Offset> shapePoints;
  final double converge;
  final double pulse;
  final double expand;

  const _GiftParticleCore({
    required this.gift,
    required this.iconSize,
    required this.shapePoints,
    required this.converge,
    required this.pulse,
    required this.expand,
  });

  @override
  Widget build(BuildContext context) {
    final size = iconSize * 1.25;
    return CustomPaint(
      painter: CategoryParticleClusterPainter(
        targets: shapePoints,
        primaryColor: gift.color,
        secondaryColor: gift.color.withValues(alpha: 0.65),
        converge: converge,
        pulse: pulse,
        expand: expand,
        seed: gift.id.hashCode,
        dominantShape: CategoryParticleVfx.dominantShape(gift.category),
      ),
      size: Size(size, size),
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
// Live-stream fly trail + impact shockwave
// ─────────────────────────────────────────────────────────────────────────────

class _FlyTrailPainter extends CustomPainter {
  final Color color;
  final double progress;
  final Offset start;
  final Offset end;
  final int seed;

  const _FlyTrailPainter({
    required this.color,
    required this.progress,
    required this.start,
    required this.end,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rng = math.Random(seed);
    final count = 10 + (progress * 8).round();
    for (int i = 0; i < count; i++) {
      final t = (i / count) * progress;
      final lift = math.sin(t * math.pi) * 28;
      final p = Offset.lerp(start, end, t)! + Offset(0, -lift);
      final r = 2.0 + rng.nextDouble() * 3.5;
      final alpha = (1 - t / progress.clamp(0.01, 1)) * 0.75;
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_FlyTrailPainter old) =>
      progress != old.progress || color != old.color;
}

class _ImpactShockwavePainter extends CustomPainter {
  final Color color;
  final double progress;
  final Offset center;
  final double maxRadius;

  const _ImpactShockwavePainter({
    required this.color,
    required this.progress,
    required this.center,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final radius = maxRadius * progress;
    final alpha = (1 - progress) * 0.55;
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (4 * (1 - progress)).clamp(1.0, 4.0);
    canvas.drawCircle(center, radius, paint);
    if (progress < 0.65) {
      canvas.drawCircle(
        center,
        radius * 0.55,
        paint..color = color.withValues(alpha: alpha * 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_ImpactShockwavePainter old) => progress != old.progress;
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
    final fade =
        progress > 0.7 ? (1.0 - (progress - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;

    for (final p in particles) {
      final dist = radius * p.speed * progress;
      final x = center.dx + math.cos(p.angle) * dist;
      final y = center.dy +
          math.sin(p.angle) * dist -
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
      center.dx - r * 1.5,
      center.dy - r * 0.4,
      center.dx - r * 1.5,
      center.dy - r * 1.5,
      center.dx,
      center.dy - r * 0.6,
    );
    path.cubicTo(
      center.dx + r * 1.5,
      center.dy - r * 1.5,
      center.dx + r * 1.5,
      center.dy - r * 0.4,
      center.dx,
      center.dy + r * 0.7,
    );
    canvas.drawPath(path, paint);
  }

  void _drawRay(
      Canvas canvas, Offset from, Offset to, Color color, double fade) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7 * fade)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(_LevelParticlePainter old) => progress != old.progress;
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
    _controller = AnimationController(duration: widget.duration, vsync: this);
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
      final adj = ((progress - fg.delay / 5.0) * 5.0).clamp(0.0, 1.0);
      if (adj <= 0) continue;

      final x = fg.startX * size.width;
      final y = (adj * fg.speed) * size.height - 50;
      if (y > size.height) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(fg.rotation + adj * fg.rotationSpeed);

      final clusterSize = fg.size * 2.4;
      canvas.translate(-clusterSize / 2, -clusterSize / 2);
      final miniTargets = CategoryParticleVfx.shapePoints(fg.gift.category, 10);
      final miniPainter = CategoryParticleClusterPainter(
        targets: miniTargets,
        primaryColor: fg.gift.color,
        secondaryColor: fg.gift.color.withValues(alpha: 0.7),
        converge: 1,
        pulse: 0.85,
        expand: 0,
        seed: fg.gift.id.hashCode,
        dominantShape: CategoryParticleVfx.dominantShape(fg.gift.category),
      );
      miniPainter.paint(canvas, Size(clusterSize, clusterSize));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GiftRainPainter old) => progress != old.progress;
}
