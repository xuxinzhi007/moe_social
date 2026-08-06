import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/farm_crop_config.dart';
import '../../models/farm_state.dart';
import '../pet/pet_art.dart';

/// 单株作物渲染：生长可视化（渐进缩放 + 摇曳）、成熟脉冲、变异光晕。
///
/// 素材缺失时回落到程序化「萌系色团」绘制，保证玩法可完整体验。
class FarmCropSprite extends PositionComponent {
  FarmCropSprite() : super(size: Vector2.all(FarmGrid.tileSize), anchor: Anchor.center);

  FarmPlot _plot = FarmPlot(index: 0);
  final Map<FarmCropStage, ui.Image?> _images = {};
  String _loadedCropId = '';

  double _time = 0;
  double _popT = 1; // 阶段晋升弹跳（1=完成）。
  FarmCropStage _lastStage = FarmCropStage.empty;

  /// 收获/种植瞬间由外部触发的大弹跳。
  double bounceT = 1;

  void apply(FarmPlot plot) {
    if (_lastStage != FarmCropStage.empty &&
        plot.stage != _lastStage &&
        plot.stage != FarmCropStage.empty) {
      _popT = 0;
    }
    if (plot.isEmpty && !_plot.isEmpty) {
      bounceT = 0; // 收获弹跳。
    }
    _lastStage = plot.stage;
    _plot = plot;
    if (plot.cropId != _loadedCropId) {
      _loadedCropId = plot.cropId;
      _images.clear();
      if (plot.cropId.isNotEmpty) {
        _loadImages(plot.cropId);
      }
    }
  }

  Future<void> _loadImages(String cropId) async {
    for (final stage in const [
      FarmCropStage.seed,
      FarmCropStage.sprout,
      FarmCropStage.ripe,
    ]) {
      final img = await PetArt.loadImage(FarmArt.crop(cropId, stage));
      if (_loadedCropId != cropId) return; // 已换作物，丢弃。
      _images[stage] = img;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_popT < 1) _popT = math.min(1, _popT + dt * 3.2);
    if (bounceT < 1) bounceT = math.min(1, bounceT + dt * 2.4);
  }

  /// 0~1：总生长进度（ripe 恒 1）。
  double get _growRatio {
    if (_plot.isEmpty) return 0;
    return (_plot.progressSeconds / _plot.config.totalSeconds).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    if (_plot.isEmpty) return;
    final cfg = _plot.config;
    final stage = _plot.stage;
    final cx = size.x / 2;
    final baseY = size.y * 0.62; // 作物扎根点。

    // 生长可视化：0.45 → 1.0 渐进放大；成熟轻微呼吸。
    var scale = 0.45 + 0.55 * _growRatio;
    if (_plot.isRipe) {
      scale *= 1 + 0.04 * math.sin(_time * 3.2);
    }
    // 阶段晋升弹跳（easeOutBack）。
    if (_popT < 1) {
      scale *= 1 + 0.35 * Curves.easeOutBack.transform(_popT) - 0.1;
    }

    // 摇曳：生长中轻摆，成熟摆幅更大（招收割）。
    final sway = math.sin(_time * (_plot.isRipe ? 3.8 : 2.2)) *
        (_plot.isRipe ? 0.07 : 0.035);

    canvas.save();
    canvas.translate(cx, baseY);
    canvas.rotate(sway);
    canvas.scale(scale);

    // 变异光晕（先画在作物底下）。
    if (_plot.isRipe && _plot.pendingMutation != FarmMutation.none) {
      _renderMutationGlow(canvas);
    }

    final img = _images[stage];
    const cropH = 96.0;
    if (img != null) {
      final w = cropH * img.width / img.height;
      paintImage(
        canvas: canvas,
        rect: Rect.fromCenter(
          center: Offset(0, -cropH / 2),
          width: w,
          height: cropH,
        ),
        image: img,
        fit: BoxFit.contain,
      );
    } else {
      _renderProcedural(canvas, cfg, stage);
    }
    canvas.restore();

    // 生长进度环（未成熟时悬浮在头顶）。
    if (!_plot.isRipe) {
      _renderProgressRing(canvas, Offset(cx, size.y * 0.14));
    } else {
      _renderRipeSparkle(canvas, Offset(cx, size.y * 0.18));
    }
  }

