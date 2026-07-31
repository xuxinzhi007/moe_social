import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/life_state.dart';

/// Flame 小世界（1280×720）。
///
/// 相机/拖拽按官方推荐：
/// - 输入用组件 [DragCallbacks]（勿混用已弃用的 [PanDetector] + TapCallbacks）
/// - 平移层挂在 [CameraComponent.viewport]（整屏可拖，不挡世界点选）
/// - 跟随用 [CameraComponent.follow] / [CameraComponent.stop]
/// 参考：https://docs.flame-engine.org/latest/flame/inputs/gesture_input.html
///       https://docs.flame-engine.org/latest/flame/camera.html
class LifeFlameGame extends FlameGame {
  LifeFlameGame({
    required this.onEntityTap,
    this.onEntityLongPress,
  });

  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double _defaultZoom = 0.62;

  /// 竖屏时可视区高度常 > 世界高度，固定 0.62 会把 Y clamp 成单点（只能左右拖）。
  /// 保证任一轴至少露出这么多「可拖余地」（相对世界尺寸）。
  static const double _minPanSlackFraction = 0.12;
  static const double _markerMoveSharpness = 7.2;
  static const double _followMaxSpeed = 520;

  final void Function(int entityId) onEntityTap;
  final void Function(int entityId)? onEntityLongPress;

  final Map<int, _LifeEntityMarker> _markers = {};
  final Set<String> _seenEventKeys = {};

  bool _followSelected = true;
  bool _isPanning = false;

  @override
  Color backgroundColor() => const Color(0xFFD7F0DE);

  @override
  Future<void> onLoad() async {
    await world.add(_LifeWorldGround());
    camera.viewfinder.anchor = Anchor.center;
    _applyPortraitAwareZoom();
    camera.viewfinder.position = _clampCamera(
      Vector2(worldWidth / 2, worldHeight / 2),
    );
    // Viewport HUD 层接收拖拽（屏幕坐标），见 Flame Camera 文档。
    await camera.viewport.add(_ViewportPanLayer());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _applyPortraitAwareZoom();
    camera.viewfinder.position = _clampCamera(camera.viewfinder.position);
  }

  /// 按 viewport 抬高 zoom，使宽高都留下可平移余量（竖屏常见缺口）。
  void _applyPortraitAwareZoom() {
    final view = camera.viewport.size;
    if (view.x <= 0 || view.y <= 0) {
      camera.viewfinder.zoom = _defaultZoom;
      return;
    }
    final maxVisibleW = worldWidth * (1 - _minPanSlackFraction);
    final maxVisibleH = worldHeight * (1 - _minPanSlackFraction);
    final zoomForWidth = view.x / maxVisibleW;
    final zoomForHeight = view.y / maxVisibleH;
    // 取较大者：两轴可视范围都不超过「世界 × (1-slack)」→ 都能拖。
    camera.viewfinder.zoom =
        math.max(_defaultZoom, math.max(zoomForWidth, zoomForHeight));
  }

  /// 屏幕像素位移 → 世界平移（与官方 ScaleDetector 示例同一公式）。
  void panByScreenDelta(Vector2 screenDelta) {
    if (screenDelta.x.isNaN || screenDelta.y.isNaN) return;
    if (screenDelta.x == 0 && screenDelta.y == 0) return;
    camera.stop();
    _followSelected = false;
    _isPanning = true;
    final zoom = camera.viewfinder.zoom.clamp(0.01, 10.0);
    // docs: delta = (info.delta.global..negate()) / zoom
    final worldDelta = Vector2(-screenDelta.x / zoom, -screenDelta.y / zoom);
    camera.viewfinder.position = _clampCamera(
      camera.viewfinder.position + worldDelta,
    );
  }

  void onViewportPanStart() {
    camera.stop();
    _followSelected = false;
    _isPanning = true;
  }

  void onViewportPanEnd() {
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
    _isPanning = false;
    // 官方跟随 API（平滑上限速度）
    camera.follow(marker, maxSpeed: _followMaxSpeed);
    camera.viewfinder.position = _clampCamera(camera.viewfinder.position);
  }

