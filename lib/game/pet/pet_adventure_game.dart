import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'pet_art.dart';

/// P3 轻冒险：短回合放置演出（无 HTTP；胜负由 Page 传入）。
class PetAdventureGame extends FlameGame {
  PetAdventureGame({
    required this.playerPower,
    this.stageLabel = '轻冒险',
  });

  final int playerPower;
  final String stageLabel;

  bool? _win;
  double _t = 0;
  String _status = '遭遇野怪…';
  bool _finished = false;

  void Function(bool win)? onFinished;

  @override
  Color backgroundColor() => const Color(0xFF2E3A4A);

  @override
  Future<void> onLoad() async {
    _status = '遭遇$stageLabel…';
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(360, 640);
    await world.add(_AdventureStage(playerPower: playerPower));
  }

  void resolve(bool win) {
    _win = win;
    _status = win ? '胜利！获得掉落' : '惜败…';
    _finished = true;
    onFinished?.call(win);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!_finished && _t > 1.6) {
      final win = playerPower >= 28;
      resolve(win);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final tp = TextPainter(
      text: TextSpan(
        text: _status,
        style: TextStyle(
          color: (_win == true)
              ? const Color(0xFF81C784)
              : (_win == false)
                  ? const Color(0xFFE57373)
                  : Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final view = camera.viewport.size;
    tp.paint(canvas, Offset((view.x - tp.width) / 2, view.y * 0.12));
  }
}

class _AdventureStage extends PositionComponent
    with HasGameReference<PetAdventureGame> {
  _AdventureStage({required this.playerPower});

  final int playerPower;
  double _pulse = 0;
  ui.Image? _player;
  ui.Image? _monster;

  @override
  Future<void> onLoad() async {
    size = Vector2(720, 1280);
    _player = await PetArt.loadImage(PetArt.body);
    _monster = await PetArt.loadImage(PetArt.monsterHead);
  }

  @override
  void update(double dt) {
    _pulse += dt * 4;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, size.y * 0.55, size.x, size.y * 0.45),
      Paint()..color = const Color(0xFF3E5245),
    );
    final bob = math.sin(_pulse) * 8;
    final playerRect = Rect.fromCenter(
      center: Offset(size.x * 0.28, size.y * 0.5 + bob),
      width: 220,
      height: 320,
    );
    final monsterRect = Rect.fromCenter(
      center: Offset(size.x * 0.72, size.y * 0.5 - bob),
      width: 220,
      height: 320,
    );
    if (_player != null) {
      paintImage(
        canvas: canvas,
        rect: playerRect,
        image: _player!,
        fit: BoxFit.contain,
      );
    } else {
      canvas.drawCircle(
        playerRect.center,
        54,
        Paint()..color = const Color(0xFFFFB7C5),
      );
    }
    if (_monster != null) {
      paintImage(
        canvas: canvas,
        rect: monsterRect,
        image: _monster!,
        fit: BoxFit.contain,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(monsterRect, const Radius.circular(20)),
        Paint()..color = const Color(0xFF8E24AA),
      );
    }
    final power = TextPainter(
      text: TextSpan(
        text: '战力 $playerPower',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    power.paint(
      canvas,
      Offset(size.x * 0.28 - power.width / 2, size.y * 0.58),
    );
  }
}
