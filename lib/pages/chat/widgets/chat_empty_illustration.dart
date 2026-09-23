import 'package:flutter/material.dart';

import '../../../theme/moe_tokens.dart';

// Hallmark · layout: layered chat bubbles · tone: warm, airy · scroll: none
// Self-critique: P5 H5 E4 S5 R5 V4
class ChatEmptyIllustration extends StatelessWidget {
  const ChatEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: CustomPaint(
        painter: _ChatEmptyIllustrationPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _ChatEmptyIllustrationPainter extends CustomPainter {
  const _ChatEmptyIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 80;
    final backBubble = Rect.fromLTWH(
      8 * unit,
      12 * unit,
      49 * unit,
      34 * unit,
    );
    final frontBubble = Rect.fromLTWH(
      26 * unit,
      35 * unit,
      47 * unit,
      34 * unit,
    );

    _drawBubble(
      canvas,
      backBubble,
      radius: MoeTokens.radiusMd * unit,
      tailOnRight: false,
      fill: Paint()..color = MoeTokens.accent.withValues(alpha: 0.24),
      outline: Paint()
        ..color = MoeTokens.secondary.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit,
      unit: unit,
    );
    _drawTypingDots(canvas, backBubble, unit);

    _drawBubble(
      canvas,
      frontBubble,
      radius: MoeTokens.radiusMd * unit,
      tailOnRight: true,
      fill: Paint()
        ..shader = MoeTokens.primaryGradient.createShader(frontBubble),
      outline: Paint()
        ..color = MoeTokens.primary.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit,
      unit: unit,
    );
    _drawMessageMark(canvas, frontBubble, unit);
    _drawSparkle(canvas, Offset(67 * unit, 16 * unit), 4.5 * unit);
    canvas.drawCircle(
      Offset(15 * unit, 62 * unit),
      2.5 * unit,
      Paint()..color = MoeTokens.mintSoft,
    );
  }

  void _drawBubble(
    Canvas canvas,
    Rect rect, {
    required double radius,
    required bool tailOnRight,
    required Paint fill,
    required Paint outline,
    required double unit,
  }) {
    final tail = Path();
    if (tailOnRight) {
      tail
        ..moveTo(rect.right - radius * 1.55, rect.bottom - unit)
        ..lineTo(rect.right - radius * 0.35, rect.bottom + 7 * unit)
        ..lineTo(rect.right - radius * 0.75, rect.bottom - unit)
        ..close();
    } else {
      tail
        ..moveTo(rect.left + radius * 1.55, rect.bottom - unit)
        ..lineTo(rect.left + radius * 0.35, rect.bottom + 7 * unit)
        ..lineTo(rect.left + radius * 0.75, rect.bottom - unit)
        ..close();
    }
    canvas.drawPath(tail, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      outline,
    );
  }

  void _drawTypingDots(Canvas canvas, Rect bubble, double unit) {
    final paint = Paint()..color = MoeTokens.primary.withValues(alpha: 0.72);
    final centerY = bubble.center.dy;
    for (var index = 0; index < 3; index++) {
      canvas.drawCircle(
        Offset(bubble.left + (17 + index * 8) * unit, centerY),
        2 * unit,
        paint,
      );
    }
  }

  void _drawMessageMark(Canvas canvas, Rect bubble, double unit) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.94)
      ..strokeCap = StrokeCap.round;
    final centerY = bubble.center.dy;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bubble.left + 13 * unit,
          centerY - 4 * unit,
          10 * unit,
          3 * unit,
        ),
        Radius.circular(MoeTokens.radiusSm * unit),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bubble.left + 13 * unit,
          centerY + 3 * unit,
          13 * unit,
          3 * unit,
        ),
        Radius.circular(MoeTokens.radiusSm * unit),
      ),
      paint,
    );
    _drawHeart(
      canvas,
      Offset(bubble.right - 12 * unit, centerY),
      5.5 * unit,
      paint,
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double radius, Paint paint) {
    final heart = Path()
      ..moveTo(center.dx, center.dy + radius * 0.85)
      ..cubicTo(
        center.dx - radius * 1.55,
        center.dy - radius * 0.15,
        center.dx - radius * 0.9,
        center.dy - radius * 1.35,
        center.dx,
        center.dy - radius * 0.45,
      )
      ..cubicTo(
        center.dx + radius * 0.9,
        center.dy - radius * 1.35,
        center.dx + radius * 1.55,
        center.dy - radius * 0.15,
        center.dx,
        center.dy + radius * 0.85,
      )
      ..close();
    canvas.drawPath(heart, paint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius) {
    final sparkle = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * 0.12,
        center.dy - radius * 0.12,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.12,
        center.dy + radius * 0.12,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.12,
        center.dy + radius * 0.12,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.12,
        center.dy - radius * 0.12,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(sparkle, Paint()..color = MoeTokens.pastelPink);
  }

  @override
  bool shouldRepaint(covariant _ChatEmptyIllustrationPainter oldDelegate) =>
      false;
}