  /// 对焦指定居民（进世界绑定联动 / 点选）。
  void focusEntity(int entityId) {
    final marker = _markers[entityId];
    if (marker == null) return;
    for (final entry in _markers.entries) {
      entry.value
          .applyEntity(entry.value.entity, selected: entry.key == entityId);
    }
    _focusCameraOnMarker(marker);
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
        camera.follow(selected, maxSpeed: _followMaxSpeed);
        return;
      }
    }
  }

  /// 新事件 → 世界坐标上浮气泡（去重）。
  void syncRecentEvents(List<LifeEvent> events) {
    for (final event in events) {
      final text = event.desc.trim();
      if (text.isEmpty) continue;
      final key =
          '${event.entityId}|${event.timestamp.millisecondsSinceEpoch}|$text';
      if (_seenEventKeys.contains(key)) continue;
      _seenEventKeys.add(key);
      if (_seenEventKeys.length > 80) {
        _seenEventKeys.remove(_seenEventKeys.first);
      }

      var x = event.x;
      var y = event.y;
      final marker = _markers[event.entityId];
      if (marker != null) {
        x = marker.position.x;
        y = marker.position.y - 48;
      } else if (x == 0 && y == 0) {
        continue;
      }
      world.add(
        _FloatingEventBubble(
          text: text.length > 18 ? '${text.substring(0, 18)}…' : text,
          position: Vector2(x, y),
        ),
      );
    }
  }

  void notifyTap(int entityId) {
    final marker = _markers[entityId];
    if (marker != null) {
      marker.playSelectPulse();
      _focusCameraOnMarker(marker);
    }
    onEntityTap(entityId);
  }

  void notifyLongPress(int entityId) => onEntityLongPress?.call(entityId);
}

/// 挂在 camera.viewport：整屏 DragCallbacks，不拦截世界 TapCallbacks。
/// （Flame 文档：Detector 将弃用；与 TapCallbacks 混用 PanDetector 会抢手势。）
class _ViewportPanLayer extends PositionComponent
    with DragCallbacks, HasGameReference<LifeFlameGame> {
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
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.onViewportPanStart();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final delta = event.localDelta;
    if (delta.x.isNaN || delta.y.isNaN) return;
    game.panByScreenDelta(delta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.onViewportPanEnd();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    game.onViewportPanEnd();
  }

  @override
  void render(Canvas canvas) {
    // 透明接收层，不绘制。
  }
}

