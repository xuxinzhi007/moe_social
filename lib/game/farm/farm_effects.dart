import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/farm_crop_config.dart';

/// 上浮飘字（金币/提示），带淡出与轻微摇摆。
class FarmFloatText extends PositionComponent {
  FarmFloatText({
    required this.text,
    required Color color,
    this.fontSize = 22,
    super.position,
    this.duration = 1.15,
    this.riseDistance = 68,
  }) : _color = color;

  final String text;
  final Color _color;
  final double fontSize;
  final double duration;
  final double riseDistance;

  double _t = 0;

  @override
  Future<void> onLoad() async {
    size = Vector2(160, 40);
    anchor = Anchor.center;
    priority = 200;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = _t / duration;
    final alpha = p < 0.7 ? 1.0 : (1 - (p - 0.7) / 0.3);
    final rise = Curves.easeOutCubic.transform(p) * riseDistance;
    final pop = p < 0.15 ? 0.6 + 0.4 * (p / 0.15) : 1.0;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 - rise);
    canvas.scale(pop);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _color.withValues(alpha: alpha),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Color(0xCCFFFFFF), blurRadius: 5),
            Shadow(color: Color(0x55000000), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );
    canvas.restore();
  }
}

/// 粒子爆裂（水滴/金币星屑/变异彩带）。
class FarmParticleBurst extends PositionComponent {
  FarmParticleBurst({
    required this.kind,
    super.position,
    this.count = 14,
  });

  final FarmParticleKind kind;
  final int count;

  double _t = 0;
  late final List<_Particle> _parts;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(1);
    anchor = Anchor.center;
    priority = 190;
    final rng = math.Random();
    _parts = List.generate(count, (i) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 90 + rng.nextDouble() * 130;
      return _Particle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 120,
        size: 4 + rng.nextDouble() * 5,
        hue: rng.nextDouble() * 360,
        spin: (rng.nextDouble() - 0.5) * 8,
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  double get duration => switch (kind) {
        FarmParticleKind.water => 0.7,
        FarmParticleKind.harvest => 0.95,
        FarmParticleKind.mutation => 1.4,
      };

  @override
  void render(Canvas canvas) {
    final life = duration;
    for (final p in _parts) {
      final progress = _t / life;
      if (progress >= 1) continue;
      final alpha = 1 - progress;
      final x = p.vx * _t;
      final y = p.vy * _t + 340 * _t * _t; // 重力。
      final s = p.size * (1 - progress * 0.5);
      switch (kind) {
        case FarmParticleKind.water:
          canvas.drawCircle(
            Offset(x, y),
            s * 0.7,
            Paint()..color = const Color(0xFF63B8E8).withValues(alpha: alpha),
          );
        case FarmParticleKind.harvest:
          // 金币圆片 + 白闪。
          canvas.drawCircle(
            Offset(x, y),
            s,
            Paint()..color = const Color(0xFFFFC93C).withValues(alpha: alpha),
          );
          canvas.drawCircle(
            Offset(x - s * 0.3, y - s * 0.3),
            s * 0.32,
            Paint()..color = Colors.white.withValues(alpha: alpha * 0.8),
          );
        case FarmParticleKind.mutation:
          final c = HSVColor.fromAHSV(alpha, (p.hue + _t * 160) % 360, 0.85, 1)
              .toColor();
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(p.spin * _t);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s),
            Paint()..color = c,
          );
          canvas.restore();
      }
    }
  }
}

enum FarmParticleKind { water, harvest, mutation }

class _Particle {
  _Particle({
    required this.vx,
    required this.vy,
    required this.size,
    required this.hue,
    required this.spin,
  });

  final double vx;
  final double vy;
  final double size;
  final double hue;
  final double spin;
}

/// 收获弹跳幽灵：作物图/色团从田块抛物线飞向 HUD 金币区。
class FarmHarvestFlyer extends PositionComponent {
  FarmHarvestFlyer({
    required this.startWorld,
    required this.targetWorld,
    required this.tint,
    this.image,
  });

