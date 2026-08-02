import 'dart:math' as math;

import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.onChanged,
    required this.onEnd,
    this.enabled = true,
    this.size = 132,
  });

  final void Function(Offset value) onChanged;
  final VoidCallback onEnd;
  final bool enabled;
  final double size;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knob = Offset.zero;

  double get _radius => widget.size * 0.34;

  void _update(Offset localPosition) {
    if (!widget.enabled) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;
    final distance = delta.distance;
    final knob = distance > _radius
        ? Offset.fromDirection(delta.direction, _radius)
        : delta;
    setState(() => _knob = knob);
    widget.onChanged(Offset(knob.dx / _radius, knob.dy / _radius));
  }

  void _release() {
    if (!widget.enabled) return;
    setState(() => _knob = Offset.zero);
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _update(details.localPosition),
        onPanUpdate: (details) => _update(details.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: CustomPaint(
          painter: _VirtualJoystickPainter(
            knob: _knob,
            radius: _radius,
            enabled: widget.enabled,
          ),
        ),
      ),
    );
  }
}

class _VirtualJoystickPainter extends CustomPainter {
  const _VirtualJoystickPainter({
    required this.knob,
    required this.radius,
    required this.enabled,
  });

  final Offset knob;
  final double radius;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final opacity = enabled ? 1.0 : 0.35;
    final outer = Paint()
      ..color = const Color(0xFFFFF8F2).withValues(alpha: 0.74 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 15, outer);
    canvas.drawCircle(
      center,
      radius + 15,
      Paint()
        ..color = const Color(0xFFE97891).withValues(alpha: 0.25 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final guide = Paint()
      ..color = const Color(0xFF8E6E83).withValues(alpha: 0.18 * opacity)
      ..strokeWidth = 1.5;
    for (final angle in [0, math.pi / 2, math.pi, math.pi * 1.5]) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center - direction * (radius - 5),
          center + direction * (radius - 5), guide);
    }

    final knobCenter = center + knob;
    canvas.drawCircle(
      knobCenter,
      radius * 0.48,
      Paint()
        ..color = const Color(0xFFE97891).withValues(alpha: 0.84 * opacity),
    );
    canvas.drawCircle(
      knobCenter,
      radius * 0.48,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final arrow = TextPainter(
      text: TextSpan(
        text: '✦',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9 * opacity),
          fontSize: radius * 0.32,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    arrow.paint(canvas, knobCenter - Offset(arrow.width / 2, arrow.height / 2));
  }

  @override
  bool shouldRepaint(covariant _VirtualJoystickPainter oldDelegate) =>
      oldDelegate.knob != knob || oldDelegate.enabled != enabled;
}
