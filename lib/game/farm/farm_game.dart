import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/farm_crop_config.dart';
import '../../models/farm_state.dart';
import 'farm_effects.dart';
import 'farm_hud.dart';
import 'farm_tile_grid.dart';

/// QQ 农场 Flame 舞台：[FarmGrid.cols]×[FarmGrid.rows] 田块世界。
///
/// 相机方案与 [LifeFlameGame] 对齐：
/// - 拖拽层挂 viewport（整屏可拖，不挡世界点选）
/// - 竖屏按可视余量抬 zoom，双轴都留可拖空间
class FarmFlameGame extends FlameGame {
  FarmFlameGame({
    required this.onPlotTap,
    required this.onPlotLongPress,
  });

  final void Function(int index) onPlotTap;
  final void Function(int index) onPlotLongPress;

  static const double worldWidth = FarmGrid.worldWidth; // 768
  static const double worldHeight = FarmGrid.worldHeight; // 1024
  static const double _minPanSlackFraction = 0.12;

  late final FarmTileGrid tileGrid;
  late final FarmHudLayer hud;
  late final FarmComboBanner comboBanner;

  @override
  Color backgroundColor() => const Color(0xFF7FBF6E);

  @override
  Future<void> onLoad() async {
    tileGrid = FarmTileGrid(
      onPlotTap: onPlotTap,
      onPlotLongPress: onPlotLongPress,
    );
    await world.add(tileGrid);

    camera.viewfinder.anchor = Anchor.center;
    _applyFitZoom();
    camera.viewfinder.position = _clampCamera(
      Vector2(worldWidth / 2, worldHeight / 2),
    );
    await camera.viewport.add(_ViewportPanLayer());

    comboBanner = FarmComboBanner();
    await camera.viewport.add(comboBanner);
    hud = FarmHudLayer();
    await camera.viewport.add(hud);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _applyFitZoom();
    camera.viewfinder.position = _clampCamera(camera.viewfinder.position);
  }

  /// 竖屏世界偏高：zoom 取「两轴都留可拖余量」的较大者。
  void _applyFitZoom() {
    final view = camera.viewport.size;
    if (view.x <= 0 || view.y <= 0) return;
    final maxVisibleW = worldWidth * (1 - _minPanSlackFraction);
    final maxVisibleH = worldHeight * (1 - _minPanSlackFraction);
    final zoomForWidth = view.x / maxVisibleW;
    final zoomForHeight = view.y / maxVisibleH;
    camera.viewfinder.zoom = math.max(zoomForWidth, zoomForHeight);
  }

  Vector2 _clampCamera(Vector2 pos) {
    final zoom = camera.viewfinder.zoom;
    final view = camera.viewport.size;
    if (view.x <= 0 || view.y <= 0) {
      return Vector2(
        pos.x.clamp(0, worldWidth),
        pos.y.clamp(0, worldHeight),
      );
    }
    final ax = camera.viewfinder.anchor.x;
    final ay = camera.viewfinder.anchor.y;
    final visibleW = view.x / zoom;
    final visibleH = view.y / zoom;
    final minX = ax * visibleW;
    final maxX = worldWidth - (1 - ax) * visibleW;
    final minY = ay * visibleH;
    final maxY = worldHeight - (1 - ay) * visibleH;
    return Vector2(
      pos.x.clamp(minX, math.max(minX, maxX)),
      pos.y.clamp(minY, math.max(minY, maxY)),
    );
  }

  void panByScreenDelta(Vector2 screenDelta) {
    if (screenDelta.x.isNaN || screenDelta.y.isNaN) return;
    if (screenDelta.x == 0 && screenDelta.y == 0) return;
    final zoom = camera.viewfinder.zoom.clamp(0.01, 10.0);
    final worldDelta = Vector2(-screenDelta.x / zoom, -screenDelta.y / zoom);
    camera.viewfinder.position = _clampCamera(
      camera.viewfinder.position + worldDelta,
    );
  }

  // ------------------------------------------------------------ 状态同步

  void syncState(FarmState state) {
    tileGrid.sync(state.plots);
    hud.syncRipeCount(state.ripeCount);
  }

  // ------------------------------------------------------------ 爽感特效

