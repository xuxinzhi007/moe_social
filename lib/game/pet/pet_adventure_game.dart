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

enum PetAdventureAction { attack, guard, skill }

/// 轻冒险：可操作回合战（攻击/防御/必杀），不再干看自动播片。
class PetAdventureGame extends FlameGame {
  PetAdventureGame({
    required this.playerPower,
    this.stageLabel = '小院试炼',
    this.hatId = '',
    this.topId = 'top_basic',
    this.bottomId = 'bottom_basic',
    this.shoesId = 'shoes_basic',
  }) {
    playerMaxHp = 72 + (playerPower * 1.2).round().clamp(0, 60);
    foeMaxHp = (88 + (36 - playerPower).clamp(-20, 40)).clamp(55, 130);
    playerHp = playerMaxHp;
    foeHp = foeMaxHp;
    _atk = 9 + playerPower ~/ 4;
  }

  static const ink = Color(0xFF5A4638);
  static const rose = Color(0xFFE97891);
  static const cream = Color(0xFFFFF6EE);
  static const winGreen = Color(0xFF6B9B76);
  static const loseRose = Color(0xFFC45B76);

  /// 兼容旧单测：战力门槛仍作参考（现改为血量战）。
  static const winThreshold = 28;

  final int playerPower;
  final String stageLabel;
  final String hatId;
  final String topId;
  final String bottomId;
  final String shoesId;

  late final int playerMaxHp;
  late final int foeMaxHp;
  late int playerHp;
  late int foeHp;
  late int _atk;

  bool? _win;
  bool _finished = false;
  bool _playerTurn = true;
  bool _guarding = false;
  int _skillCd = 0;
  double _enemyTimer = 0;
  String _status = '点下方按钮开战！';
  double _shake = 0;
  double _lunge = 0;
  final List<_FloatText> _floats = [];
  final math.Random _rng = math.Random();

  void Function(bool win)? onFinished;
  VoidCallback? onChanged;

  bool get finished => _finished;
  bool? get won => _win;
  bool get playerTurn => _playerTurn && !_finished;
  int get skillCooldown => _skillCd;
  bool get canSkill => _skillCd <= 0 && playerTurn;
  int get effectivePower => playerPower;
  int get boostTotal => 0;

  @override
  Color backgroundColor() => cream;

  @override
  Future<void> onLoad() async {
    _status = '遭遇野怪！轮到你了';
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(360, 640);
    await world.add(
      _AdventureStage(
        hatId: hatId,
        topId: topId,
        bottomId: bottomId,
        shoesId: shoesId,
      ),
    );
  }

  void _notify() => onChanged?.call();

  /// 兼容旧页按钮；现映射为普通攻击。
  void boost(int amount) => perform(PetAdventureAction.attack);

  void perform(PetAdventureAction action) {
    if (_finished || !_playerTurn) return;
    switch (action) {
      case PetAdventureAction.attack:
        _playerStrike(mult: 1.0, label: '攻击');
        return;
      case PetAdventureAction.guard:
        _guarding = true;
        _status = '防御姿态！下回合减伤';
        _floats.add(_FloatText('防御', Offset(0.30, 0.48), winGreen));
        _endPlayerTurn();
        return;
      case PetAdventureAction.skill:
        if (_skillCd > 0) {
          _status = '必杀冷却中（$_skillCd）';
          _notify();
          return;
        }
        _skillCd = 2;
        _playerStrike(mult: 1.85, label: '必杀');
        return;
    }
  }

  void _playerStrike({required double mult, required String label}) {
    final variance = 0.85 + _rng.nextDouble() * 0.3;
    final dmg = math.max(4, (_atk * mult * variance).round());
    foeHp = math.max(0, foeHp - dmg);
    _lunge = 1;
    _shake = 0.55;
    _status = '$label！-$dmg';
    _floats.add(_FloatText('-$dmg', Offset(0.70, 0.46), rose));
    if (foeHp <= 0) {
      resolve(true);
      return;
    }
    _endPlayerTurn();
  }

  void _endPlayerTurn() {
    _playerTurn = false;
    _enemyTimer = 0.55;
    if (_skillCd > 0 && !_guarding) {
      // skill cd ticks at end of full round in enemy phase
    }
    _notify();
  }

