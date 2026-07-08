import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/gift.dart';
import 'category_particle_vfx.dart';

/// 粒子形状。
enum GiftParticleShape {
  circle,
  star,
  heart,
  diamond,
  ring,
}

/// 单颗粒子：内部用 0~1 比例坐标，绘制时按当前画布尺寸换算像素。
class GiftParticle {
  double nx;
  double ny;
  double vx;
  double vy;
  double life;
  final double maxLife;
  double sizeFactor;
  final Color color;
  final GiftParticleShape shape;
  double gravityY;
  double drag;
  double rotation;
  double rotationSpeed;
  double glow;

  GiftParticle({
    required this.nx,
    required this.ny,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.sizeFactor,
    required this.color,
    required this.shape,
    this.gravityY = 0,
    this.drag = 0.02,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.glow = 0,
  });

  bool get alive => life > 0;

  double get alpha =>
      (life / maxLife).clamp(0.0, 1.0) * color.a / 255.0;

  void tick(double dt) {
    if (!alive) return;
    life -= dt;
    vy += gravityY * dt;
    vx *= (1 - drag).clamp(0.0, 1.0);
    vy *= (1 - drag).clamp(0.0, 1.0);
    nx += vx * dt;
    ny += vy * dt;
    rotation += rotationSpeed * dt;
  }

  Offset toPixels(Size canvas) =>
      Offset(nx * canvas.width, ny * canvas.height);

  double pixelSize(Size canvas) =>
      sizeFactor * math.min(canvas.width, canvas.height);
}

/// 礼物粒子物理引擎（比例坐标，与屏幕尺寸解耦）。
class GiftParticleEngine {
  final List<GiftParticle> _particles = [];
  final math.Random _rng;

  GiftParticleEngine({int? seed}) : _rng = math.Random(seed);

  List<GiftParticle> get particles =>
      List.unmodifiable(_particles.where((p) => p.alive));

  void clear() => _particles.clear();

  void tick(double dtSeconds) {
    for (final p in _particles) {
      p.tick(dtSeconds);
    }
    _particles.removeWhere((p) => !p.alive);
  }

  void emitBurst({
    required Offset normOrigin,
    required int count,
    required Color color,
    double speedMin = 0.18,
    double speedMax = 0.55,
    double sizeMin = 0.006,
    double sizeMax = 0.018,
    GiftParticleShape? dominantShape,
    double gravityY = 0.35,
    double lifeMin = 0.5,
    double lifeMax = 1.2,
  }) {
    final shape = dominantShape ?? GiftParticleShape.circle;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + _rng.nextDouble() * 0.5;
      final speed = speedMin + _rng.nextDouble() * (speedMax - speedMin);
      _particles.add(GiftParticle(
        nx: normOrigin.dx + (_rng.nextDouble() - 0.5) * 0.01,
        ny: normOrigin.dy + (_rng.nextDouble() - 0.5) * 0.01,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        life: lifeMin + _rng.nextDouble() * (lifeMax - lifeMin),
        maxLife: lifeMax,
        sizeFactor: sizeMin + _rng.nextDouble() * (sizeMax - sizeMin),
        color: _varyColor(color),
        shape: _pickShape(shape, i),
        gravityY: gravityY,
        drag: 0.015 + _rng.nextDouble() * 0.02,
        rotation: _rng.nextDouble() * math.pi * 2,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 8,
        glow: _rng.nextDouble() * 0.4,
      ));
    }
  }

  void emitTrail({
    required Offset normFrom,
    required Offset normTo,
    required int count,
    required Color color,
    double sizeMin = 0.004,
    double sizeMax = 0.01,
  }) {
    for (int i = 0; i < count; i++) {
      final t = i / math.max(count - 1, 1);
      final lift = math.sin(t * math.pi) * 0.03;
      final pos = Offset.lerp(normFrom, normTo, t)! + Offset(0, -lift);
      _particles.add(GiftParticle(
        nx: pos.dx + (_rng.nextDouble() - 0.5) * 0.012,
        ny: pos.dy + (_rng.nextDouble() - 0.5) * 0.012,
        vx: (_rng.nextDouble() - 0.5) * 0.06,
        vy: -0.04 - _rng.nextDouble() * 0.08,
        life: 0.25 + _rng.nextDouble() * 0.35,
        maxLife: 0.6,
        sizeFactor: sizeMin + _rng.nextDouble() * (sizeMax - sizeMin),
        color: color.withValues(alpha: 0.85),
        shape: GiftParticleShape.circle,
        gravityY: 0.08,
        drag: 0.04,
        glow: 0.6,
      ));
    }
  }

  void emitShockwave({
    required Offset normCenter,
    required double normRadius,
    required Color color,
    int segments = 24,
    double life = 0.45,
  }) {
    for (int i = 0; i < segments; i++) {
      final angle = (i / segments) * 2 * math.pi;
      final outward = Offset(math.cos(angle), math.sin(angle));
      _particles.add(GiftParticle(
        nx: normCenter.dx + outward.dx * normRadius,
        ny: normCenter.dy + outward.dy * normRadius,
        vx: outward.dx * (0.12 + _rng.nextDouble() * 0.08),
        vy: outward.dy * (0.12 + _rng.nextDouble() * 0.08),
        life: life,
        maxLife: life,
        sizeFactor: 0.008 + _rng.nextDouble() * 0.006,
        color: color.withValues(alpha: 0.9),
        shape: GiftParticleShape.ring,
        gravityY: 0,
        drag: 0.06,
        glow: 0.8,
      ));
    }
  }

  void emitRain({
    required int count,
    required Color color,
    GiftCategory? category,
  }) {
    final shape = _categoryShape(category ?? GiftCategory.special);
    for (int i = 0; i < count; i++) {
      _particles.add(GiftParticle(
        nx: _rng.nextDouble(),
        ny: -0.05 - _rng.nextDouble() * 0.25,
        vx: (_rng.nextDouble() - 0.5) * 0.04,
        vy: 0.18 + _rng.nextDouble() * 0.15,
        life: 1.8 + _rng.nextDouble() * 1.2,
        maxLife: 3.0,
        sizeFactor: 0.008 + _rng.nextDouble() * 0.01,
        color: _varyColor(color),
        shape: _pickShape(shape, i),
        gravityY: 0.06,
        drag: 0.01,
        rotation: _rng.nextDouble() * math.pi,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 4,
      ));
    }
  }

  void emitAmbient({
    required Offset normCenter,
    required int count,
    required Color color,
    double normRadius = 0.1,
  }) {
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final dist = _rng.nextDouble() * normRadius;
      _particles.add(GiftParticle(
        nx: normCenter.dx + math.cos(angle) * dist,
        ny: normCenter.dy + math.sin(angle) * dist,
        vx: (_rng.nextDouble() - 0.5) * 0.04,
        vy: -0.03 - _rng.nextDouble() * 0.06,
        life: 0.4 + _rng.nextDouble() * 0.5,
        maxLife: 0.9,
        sizeFactor: 0.004 + _rng.nextDouble() * 0.008,
        color: color.withValues(alpha: 0.7),
        shape: GiftParticleShape.circle,
        gravityY: -0.02,
        drag: 0.03,
        glow: 0.5,
      ));
    }
  }

  GiftParticleShape _categoryShape(GiftCategory category) {
    return switch (CategoryParticleVfx.dominantShape(category)) {
      2 => GiftParticleShape.heart,
      1 => GiftParticleShape.star,
      3 => GiftParticleShape.diamond,
      _ => GiftParticleShape.circle,
    };
  }

  GiftParticleShape _pickShape(GiftParticleShape dominant, int index) {
    if (index % 4 == 0) return dominant;
    const pool = GiftParticleShape.values;
    return pool[_rng.nextInt(pool.length)];
  }

  Color _varyColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness(
          (hsl.lightness + (_rng.nextDouble() - 0.5) * 0.15).clamp(0.2, 0.9),
        )
        .withSaturation(
          (hsl.saturation + (_rng.nextDouble() - 0.3) * 0.1).clamp(0.3, 1.0),
        )
        .toColor()
        .withValues(alpha: 0.75 + _rng.nextDouble() * 0.25);
  }
}

