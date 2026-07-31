import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/life_state.dart';

/// Flame 小世界（横屏世界坐标 1280×720）— 早期手感版：
/// 固定缩放可拖、点选跟随；不做「全图锁定 / 自动放大」。
class LifeFlameGame extends FlameGame {
  LifeFlameGame({
    required this.onEntityTap,
    this.onEntityLongPress,
  });

  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double _defaultZoom = 0.62;

  final void Function(int entityId) onEntityTap;
  final void Function(int entityId)? onEntityLongPress;

  final Map<int, _LifeEntityMarker> _markers = {};
  final Vector2 _cameraTarget = Vector2(worldWidth / 2, worldHeight / 2);

  bool _followSelected = true;
  bool _isPanning = false;

  @override
  Color backgroundColor() => const Color(0xFFD7F0DE);

  @override
  Future<void> onLoad() async {
    await world.add(_LifeWorldGround());
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = _cameraTarget.clone();
    camera.viewfinder.zoom = _defaultZoom;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isPanning) return;
    final current = camera.viewfinder.position;
    camera.viewfinder.position =
        current + (_cameraTarget - current) * (1 - math.exp(-4.2 * dt));
  }

  /// 手指拖动：世界坐标 delta（拖向右 → 镜头向左）。
  void panByWorldDelta(Vector2 delta) {
    if (delta.x.isNaN || delta.y.isNaN) return;
    _followSelected = false;
    _isPanning = true;
    _cameraTarget.setFrom(_clampCamera(_cameraTarget - delta));
    camera.viewfinder.position.setFrom(_cameraTarget);
  }

  void endPan() {
    _isPanning = false;
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
    final halfW = view.x / (2 * zoom);
    final halfH = view.y / (2 * zoom);
    return Vector2(
      pos.x.clamp(halfW, math.max(halfW, worldWidth - halfW)),
      pos.y.clamp(halfH, math.max(halfH, worldHeight - halfH)),
    );
  }

  void _focusCameraOnMarker(_LifeEntityMarker marker) {
    _followSelected = true;
    _cameraTarget.setFrom(_clampCamera(marker.position));
  }

  void syncEntities(List<LifeEntity> entities, {int? selectedId}) {
    final liveIds = <int>{};

    for (final entity in entities) {
      liveIds.add(entity.id);
      final existing = _markers[entity.id];
      if (existing == null) {
        final marker = _LifeEntityMarker(
          entity: entity,
          selected: entity.id == selectedId,
        );
        _markers[entity.id] = marker;
        world.add(marker);
      } else {
        existing.applyEntity(entity, selected: entity.id == selectedId);
      }
    }

    for (final id in _markers.keys.toList(growable: false)) {
      if (liveIds.contains(id)) continue;
      _markers[id]?.removeFromParent();
      _markers.remove(id);
    }

    if (!_followSelected || _isPanning) return;

    if (selectedId != null) {
      final selected = _markers[selectedId];
      if (selected != null) {
        _cameraTarget.setFrom(_clampCamera(selected.position));
        return;
      }
    }
    if (_markers.isNotEmpty) {
      var sx = 0.0;
      var sy = 0.0;
      for (final m in _markers.values) {
        sx += m.position.x;
        sy += m.position.y;
      }
      _cameraTarget.setFrom(
        _clampCamera(Vector2(sx / _markers.length, sy / _markers.length)),
      );
    }
  }

  void notifyTap(int entityId) {
    final marker = _markers[entityId];
    if (marker != null) _focusCameraOnMarker(marker);
    onEntityTap(entityId);
  }

  void notifyLongPress(int entityId) => onEntityLongPress?.call(entityId);
}

