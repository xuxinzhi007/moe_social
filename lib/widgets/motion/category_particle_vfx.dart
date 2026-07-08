import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/gift.dart';

/// 分类粒子形体 — 礼物/成就动效中心，替代 emoji 贴图。
abstract final class CategoryParticleVfx {
  static List<Offset> shapePoints(GiftCategory category, int count) {
    return switch (category) {
      GiftCategory.emotion => _heartPoints(count),
      GiftCategory.food => _circlePoints(count, 0.82),
      GiftCategory.luxury => _diamondPoints(count),
      GiftCategory.special => _starPoints(count),
    };
  }

  static int dominantShape(GiftCategory category) {
    return switch (category) {
      GiftCategory.emotion => 2,
      GiftCategory.food => 0,
      GiftCategory.luxury => 3,
      GiftCategory.special => 1,
    };
  }

  static List<Offset> _circlePoints(int count, double radius) {
    return List.generate(count, (i) {
      final a = (i / count) * 2 * math.pi;
      final wobble = 0.88 + (i % 3) * 0.06;
      return Offset(
          math.cos(a) * radius * wobble, math.sin(a) * radius * wobble);
    });
  }

  static List<Offset> _heartPoints(int count) {
    return List.generate(count, (i) {
      final t = (i / count) * 2 * math.pi;
      final x = 16 * math.pow(math.sin(t), 3).toDouble();
      final y = -(13 * math.cos(t) -
          5 * math.cos(2 * t) -
          2 * math.cos(3 * t) -
          math.cos(4 * t));
      return Offset(x / 18, y / 18);
    });
  }

  static List<Offset> _diamondPoints(int count) {
    const corners = [
      Offset(0, -1),
      Offset(0.75, 0),
      Offset(0, 1),
      Offset(-0.75, 0),
    ];
    return List.generate(count, (i) {
      final seg = corners.length;
      final t = i / count * seg;
      final idx = t.floor() % seg;
      final next = (idx + 1) % seg;
      final local = t - t.floor();
      return Offset.lerp(corners[idx], corners[next], local)!;
    });
  }

  static List<Offset> _starPoints(int count) {
    return List.generate(count, (i) {
      final a = (i / count) * 2 * math.pi - math.pi / 2;
      final r = i.isEven ? 1.0 : 0.42;
      return Offset(math.cos(a) * r * 0.9, math.sin(a) * r * 0.9);
    });
  }
}

/// 中心粒子簇：散射 → 聚合成形体，可叠加脉冲与轻微扩散。
class CategoryParticleClusterPainter extends CustomPainter {
  final List<Offset> targets;
  final Color primaryColor;
  final Color secondaryColor;
  final double converge;
  final double pulse;
  final double expand;
  final int seed;
  final int dominantShape;

  const CategoryParticleClusterPainter({
    required this.targets,
    required this.primaryColor,
    required this.secondaryColor,
    required this.converge,
    this.pulse = 1,
    this.expand = 0,
    this.seed = 0,
    this.dominantShape = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.38;
    final rng = math.Random(seed);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.45 * pulse),
          primaryColor.withValues(alpha: 0.12 * pulse),
          Colors.transparent,
        ],
        stops: const [0, 0.45, 1],
      ).createShader(
          Rect.fromCircle(center: center, radius: baseRadius * 1.35));
    canvas.drawCircle(center, baseRadius * (1.1 + pulse * 0.08), glowPaint);

    final ringPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.25 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, baseRadius * (0.95 + expand * 0.15), ringPaint);

    for (var i = 0; i < targets.length; i++) {
      final scatterAngle = rng.nextDouble() * 2 * math.pi;
      final scatterDist = 1.1 + rng.nextDouble() * 0.55;
      final scatter = Offset(
        math.cos(scatterAngle) * scatterDist,
        math.sin(scatterAngle) * scatterDist,
      );
      final target = targets[i];
      final pos = Offset.lerp(scatter, target, converge.clamp(0.0, 1.0))!;
      final canvasPos = center + pos * baseRadius * (1 + expand * 0.25);

      final particleSize =
          (3.5 + (i % 4) * 1.2) * (0.85 + pulse * 0.15) * (1 - expand * 0.2);
      final color = i.isEven ? primaryColor : secondaryColor;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.55 + pulse * 0.35)
        ..style = PaintingStyle.fill;

      final shape = (i + dominantShape) % 4;
      switch (shape) {
        case 1:
          _drawStar(canvas, canvasPos, particleSize * 1.4, paint);
        case 2:
          _drawHeart(canvas, canvasPos, particleSize * 1.2, paint);
        case 3:
          _drawRay(canvas, center, canvasPos, color, pulse);
        default:
          canvas.drawCircle(canvasPos, particleSize, paint);
      }
    }
  }

  static void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    const points = 5;
    const innerRatio = 0.42;
    for (var i = 0; i < points * 2; i++) {
      final a = (i * math.pi / points) - math.pi / 2;
      final cr = i.isEven ? r : r * innerRatio;
      final pt = Offset(c.dx + math.cos(a) * cr, c.dy + math.sin(a) * cr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  static void _drawHeart(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    path.moveTo(c.dx, c.dy + r * 0.7);
    path.cubicTo(
      c.dx - r * 1.5,
      c.dy - r * 0.4,
      c.dx - r * 1.5,
      c.dy - r * 1.5,
      c.dx,
      c.dy - r * 0.6,
    );
    path.cubicTo(
      c.dx + r * 1.5,
      c.dy - r * 1.5,
      c.dx + r * 1.5,
      c.dy - r * 0.4,
      c.dx,
      c.dy + r * 0.7,
    );
    canvas.drawPath(path, paint);
  }

  static void _drawRay(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    double fade,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65 * fade)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(CategoryParticleClusterPainter old) {
    return converge != old.converge ||
        pulse != old.pulse ||
        expand != old.expand ||
        primaryColor != old.primaryColor;
  }
}