  void _enemyAct() {
    if (_finished) return;
    final wasGuard = _guarding;
    _guarding = false;
    final base = 7 + (foeMaxHp ~/ 18) + _rng.nextInt(5);
    final dmg = wasGuard ? math.max(2, (base * 0.45).round()) : base;
    playerHp = math.max(0, playerHp - dmg);
    _shake = 0.7;
    _status = wasGuard ? '挡住了！-$dmg' : '野怪袭击！-$dmg';
    _floats.add(_FloatText('-$dmg', Offset(0.30, 0.46), loseRose));
    if (_skillCd > 0) _skillCd -= 1;
    if (playerHp <= 0) {
      resolve(false);
      return;
    }
    _playerTurn = true;
    _enemyTimer = 0;
    _status = '轮到你了！';
    _notify();
  }

  void resolve(bool win) {
    if (_finished) return;
    _win = win;
    _status = win ? '胜利！获得掉落' : '惜败，休息后再来';
    _finished = true;
    _playerTurn = false;
    _notify();
    onFinished?.call(win);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_shake > 0) _shake = math.max(0, _shake - dt * 2.4);
    if (_lunge > 0) _lunge = math.max(0, _lunge - dt * 3.2);
    _floats.removeWhere((f) {
      f.t += dt;
      return f.t > 0.9;
    });
    if (_finished) return;
    if (!_playerTurn) {
      _enemyTimer -= dt;
      if (_enemyTimer <= 0) _enemyAct();
    } else {
      // 犹豫太久野怪偷袭
      _enemyTimer += dt;
      if (_enemyTimer > 4.5) {
        _status = '发呆被偷袭！';
        _playerTurn = false;
        _enemyTimer = 0.2;
        _notify();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final view = camera.viewport.size;
    final shakeX = math.sin(_shake * 40) * 6 * _shake;

    _paintBanner(canvas, view);
    _paintHpBars(canvas, view, shakeX);

    for (final f in _floats) {
      final p = (f.t / 0.9).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            color: f.color.withValues(alpha: 1 - p),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          view.x * f.origin.dx - tp.width / 2 + shakeX,
          view.y * f.origin.dy - 36 * p,
        ),
      );
    }
  }

  void _paintBanner(Canvas canvas, Vector2 view) {
    final tp = TextPainter(
      text: TextSpan(
        text: _status,
        style: TextStyle(
          color: (_win == true)
              ? winGreen
              : (_win == false)
                  ? loseRose
                  : ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: view.x - 48);
    const padH = 14.0;
    const padV = 9.0;
    final bw = math.min(tp.width + padH * 2, view.x - 32);
    final bh = tp.height + padV * 2;
    final left = (view.x - bw) / 2;
    final top = view.y * 0.10;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, bw, bh),
      const Radius.circular(16),
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

  void _paintHpBars(Canvas canvas, Vector2 view, double shakeX) {
    void bar(double cx, int hp, int max, Color color) {
      final w = view.x * 0.28;
      final left = cx - w / 2 + shakeX;
      final top = view.y * 0.18;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, w, 10),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0x33FFFFFF),
      );
      final ratio = max <= 0 ? 0.0 : (hp / max).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, w * ratio, 10),
          const Radius.circular(5),
        ),
        Paint()..color = color,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '$hp/$max',
          style: const TextStyle(
            color: ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(cx - label.width / 2 + shakeX, top + 12));
    }

    bar(view.x * 0.30, playerHp, playerMaxHp, winGreen);
    bar(view.x * 0.70, foeHp, foeMaxHp, rose);
  }
}

class _FloatText {
  _FloatText(this.text, this.origin, this.color);
  final String text;
  final Offset origin;
  final Color color;
  double t = 0;
}

class _AdventureStage extends PositionComponent
    with HasGameReference<PetAdventureGame> {
  _AdventureStage({
    required this.hatId,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
  });

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
    _monster = await PetArt.loadImage(PetArt.monsterHead, knockoutDarkBg: true);
  }

  @override
  void update(double dt) {
    _pulse += dt * 3.2;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final g = game;

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

    final bob = math.sin(_pulse) * 6;
    final lunge = g._lunge * 28;
    final shake = math.sin(g._shake * 40) * 8 * g._shake;
    final playerRect = Rect.fromCenter(
      center: Offset(w * 0.30 + lunge + shake, h * 0.52 + bob),
      width: 168,
      height: 220,
    );
    final foeRect = Rect.fromCenter(
      center: Offset(w * 0.70 - lunge * 0.35 - shake, h * 0.52 - bob * 0.5),
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
        text: '战力 ${g.playerPower}',
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