class _LifeWorldGround extends PositionComponent {
  _LifeWorldGround()
      : super(
          size: Vector2(LifeFlameGame.worldWidth, LifeFlameGame.worldHeight),
          position: Vector2.zero(),
          priority: -10,
        );

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final sky = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.y),
        const [
          Color(0xFFEAF6FF),
          Color(0xFFE4F6EA),
          Color(0xFFD2EBB8),
        ],
        const [0.0, 0.42, 1.0],
      );
    canvas.drawRect(rect, sky);

    // 远景丘陵
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * 0.28, size.y * 0.62),
        width: size.x * 0.55,
        height: size.y * 0.28,
      ),
      Paint()..color = const Color(0xFF8FCF7A).withValues(alpha: 0.22),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * 0.72, size.y * 0.58),
        width: size.x * 0.5,
        height: size.y * 0.26,
      ),
      Paint()..color = const Color(0xFF7BCB86).withValues(alpha: 0.2),
    );

    // 近景草地
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * 0.5, size.y * 0.82),
        width: size.x * 1.15,
        height: size.y * 0.4,
      ),
      Paint()..color = const Color(0xFF6FBF78).withValues(alpha: 0.28),
    );

    // 软路径
    final pathPaint = Paint()
      ..color = const Color(0xFFE8D5A8).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(120, size.y * 0.72)
      ..quadraticBezierTo(
        size.x * 0.45,
        size.y * 0.55,
        size.x * 0.88,
        size.y * 0.68,
      );
    canvas.drawPath(path, pathPaint);

    // 淡网格（低存在感）
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    const step = 96.0;
    for (var x = 0.0; x <= size.x; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), grid);
    }
    for (var y = 0.0; y <= size.y; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), grid);
    }

    _drawProp(canvas, const Offset(180, 160), '🌳', 44);
    _drawProp(canvas, const Offset(1080, 200), '🏡', 42);
    _drawProp(canvas, const Offset(920, 520), '🌸', 34);
    _drawProp(canvas, const Offset(260, 540), '🪨', 30);
    _drawProp(canvas, const Offset(640, 120), '☁️', 36);
    _drawProp(canvas, const Offset(520, 480), '🌿', 28);
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
          size: Vector2(92, 108),
          anchor: Anchor.center,
          position: Vector2(entity.x, entity.y),
          priority: 20,
        );

  LifeEntity entity;
  bool selected;
  double _bob = 0;
  double _selectPulse = 0;
  double _selectScale = 1;
  Vector2 _target = Vector2.zero();

  void applyEntity(LifeEntity next, {required bool selected}) {
    final wasSelected = this.selected;
    entity = next;
    this.selected = selected;
    _target = Vector2(next.x, next.y);
    if (selected && !wasSelected) playSelectPulse();
  }

  void playSelectPulse() {
    _selectPulse = 1;
    _selectScale = 1.18;
  }

  @override
  Future<void> onLoad() async {
    _target = position.clone();
  }

  @override
  void update(double dt) {
    _bob += dt * 2.6;
    final t = 1 - math.exp(-LifeFlameGame._markerMoveSharpness * dt);
    position += (_target - position) * t;

    if (_selectPulse > 0) {
      _selectPulse = (_selectPulse - dt * 1.8).clamp(0.0, 1.0);
    }
    _selectScale += (1.0 - _selectScale) * (1 - math.exp(-10 * dt));
  }

  @override
  void render(Canvas canvas) {
    final bobY = math.sin(_bob) * (selected ? 3.6 : 2.2);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + bobY);
    canvas.scale(_selectScale);

    // 地面阴影
    canvas.drawOval(
      const Rect.fromLTWH(-24, 30, 48, 14),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );

    if (selected) {
      final pulse = 0.55 + 0.45 * math.sin(_bob * 2.2);
      final ringR = 36 + (1 - _selectPulse) * 10;
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..color =
              const Color(0xFF7C75DD).withValues(alpha: 0.12 + 0.1 * pulse)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset.zero,
        34,
        Paint()
          ..color = const Color(0xFF7C75DD).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8,
      );
    }

    canvas.drawCircle(
      Offset.zero,
      29,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          29,
          [
            Colors.white,
            const Color(0xFFF3F0FF),
          ],
        ),
    );

    final emoji = TextPainter(
      text: TextSpan(
        text: entity.emoji.trim().isEmpty ? '🐣' : entity.emoji,
        style: const TextStyle(fontSize: 32),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emoji.paint(canvas, Offset(-emoji.width / 2, -emoji.height / 2 - 2));

    final name = TextPainter(
      text: TextSpan(
        text: entity.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: selected ? const Color(0xFF5B4B8A) : const Color(0xFF243447),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    name.paint(canvas, Offset(-name.width / 2, 32));

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
          center: const Offset(0, -42),
          width: bubble.width + 16,
          height: bubble.height + 10,
        ),
        const Radius.circular(11),
      );
      canvas.drawRRect(
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.94),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = const Color(0xFF7C75DD).withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      bubble.paint(canvas, Offset(-bubble.width / 2, -42 - bubble.height / 2));
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

class _FloatingEventBubble extends PositionComponent {
  _FloatingEventBubble({
    required this.text,
    required Vector2 position,
  }) : super(
          position: position.clone(),
          anchor: Anchor.center,
          priority: 40,
        );

  final String text;
  double _age = 0;
  static const double _life = 2.2;

  @override
  void update(double dt) {
    _age += dt;
    position.y -= 28 * dt;
    if (_age >= _life) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final fade = (1 - _age / _life).clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF334155).withValues(alpha: fade),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 14,
        height: tp.height + 8,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.88 * fade),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}
