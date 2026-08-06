import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/farm_crop_config.dart';
import '../../models/farm_state.dart';
import '../pet/pet_art.dart';
import 'farm_crop_sprite.dart';
import 'farm_game.dart';

/// 农场田块网格：(col,row) 逻辑坐标 ↔ 世界像素的 SSOT。
///
/// 世界尺寸 = [FarmGrid.cols]×[FarmGrid.rows] × [FarmGrid.tileSize]。
class FarmTileGrid extends PositionComponent
    with HasGameReference<FarmFlameGame> {
  FarmTileGrid({required this.onPlotTap, required this.onPlotLongPress});

  final void Function(int index) onPlotTap;
  final void Function(int index) onPlotLongPress;

  final List<FarmPlotTile> _tiles = [];
  ui.Image? soilDry;
  ui.Image? soilWet;
  ui.Image? grass;

  /// 逻辑坐标 → 格子中心世界像素。
  static Vector2 tileCenter(int index) {
    final t = FarmGrid.tileSize;
    return Vector2(
      FarmGrid.colOf(index) * t + t / 2,
      FarmGrid.rowOf(index) * t + t / 2,
    );
  }

  /// 世界像素 → 格子 index；越界返回 null。
  static int? tileAt(Vector2 worldPoint) {
    final col = (worldPoint.x / FarmGrid.tileSize).floor();
    final row = (worldPoint.y / FarmGrid.tileSize).floor();
    if (!FarmGrid.inBounds(col, row)) return null;
    return FarmGrid.indexOf(col, row);
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(FarmGrid.worldWidth, FarmGrid.worldHeight);
    priority = 0;
    // 缺图时 loadImage 返回 null，渲染层自动回落程序化绘制。
    soilDry = await PetArt.loadImage(FarmArt.soilDry);
    soilWet = await PetArt.loadImage(FarmArt.soilWet);
    grass = await PetArt.loadImage(FarmArt.grassTile);

    for (var i = 0; i < FarmGrid.plotCount; i++) {
      final tile = FarmPlotTile(
        index: i,
        onTap: () => onPlotTap(i),
        onLongPress: () => onPlotLongPress(i),
      );
      tile.position = tileCenter(i);
      _tiles.add(tile);
      await add(tile);
    }
  }

  void sync(List<FarmPlot> plots) {
    for (var i = 0; i < _tiles.length; i++) {
      final plot = i < plots.length ? plots[i] : FarmPlot(index: i);
      _tiles[i].apply(plot);
    }
  }

  @override
  void render(Canvas canvas) {
    // 草地底：平铺 grass tile，缺图回落纯色。
    final grassImg = grass;
    if (grassImg != null) {
      const step = 128.0;
      for (var y = 0.0; y < size.y; y += step) {
        for (var x = 0.0; x < size.x; x += step) {
          canvas.drawImageRect(
            grassImg,
            Rect.fromLTWH(0, 0, grassImg.width.toDouble(),
                grassImg.height.toDouble()),
            Rect.fromLTWH(x, y, step, step),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
      }
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF8FCF7E),
      );
    }
    // 淡网格线帮助定位。
    final line = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (var c = 1; c < FarmGrid.cols; c++) {
      final x = c * FarmGrid.tileSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), line);
    }
    for (var r = 1; r < FarmGrid.rows; r++) {
      final y = r * FarmGrid.tileSize;
      canvas.drawLine(Offset(0, y), Offset(size.x, y), line);
    }
  }
}

/// 单个田块：土壤 + 内嵌 [FarmCropSprite]；接收点击/长按。
class FarmPlotTile extends PositionComponent
    with TapCallbacks, LongPressCallbacks, HasGameReference<FarmFlameGame> {
  FarmPlotTile({
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  FarmPlot _plot = FarmPlot(index: 0);
  late final FarmCropSprite cropSprite;
  double _pressGlow = 0;
  bool _pressed = false;

  @override
  Future<void> onLoad() async {
    size = Vector2(FarmGrid.tileSize, FarmGrid.tileSize);
    anchor = Anchor.center;
    cropSprite = FarmCropSprite();
    cropSprite.position = size / 2;
    await add(cropSprite);
  }

  void apply(FarmPlot plot) {
    _plot = plot;
    cropSprite.apply(plot);
  }

  FarmPlot get plot => _plot;

  @override
  void update(double dt) {
    super.update(dt);
    _pressGlow = _pressed
        ? (_pressGlow + dt * 6).clamp(0.0, 1.0)
        : (_pressGlow - dt * 6).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    final t = size.x;
    final inset = 8.0;
    final soilRect = Rect.fromLTWH(inset, inset, t - inset * 2, t - inset * 2);

    final wet = _plot.waterCount > 0 && !_plot.isRipe;
    final img = wet ? game.tileGrid.soilWet : game.tileGrid.soilDry;
    if (img != null) {
      paintImage(
        canvas: canvas,
        rect: soilRect,
        image: img,
        fit: BoxFit.fill,
      );
    } else {
      // 程序化回落：干土棕 / 湿土深棕。
      final base = wet ? const Color(0xFF6B4F35) : const Color(0xFF9A7350);
      canvas.drawRRect(
        RRect.fromRectAndRadius(soilRect, const Radius.circular(14)),
        Paint()..color = base,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          soilRect.deflate(5),
          const Radius.circular(10),
        ),
        Paint()..color = wet
            ? const Color(0xFF5C4229)
            : const Color(0xFF8D6A48),
      );
      // 三条垄沟。
      final groove = Paint()
        ..color = const Color(0x33000000)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i <= 3; i++) {
        final y = soilRect.top + soilRect.height * i / 4;
        canvas.drawLine(
          Offset(soilRect.left + 16, y),
          Offset(soilRect.right - 16, y),
          groove,
        );
      }
    }

    // 长按高亮反馈。
    if (_pressGlow > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(soilRect, const Radius.circular(14)),
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, 0.28 * _pressGlow),
        );
    }
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();

  @override
  void onLongPressStart(LongPressStartEvent event) {
    super.onLongPressStart(event);
    _pressed = true;
  }

  @override
  void onLongPressEnd(LongPressEndEvent event) {
    super.onLongPressEnd(event);
    _pressed = false;
    onLongPress();
  }

  @override
  void onLongPressCancel(LongPressCancelEvent event) {
    super.onLongPressCancel(event);
    _pressed = false;
  }
}
