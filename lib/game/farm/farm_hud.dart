import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../pet/pet_art.dart';
import '../../models/farm_crop_config.dart';

/// 视口 HUD：右上角金币数 + 底部「N 块可收获」提示条。
///
/// 数值由页面层通过 [syncCoins] / [syncRipeCount] 推入，
/// HUD 只负责游戏内呈现（Material 按钮在页面 overlay 层）。
class FarmHudLayer extends PositionComponent
    with HasGameReference {
  FarmHudLayer() : super(priority: 400);

  int _coins = 0;
  int _ripe = 0;
  double _ripePulse = 0;
  ui.Image? _coinIcon;

  @override
  Future<void> onLoad() async {
    size = Vector2.zero();
    _coinIcon = await PetArt.loadImage(FarmArt.coinIcon);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
  }

  void syncCoins(int coins) {
    _coins = coins;
  }

  void syncRipeCount(int ripe) {
    if (ripe > _ripe) _ripePulse = 1;
    _ripe = ripe;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_ripePulse > 0) _ripePulse = (_ripePulse - dt * 1.6).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    _renderCoinPill(canvas);
    _renderRipePill(canvas);
  }

  void _renderCoinPill(Canvas canvas) {
    const h = 36.0;
    final text = TextPainter(
      text: TextSpan(
        text: '$_coins',
        style: const TextStyle(
          color: Color(0xFF7A5C1E),
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = text.width + 52;
    final rect = Rect.fromLTWH(size.x - w - 14, 14, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(h / 2)),
      Paint()..color = const Color(0xEEFFF3D6),
    );
    final icon = _coinIcon;
    if (icon != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(rect.left + 8, rect.top + 6, 24, 24),
        image: icon,
        fit: BoxFit.contain,
      );
    } else {
      canvas.drawCircle(
        Offset(rect.left + 20, rect.top + h / 2),
        11,
        Paint()..color = const Color(0xFFFFC93C),
      );
      canvas.drawCircle(
        Offset(rect.left + 17, rect.top + h / 2 - 3),
        3.5,
        Paint()..color = const Color(0xAAFFFFFF),
      );
    }
    text.paint(canvas, Offset(rect.left + 38, rect.top + (h - text.height) / 2));
  }

  void _renderRipePill(Canvas canvas) {
    if (_ripe <= 0) return;
    final scale = 1 + 0.08 * _ripePulse;
    final text = TextPainter(
      text: TextSpan(
        text: '$_ripe 块作物可收获',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const h = 30.0;
    final w = text.width + 28;
    canvas.save();
    canvas.translate(size.x / 2, size.y - 118);
    canvas.scale(scale);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: w,
      height: h,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(h / 2)),
      Paint()..color = const Color(0xDD5FA052),
    );
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }
}
