import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'arena_view_model.dart';

class ArenaBattleGame extends FlameGame {
  ArenaBattleGame({required this.model});

  final ArenaViewModel model;
  double _time = 0;

  @override
  Color backgroundColor() => const Color(0xFFB7D7E9);

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final width = size.x;
    final height = size.y;
    final arenaTop = height * .16;
    final arenaBottom = height * .86;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, height),
          const [Color(0xFF9CC9E7), Color(0xFFFFEAC6)],
        ),
    );
    _paintCastle(canvas, width, arenaTop);
    _paintArena(canvas, width, arenaBottom);
    _paintBattlePads(canvas, width, arenaBottom);
    _paintCenterRune(canvas, Offset(width * .5, arenaBottom - 36));
  }

  void _paintCastle(Canvas canvas, double width, double top) {
    final paint = Paint()..color = const Color(0xAAFFF6E1);
    canvas.drawRect(Rect.fromLTWH(width * .28, top, width * .44, 4), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * .36, top - 54, width * .28, 64),
        const Radius.circular(70),
      ),
      paint,
    );
    for (var index = 0; index < 4; index++) {
      final x = width * (.3 + index * .14);
      canvas.drawRect(
        Rect.fromLTWH(x, top - 22, width * .055, 28),
        Paint()..color = const Color(0x88FFF8E9),
      );
    }
  }

  void _paintArena(Canvas canvas, double width, double bottom) {
    final center = Offset(width * .5, bottom + 52);
    final radius = width * .44;
    for (var index = 0; index < 4; index++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * (1.72 - index * .25),
          height: radius * (.42 - index * .05),
        ),
        Paint()
          ..color =
              index.isEven ? const Color(0x88FFF9E2) : const Color(0x55CDAE6E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
  }

  void _paintBattlePads(Canvas canvas, double width, double bottom) {
    final pads = [
      Offset(width * .16, bottom - 2),
      Offset(width * .26, bottom - 24),
      Offset(width * .36, bottom - 2),
      Offset(width * .64, bottom - 2),
      Offset(width * .74, bottom - 24),
      Offset(width * .84, bottom - 2),
    ];
    for (var index = 0; index < pads.length; index++) {
      final friendly = index < 3;
      final pulse = math.sin(_time * 2.8 + index) * 4;
      final paint = Paint()
        ..color = (friendly ? const Color(0xFF8DE0EC) : const Color(0xFF6B4A78))
            .withValues(alpha: friendly ? .30 : .24)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = (friendly ? const Color(0xFFFFE39B) : const Color(0xFF443451))
            .withValues(alpha: .62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final rect = Rect.fromCenter(
        center: pads[index].translate(0, pulse * .15),
        width: 88 + pulse,
        height: 26 + pulse * .25,
      );
      canvas.drawOval(rect, paint);
      canvas.drawOval(rect, stroke);
    }
  }

  void _paintCenterRune(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      33,
      Paint()
        ..color = const Color(0x66FFF7D5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(center, 5 + math.sin(_time * 3) * 1.5,
        Paint()..color = const Color(0xFFD6A950));
  }
}