  /// 萌系色团回落绘制：茎 + 叶 + 果实轮廓，用配置 tint 区分作物。
  void _renderProcedural(Canvas canvas, FarmCropConfig cfg, FarmCropStage stage) {
    final tint = Color(cfg.tint);
    final leaf = const Color(0xFF5FA052);
    switch (stage) {
      case FarmCropStage.seed:
        // 小芽：两片嫩叶。
        final stem = Paint()..color = const Color(0xFF7CB86A);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -34, 6, 34),
            const Radius.circular(3),
          ),
          stem,
        );
        canvas.drawOval(
          const Rect.fromLTWH(-16, -44, 15, 10),
          Paint()..color = leaf,
        );
        canvas.drawOval(
          const Rect.fromLTWH(1, -48, 15, 10),
          Paint()..color = const Color(0xFF74C365),
        );
      case FarmCropStage.sprout:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -52, 8, 52),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFF6FAF5E),
        );
        canvas.drawOval(
          const Rect.fromLTWH(-24, -62, 22, 14),
          Paint()..color = leaf,
        );
        canvas.drawOval(
          const Rect.fromLTWH(2, -68, 22, 14),
          Paint()..color = const Color(0xFF74C365),
        );
        canvas.drawCircle(
          const Offset(0, -56),
          10,
          Paint()..color = tint.withValues(alpha: 0.85),
        );
      case FarmCropStage.ripe:
        // 成熟果实主体 + 高光。
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -40, 8, 40),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFF6FAF5E),
        );
        canvas.drawOval(
          const Rect.fromLTWH(-30, -36, 26, 16),
          Paint()..color = leaf,
        );
        canvas.drawOval(
          const Rect.fromLTWH(4, -42, 26, 16),
          Paint()..color = const Color(0xFF74C365),
        );
        canvas.drawCircle(
          const Offset(0, -62),
          24,
          Paint()..color = tint,
        );
        canvas.drawCircle(
          const Offset(-8, -70),
          7,
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      case FarmCropStage.empty:
        break;
    }
  }

  void _renderMutationGlow(Canvas canvas) {
    final isRainbow = _plot.pendingMutation == FarmMutation.rainbow;
    final pulse = 0.6 + 0.4 * math.sin(_time * 5);
    final color = isRainbow
        ? HSVColor.fromAHSV(0.5, (_time * 90) % 360, 0.9, 1).toColor()
        : const Color(0xFFFFD700).withValues(alpha: 0.5 * pulse + 0.2);
    canvas.drawCircle(
      const Offset(0, -52),
      46 + 6 * pulse,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _renderProgressRing(Canvas canvas, Offset center) {
    const r = 11.0;
    canvas.drawCircle(center, r, Paint()..color = const Color(0xAAFFFFFF));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      2 * math.pi * _growRatio,
      false,
      Paint()
        ..color = const Color(0xFF6FBF5A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _renderRipeSparkle(Canvas canvas, Offset center) {
    // 三颗错峰闪烁星点，提示「可收」。
    for (var i = 0; i < 3; i++) {
      final phase = _time * 2.6 + i * 2.1;
      final alpha = (math.sin(phase).clamp(0.0, 1.0)) * 0.9;
      if (alpha < 0.05) continue;
      final dx = math.cos(i * 2.4) * 22;
      final dy = math.sin(i * 2.9) * 8;
      final p = Offset(center.dx + dx, center.dy + dy);
      final paint = Paint()..color = Color.fromRGBO(255, 244, 180, alpha);
      canvas.drawCircle(p, 3.2, paint);
      canvas.drawLine(
        p - const Offset(6, 0),
        p + const Offset(6, 0),
        paint..strokeWidth = 1.4,
      );
      canvas.drawLine(
        p - const Offset(0, 6),
        p + const Offset(0, 6),
        paint,
      );
    }
  }
}
