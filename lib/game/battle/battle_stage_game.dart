import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/battle_room.dart';

/// 第一版礼物 PK 战场：轻量确定性模拟，Flame 只负责舞台表现。
class BattleStageGame extends FlameGame {
  BattleStageGame({this.onChanged});

  final VoidCallback? onChanged;
  final List<_BattleUnit> _units = [];
  final List<_BattleBurst> _bursts = [];
  int leftBaseHp = 100;
  int rightBaseHp = 100;
  int likes = 0;
  double _pulse = 0;

  @override
  Color backgroundColor() => const Color(0xFF111426);

  void addLike({BattleSide side = BattleSide.left}) {
    likes++;
    final elite = likes % 8 == 0;
    spawn(side, elite: elite, label: elite ? '点赞精英' : '点赞小兵');
  }

  void spawn(BattleSide side, {bool elite = false, String label = '礼物单位'}) {
    _units.add(_BattleUnit(
      side: side,
      elite: elite,
      label: label,
      progress: side == BattleSide.left ? .16 : .84,
      hp: elite ? 4 : 2,
      speed: elite ? .035 : .052,
      color: side == BattleSide.left
          ? (elite ? const Color(0xFFFFB347) : const Color(0xFFFF6FAE))
          : (elite ? const Color(0xFF8DE6FF) : const Color(0xFF67A9FF)),
    ));
    _bursts.add(_BattleBurst(
        progress: side == BattleSide.left ? .16 : .84,
        color: side == BattleSide.left
            ? const Color(0xFFFF6FAE)
            : const Color(0xFF67A9FF)));
    onChanged?.call();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt;
    for (final burst in _bursts) {
      burst.life -= dt;
    }
    _bursts.removeWhere((burst) => burst.life <= 0);

    for (var i = 0; i < _units.length; i++) {
      final unit = _units[i];
      unit.cooldown -= dt;
      final enemy = _units.firstWhereOrNull((other) =>
          other.side != unit.side &&
          (other.progress - unit.progress).abs() < .075);
      if (enemy != null) {
        if (unit.cooldown <= 0) {
          enemy.hp--;
          unit.cooldown = unit.elite ? .42 : .66;
          _bursts.add(_BattleBurst(progress: unit.progress, color: unit.color));
        }
        continue;
      }
      unit.progress +=
          (unit.side == BattleSide.left ? 1 : -1) * unit.speed * dt;
      final hitBase = unit.side == BattleSide.left
          ? unit.progress >= .87
          : unit.progress <= .13;
      if (hitBase && unit.cooldown <= 0) {
        if (unit.side == BattleSide.left) {
          rightBaseHp = math.max(0, rightBaseHp - (unit.elite ? 8 : 3));
        } else {
          leftBaseHp = math.max(0, leftBaseHp - (unit.elite ? 8 : 3));
        }
        unit.cooldown = .72;
        _bursts.add(_BattleBurst(progress: unit.progress, color: unit.color));
      }
    }
    _units.removeWhere(
        (unit) => unit.hp <= 0 || unit.progress < .07 || unit.progress > .93);
    onChanged?.call();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;
    final laneY = h * .60;
    final laneLeft = w * .10;
    final laneRight = w * .90;
    final laneWidth = laneRight - laneLeft;

    canvas.drawRect(
        Offset.zero & Size(w, h),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(w, h),
              const [Color(0xFF2D2448), Color(0xFF111426)]));
    canvas.drawCircle(Offset(w * .5, laneY), w * .34,
        Paint()..color = const Color(0x147F7FD5));
    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: .16)
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(laneLeft, laneY), Offset(laneRight, laneY), lanePaint);
    for (var i = 0; i < 8; i++) {
      final x = laneLeft + laneWidth * (i / 7);
      canvas.drawCircle(Offset(x, laneY), 3,
          Paint()..color = Colors.white.withValues(alpha: .25));
    }
    _paintBase(canvas, Offset(laneLeft, laneY), const Color(0xFFFF5C9A),
        leftBaseHp, '左方基地');
    _paintBase(canvas, Offset(laneRight, laneY), const Color(0xFF5FA8FF),
        rightBaseHp, '右方基地');
    for (final unit in _units) {
      final position = Offset(laneLeft + laneWidth * unit.progress, laneY);
      _paintUnit(canvas, position, unit);
    }
    for (final burst in _bursts) {
      final x = laneLeft + laneWidth * burst.progress;
      final radius = 10 + (1 - burst.life / .38) * 24;
      canvas.drawCircle(
          Offset(x, laneY),
          radius,
          Paint()
            ..color = burst.color.withValues(alpha: burst.life / .38 * .45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    _paintLabel(canvas, Offset(16, 16), '点赞 $likes  ·  战场单位 ${_units.length}',
        Colors.white70, 12);
    _paintLabel(canvas, Offset(w * .5 - 50, 18), '实时战场', Colors.white, 15);
  }

  void _paintBase(
      Canvas canvas, Offset center, Color color, int hp, String label) {
    canvas.drawCircle(
        center, 30, Paint()..color = color.withValues(alpha: .18));
    canvas.drawCircle(center, 22, Paint()..color = color);
    canvas.drawCircle(center, 14, Paint()..color = const Color(0xFF15182B));
    final ratio = (hp / 100).clamp(0.0, 1.0);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - 34, center.dy + 38, 68 * ratio, 5),
            const Radius.circular(99)),
        Paint()..color = color);
    _paintLabel(canvas, Offset(center.dx - 30, center.dy + 48), '$label $hp',
        Colors.white70, 9);
  }

  void _paintUnit(Canvas canvas, Offset center, _BattleUnit unit) {
    final bob = math.sin(_pulse * 5 + unit.progress * 10) * 3;
    final c = center.translate(0, bob);
    canvas.drawCircle(c, unit.elite ? 17 : 12,
        Paint()..color = unit.color.withValues(alpha: .22));
    canvas.drawCircle(c, unit.elite ? 12 : 8, Paint()..color = unit.color);
    _paintLabel(canvas, Offset(c.dx - 15, c.dy - 28), unit.elite ? '★' : '•',
        Colors.white, unit.elite ? 14 : 12);
  }

  void _paintLabel(
      Canvas canvas, Offset offset, String text, Color color, double size) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                color: color, fontSize: size, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(canvas, offset);
  }
}

class _BattleUnit {
  _BattleUnit(
      {required this.side,
      required this.elite,
      required this.label,
      required this.progress,
      required this.hp,
      required this.speed,
      required this.color});
  final BattleSide side;
  final bool elite;
  final String label;
  final Color color;
  final double speed;
  double progress;
  int hp;
  double cooldown = .25;
}

class _BattleBurst {
  _BattleBurst({required this.progress, required this.color});
  final double progress;
  final Color color;
  double life = .38;
}

extension on Iterable<_BattleUnit> {
  _BattleUnit? firstWhereOrNull(bool Function(_BattleUnit value) test) {
    for (final value in this) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }
}