class GiftParticlePainter extends CustomPainter {
  final List<GiftParticle> particles;

  const GiftParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    for (final p in particles) {
      if (!p.alive) continue;
      final center = p.toPixels(size);
      final r = p.pixelSize(size);
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.alpha)
        ..style = PaintingStyle.fill;
      if (p.glow > 0.2) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + p.glow * 3);
      }
      _drawShape(canvas, center, r, p, paint);
    }
  }

  void _drawShape(
    Canvas canvas,
    Offset center,
    double r,
    GiftParticle p,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(p.rotation);
    switch (p.shape) {
      case GiftParticleShape.circle:
        canvas.drawCircle(Offset.zero, r, paint);
      case GiftParticleShape.star:
        _drawStar(canvas, r * 1.4, paint);
      case GiftParticleShape.heart:
        _drawHeart(canvas, r * 1.2, paint);
      case GiftParticleShape.diamond:
        _drawDiamond(canvas, r * 1.5, paint);
      case GiftParticleShape.ring:
        final ring = Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = (r * 0.35).clamp(1.0, 3.0);
        canvas.drawCircle(Offset.zero, r, ring);
    }
    canvas.restore();
  }

  void _drawStar(Canvas canvas, double r, Paint paint) {
    final path = Path();
    const points = 5;
    const innerRatio = 0.42;
    for (int i = 0; i < points * 2; i++) {
      final a = (i * math.pi / points) - math.pi / 2;
      final cr = i.isEven ? r : r * innerRatio;
      final pt = Offset(math.cos(a) * cr, math.sin(a) * cr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, double r, Paint paint) {
    final path = Path();
    path.moveTo(0, r * 0.7);
    path.cubicTo(-r * 1.5, -r * 0.4, -r * 1.5, -r * 1.5, 0, -r * 0.6);
    path.cubicTo(r * 1.5, -r * 1.5, r * 1.5, -r * 0.4, 0, r * 0.7);
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, double r, Paint paint) {
    final path = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.7, 0)
      ..lineTo(0, r)
      ..lineTo(-r * 0.7, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(GiftParticlePainter old) => true;
}

class GiftParticleLayer extends StatefulWidget {
  final GiftParticleEngine engine;
  final bool running;

  const GiftParticleLayer({
    super.key,
    required this.engine,
    this.running = true,
  });

  @override
  State<GiftParticleLayer> createState() => _GiftParticleLayerState();
}

class _GiftParticleLayerState extends State<GiftParticleLayer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(GiftParticleLayer old) {
    super.didUpdateWidget(old);
    if (widget.running != old.running) {
      widget.running ? _startTicker() : _stopTicker();
    }
  }

  void _startTicker() {
    _ticker?.dispose();
    _lastTick = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.stop();
  }

  void _onTick(Duration elapsed) {
    if (!widget.running) return;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt > 0 && dt < 0.1) {
      widget.engine.tick(dt);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GiftParticlePainter(particles: widget.engine.particles),
      child: const SizedBox.expand(),
    );
  }
}
