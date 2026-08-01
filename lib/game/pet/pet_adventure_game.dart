import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'pet_art.dart';
import 'pet_avatar_stack.dart';
import 'pet_lpc_sheet.dart';
import 'pet_sheet_avatar.dart';
import '../../models/pet_wear.dart';

/// 轻冒险舞台：视觉与小家统一（暖色 + LPC/Paper 角色，禁止深夜蓝调试风）。
class PetAdventureGame extends FlameGame {
  PetAdventureGame({
    required this.playerPower,
    this.stageLabel = '小院试炼',
    this.hatId = '',
    this.topId = 'top_basic',
    this.bottomId = 'bottom_basic',
    this.shoesId = 'shoes_basic',
  });

  static const ink = Color(0xFF5A4638);
  static const rose = Color(0xFFE97891);
  static const cream = Color(0xFFFFF6EE);
  static const winGreen = Color(0xFF6B9B76);
  static const loseRose = Color(0xFFC45B76);

  final int playerPower;
  final String stageLabel;
  final String hatId;
  final String topId;
  final String bottomId;
  final String shoesId;

  bool? _win;
  double _t = 0;
  String _status = '遭遇野怪…';
  bool _finished = false;

  void Function(bool win)? onFinished;

  bool get finished => _finished;
  bool? get won => _win;

  @override
  Color backgroundColor() => cream;

  @override
  Future<void> onLoad() async {
    _status = '出发：$stageLabel';
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(360, 640);
    await world.add(
      _AdventureStage(
        playerPower: playerPower,
        hatId: hatId,
        topId: topId,
        bottomId: bottomId,
        shoesId: shoesId,
      ),
    );
  }

  void resolve(bool win) {
    _win = win;
    _status = win ? '胜利！获得掉落' : '惜败，休息后再来';
    _finished = true;
    onFinished?.call(win);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!_finished && _t > 1.6) {
      resolve(playerPower >= 28);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final view = camera.viewport.size;
    final tp = TextPainter(
      text: TextSpan(
        text: _status,
        style: TextStyle(
          color: (_win == true)
              ? winGreen
              : (_win == false)
                  ? loseRose
                  : ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padH = 16.0;
    const padV = 10.0;
    final bw = tp.width + padH * 2;
    final bh = tp.height + padV * 2;
    final left = (view.x - bw) / 2;
    final top = view.y * 0.11;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, bw, bh),
      const Radius.circular(18),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xF2FFF8F2));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = rose.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    tp.paint(canvas, Offset(left + padH, top + padV));
  }
}

class _AdventureStage extends PositionComponent
    with HasGameReference<PetAdventureGame> {
  _AdventureStage({
    required this.playerPower,
    required this.hatId,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
  });

  final int playerPower;
  final String hatId;
  final String topId;
  final String bottomId;
  final String shoesId;

  double _pulse = 0;
  PetLpcSheet? _sheet;
  PetAvatarStack? _stack;
  ui.Image? _monster;

  @override
  Future<void> onLoad() async {
    size = Vector2(720, 1280);
    if (PetSheetAvatar.isActive) {
      _sheet = await PetSheetAvatar.composeOutfit(
        hatId: hatId,
        topId: topId,
        bottomId: bottomId,
        shoesId: shoesId,
      );
    }
    if (_sheet == null) {
      _stack = await PetAvatarStack.compose(
        hatId: hatId,
        topId: topId,
        bottomId: bottomId,
        shoesId: shoesId,
      );
    }
    _monster = await PetArt.loadImage(PetArt.monsterHead);
  }

  @override
  void update(double dt) {
    _pulse += dt * 3.2;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.58),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h * 0.58),
          const [Color(0xFFFFF6EE), Color(0xFFFFE8D6)],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.55, w, h * 0.45),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.55),
          Offset(0, h),
          const [Color(0xFFC5E1A5), Color(0xFFE8D5C4)],
        ),
    );
    canvas.drawOval(
      Rect.fromLTWH(w * 0.52, h * 0.40, w * 0.55, h * 0.18),
      Paint()..color = const Color(0x33A5D6A7),
    );

    final bob = math.sin(_pulse) * 6;
    final playerRect = Rect.fromCenter(
      center: Offset(w * 0.30, h * 0.52 + bob),
      width: 168,
      height: 220,
    );
    final foeRect = Rect.fromCenter(
      center: Offset(w * 0.70, h * 0.52 - bob * 0.5),
      width: 140,
      height: 140,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(playerRect.center.dx, playerRect.bottom - 4),
        width: 72,
        height: 16,
      ),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(foeRect.center.dx, foeRect.bottom + 2),
        width: 66,
        height: 14,
      ),
      Paint()..color = const Color(0x22000000),
    );

    _paintPlayer(canvas, playerRect);
    _paintFoe(canvas, foeRect);

    final vs = TextPainter(
      text: const TextSpan(
        text: 'VS',
        style: TextStyle(
          color: PetAdventureGame.rose,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    vs.paint(canvas, Offset((w - vs.width) / 2, h * 0.455));

    final power = TextPainter(
      text: TextSpan(
        text: '战力 $playerPower',
        style: const TextStyle(
          color: PetAdventureGame.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    power.paint(
      canvas,
      Offset(playerRect.center.dx - power.width / 2, playerRect.bottom + 8),
    );

    final foeLabel = TextPainter(
      text: const TextSpan(
        text: '野怪',
        style: TextStyle(
          color: PetAdventureGame.ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    foeLabel.paint(
      canvas,
      Offset(foeRect.center.dx - foeLabel.width / 2, foeRect.bottom + 10),
    );
  }

  void _paintPlayer(Canvas canvas, Rect rect) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    final sheet = _sheet;
    if (sheet != null) {
      sheet.paint(
        canvas,
        rect.size,
        dir: 2,
        moving: false,
        frame: 0,
      );
    } else {
      final stack = _stack;
      if (stack != null) {
        stack.paint(canvas, rect.size, PetWearLayout.defaults);
      } else {
        canvas.drawOval(
          Rect.fromLTWH(10, 10, rect.width - 20, rect.height - 20),
          Paint()..color = const Color(0xFFFFB7C5),
        );
      }
    }
    canvas.restore();
  }

  void _paintFoe(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(10), const Radius.circular(28)),
      Paint()..color = const Color(0x28E97891),
    );
    final m = _monster;
    if (m != null) {
      paintImage(
        canvas: canvas,
        rect: rect,
        image: m,
        fit: BoxFit.contain,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(20)),
        Paint()..color = PetAdventureGame.rose.withValues(alpha: 0.5),
      );
    }
  }
}