  /// 种植反馈：嫩芽飘字 + 少量绿屑。
  void playPlant(int index, FarmCropConfig config) {
    final center = FarmTileGrid.tileCenter(index);
    world.add(FarmFloatText(
      text: '种下${config.label}',
      color: const Color(0xFF5FA052),
      fontSize: 18,
      position: center - Vector2(0, 40),
      riseDistance: 46,
    ));
    world.add(FarmParticleBurst(
      kind: FarmParticleKind.water,
      position: center,
      count: 8,
    ));
  }

  /// 浇水反馈：水滴爆裂 + 提示。
  void playWater(int index) {
    final center = FarmTileGrid.tileCenter(index);
    world.add(FarmParticleBurst(
      kind: FarmParticleKind.water,
      position: center - Vector2(0, 20),
      count: 16,
    ));
    world.add(FarmFloatText(
      text: '浇水加速 30%',
      color: const Color(0xFF5C9EAD),
      fontSize: 16,
      position: center - Vector2(0, 48),
      riseDistance: 42,
    ));
  }

  /// 收获反馈：金币飘字 + 爆裂 + 飞向 HUD 的收获物。
  void playHarvest({
    required int index,
    required int coins,
    required FarmMutation mutation,
    required Color tint,
  }) {
    final center = FarmTileGrid.tileCenter(index);
    final tier = tierOf(mutation);

    world.add(FarmParticleBurst(
      kind: particleKindOf(tier),
      position: center - Vector2(0, 24),
      count: mutation == FarmMutation.none ? 14 : 26,
    ));

    final label = mutation == FarmMutation.none
        ? '+$coins'
        : '+$coins ${mutation.label}!';
    world.add(FarmFloatText(
      text: label,
      color: mutation == FarmMutation.rainbow
          ? const Color(0xFFB16CEA)
          : (mutation == FarmMutation.golden
              ? const Color(0xFFFFB300)
              : const Color(0xFFE97891)),
      fontSize: mutation == FarmMutation.none ? 22 : 26,
      position: center - Vector2(0, 44),
    ));

    // 收获物抛物线飞向右上方 HUD 金币区（屏幕坐标 → 世界坐标）。
    final viewSize = camera.viewport.size;
    final visible = camera.visibleWorldRect;
    final target = Vector2(
      visible.left + visible.width * ((viewSize.x - 56) / viewSize.x),
      visible.top + visible.height * (44 / viewSize.y),
    );
    world.add(FarmHarvestFlyer(
      startWorld: center - Vector2(0, 30),
      targetWorld: target,
      tint: tint,
    ));
  }

  void punchCombo(int combo) => comboBanner.punch(combo);

  void playDailyFirst() {
    camera.viewport.add(FarmDailyFirstBanner());
  }

  /// 一键全收时的整屏庆祝。
  void playHarvestAll(int totalCoins, int count) {
    final center = Vector2(worldWidth / 2, worldHeight / 2);
    world.add(FarmFloatText(
      text: '全田收割 +$totalCoins ($count块)',
      color: const Color(0xFFE97891),
      fontSize: 26,
      position: center,
      riseDistance: 90,
      duration: 1.6,
    ));
    world.add(FarmParticleBurst(
      kind: FarmParticleKind.harvest,
      position: center,
      count: 30,
    ));
  }

  /// 道具特效（肥料/阳光）。
  void playItemBoost(int? index, String itemId) {
    final center = index != null
        ? FarmTileGrid.tileCenter(index)
        : Vector2(worldWidth / 2, worldHeight / 2);
    world.add(FarmParticleBurst(
      kind: FarmParticleKind.water,
      position: center,
      count: index == null ? 24 : 12,
    ));
    world.add(FarmFloatText(
      text: itemId == 'sunshine' ? '阳光普照！' : '施肥加速！',
      color: itemId == 'sunshine'
          ? const Color(0xFFFFB300)
          : const Color(0xFFB08968),
      fontSize: 18,
      position: center - Vector2(0, 44),
    ));
  }
}

/// 挂在 viewport 的整屏拖拽层（不拦截世界 Tap/LongPress）。
class _ViewportPanLayer extends PositionComponent
    with DragCallbacks, HasGameReference<FarmFlameGame> {
  _ViewportPanLayer() : super(priority: -100);

  @override
  Future<void> onLoad() async {
    size = game.size;
    position = Vector2.zero();
    anchor = Anchor.topLeft;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    game.panByScreenDelta(event.localDelta);
  }
}