class _LifeWorldGround extends PositionComponent with DragCallbacks {
  _LifeWorldGround()
      : super(
          size: Vector2(LifeFlameGame.worldWidth, LifeFlameGame.worldHeight),
          position: Vector2.zero(),
          priority: -10,
        );

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final game = findGame();
    if (game is! LifeFlameGame) return;
    final delta = event.localDelta;
    if (delta.x.isNaN || delta.y.isNaN) return;
    game.panByWorldDelta(delta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final game = findGame();
    if (game is LifeFlameGame) game.endPan();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    final game = findGame();
    if (game is LifeFlameGame) game.endPan();
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final sky = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.y),
        const [
          Color(0xFFEAF6FF),
          Color(0xFFE7F8EA),
          Color(0xFFD8F0C8),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawRect(rect, sky);

    final grass = Paint()
      ..color = const Color(0xFF7BCB86).withValues(alpha: 0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * 0.5, size.y * 0.78),
        width: size.x * 1.1,
        height: size.y * 0.42,
      ),
      grass,
    );

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    const step = 80.0;
    for (var x = 0.0; x <= size.x; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), grid);
    }
    for (var y = 0.0; y <= size.y; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), grid);
    }

    _drawProp(canvas, const Offset(180, 160), '🌳', 42);
    _drawProp(canvas, const Offset(1080, 200), '🏡', 40);
    _drawProp(canvas, const Offset(920, 520), '🌸', 34);
    _drawProp(canvas, const Offset(260, 540), '🪨', 30);
    _drawProp(canvas, const Offset(640, 120), '☁️', 36);
  }

  void _drawProp(Canvas canvas, Offset center, String emoji, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}

class _LifeEntityMarker extends PositionComponent
    with TapCallbacks, LongPressCallbacks {
  _LifeEntityMarker({
    required this.entity,
    required this.selected,
  }) : super(
          size: Vector2(84, 100),
          anchor: Anchor.center,
          position: Vector2(entity.x, entity.y),
          priority: 20,
        );

  LifeEntity entity;
  bool selected;
  double _bob = 0;
  Vector2 _target = Vector2.zero();

  void applyEntity(LifeEntity next, {required bool selected}) {
    entity = next;
    this.selected = selected;
    _target = Vector2(next.x, next.y);
  }

  @override
  Future<void> onLoad() async {
    _target = position.clone();
  }

  @override
  void update(double dt) {
    _bob += dt * 2.4;
    position += (_target - position) * (1 - math.exp(-5.5 * dt));
  }

  @override
  void render(Canvas canvas) {
    final bobY = math.sin(_bob) * (selected ? 3.2 : 2.0);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + bobY);

    canvas.drawOval(
      const Rect.fromLTWH(-22, 28, 44, 12),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    if (selected) {
      canvas.drawCircle(
        Offset.zero,
        34,
        Paint()
          ..color = const Color(0xFF7C75DD).withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset.zero,
        34,
        Paint()
          ..color = const Color(0xFF7C75DD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    canvas.drawCircle(
      Offset.zero,
      28,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    final emoji = TextPainter(
      text: TextSpan(
        text: entity.emoji.trim().isEmpty ? '🐣' : entity.emoji,
        style: const TextStyle(fontSize: 30),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emoji.paint(canvas, Offset(-emoji.width / 2, -emoji.height / 2 - 2));

    final name = TextPainter(
      text: TextSpan(
        text: entity.name,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF243447),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    name.paint(canvas, Offset(-name.width / 2, 30));

    final label = entity.actionLabel.trim();
    if (label.isNotEmpty) {
      final bubble = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5B4B8A),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(0, -40),
          width: bubble.width + 14,
          height: bubble.height + 10,
        ),
        const Radius.circular(10),
      );
      canvas.drawRRect(
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      bubble.paint(canvas, Offset(-bubble.width / 2, -40 - bubble.height / 2));
    }

    canvas.restore();
  }

  @override
  void onTapUp(TapUpEvent event) {
    final game = findGame();
    if (game is LifeFlameGame) game.notifyTap(entity.id);
  }

  @override
  void onLongPressStart(LongPressStartEvent event) {
    super.onLongPressStart(event);
    final game = findGame();
    if (game is LifeFlameGame) game.notifyLongPress(entity.id);
  }
}