  final Vector2 startWorld;
  final Vector2 targetWorld;
  final Color tint;
  final ui.Image? image;

  double _t = 0;
  static const _duration = 0.62;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(48);
    anchor = Anchor.center;
    priority = 220;
    position = startWorld;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final p = (_t / _duration).clamp(0.0, 1.0);
    final eased = Curves.easeInQuad.transform(p);
    position = startWorld + (targetWorld - startWorld) * eased;
    // 抛物线抬升。
    position.y -= math.sin(p * math.pi) * 110;
    scale = Vector2.all(1 - 0.35 * p);
    if (p >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final img = image;
    if (img != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size.toSize(),
        image: img,
        fit: BoxFit.contain,
      );
    } else {
      canvas.drawCircle(
        size.toOffset() / 2,
        size.x / 2,
        Paint()..color = tint,
      );
      canvas.drawCircle(
        size.toOffset() / 2 - const Offset(5, 5),
        size.x * 0.16,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }
}

/// 连收 Combo 横幅（挂在 viewport，屏幕坐标）。
class FarmComboBanner extends PositionComponent {
  FarmComboBanner();

  int combo = 0;
  double _flash = 0;

  void punch(int newCombo) {
    combo = newCombo;
    _flash = 1;
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(220, 60);
    anchor = Anchor.topRight;
    priority = 500;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x - 16, 64);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash = math.max(0, _flash - dt * 2.2);
  }

  @override
  void render(Canvas canvas) {
    if (combo < 2) return;
    final scalePop = 1 + 0.3 * _flash;
    canvas.save();
    canvas.translate(size.x, 0);
    canvas.scale(scalePop);
    canvas.translate(-size.x, 0);

    final painter = TextPainter(
      text: TextSpan(
        text: '连收 ×$combo',
        style: TextStyle(
          color: combo >= 4
              ? const Color(0xFFFF6B81)
              : const Color(0xFFFFA94D),
          fontSize: combo >= 4 ? 26 : 22,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Color(0xEEFFFFFF), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(size.x - painter.width, 8));
    canvas.restore();
  }
}

/// 每日首收庆祝横幅（一次性）。
class FarmDailyFirstBanner extends PositionComponent {
  FarmDailyFirstBanner() : super(priority: 510);

  double _t = 0;
  static const _duration = 2.2;

  @override
  Future<void> onLoad() async {
    size = Vector2(320, 56);
    anchor = Anchor.center;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x / 2, size.y * 0.18);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = _t / _duration;
    final alpha = p < 0.15 ? p / 0.15 : (p > 0.75 ? (1 - p) / 0.25 : 1.0);
    final pop = p < 0.18 ? Curves.easeOutBack.transform(p / 0.18) : 1.0;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(pop);

    final bg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.x,
        height: size.y,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = const Color(0xFFE97891).withValues(alpha: 0.92 * alpha),
    );
    final painter = TextPainter(
      text: const TextSpan(
        text: '今日首收 · 双倍奖励！',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );
    canvas.restore();
  }
}

/// 根据收获结果选择粒子风格。
FarmParticleKind particleKindOf(FarmHarvestMutationTier tier) => switch (tier) {
      FarmHarvestMutationTier.normal => FarmParticleKind.harvest,
      FarmHarvestMutationTier.golden ||
      FarmHarvestMutationTier.rainbow =>
        FarmParticleKind.mutation,
    };

/// 特效选择用的轻量档位（避免 effects 依赖 provider）。
enum FarmHarvestMutationTier { normal, golden, rainbow }

FarmHarvestMutationTier tierOf(FarmMutation m) => switch (m) {
      FarmMutation.none => FarmHarvestMutationTier.normal,
      FarmMutation.golden => FarmHarvestMutationTier.golden,
      FarmMutation.rainbow => FarmHarvestMutationTier.rainbow,
    };
