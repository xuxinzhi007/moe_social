import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/life_state.dart';

/// Flame「TA 的院子」舞台（1280×720）· v1 成品竖切。
///
/// 相机/拖拽按官方推荐：
/// - 输入用组件 [DragCallbacks]（勿混用已弃用的 [PanDetector] + TapCallbacks）
/// - 平移层挂在 [CameraComponent.viewport]（整屏可拖，不挡世界点选）
/// - 跟随：每帧硬锁 `viewfinder.position`（不用 [CameraComponent.follow] 追赶）
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

  /// 居民追目标的最大世界速度（单位/秒）。匀速滑动，避免指数吸附「窜一下再停」。
  static const double _markerMoveSpeed = 48;

  /// 院子中景（TA 常驻落脚区中心），进世界未对焦前的默认镜头。
  static final Vector2 yardFocus = Vector2(640, 430);

  final void Function(int entityId) onEntityTap;
  final void Function(int entityId)? onEntityLongPress;

  final Map<int, _LifeEntityMarker> _markers = {};
  final Set<String> _seenEventKeys = {};

  bool _followSelected = true;
  bool _isPanning = false;
  int? _followedEntityId;
  int? _boundEntityId;

  /// 跟随锚点 Y：小于 0.5 表示角色出现在屏幕偏上，躲开底栏 Care HUD。
  static const Anchor _followAnchor = Anchor(0.5, 0.34);

  @override
  Color backgroundColor() => const Color(0xFFB8D9C4);

  @override
  Future<void> onLoad() async {
    await world.add(_LifeWorldGround());
    // 角色落在屏幕偏上（约 34% 高），底栏 HUD 不再压住台词气泡。
    camera.viewfinder.anchor = _followAnchor;
    _applyPortraitAwareZoom();
    camera.viewfinder.position = _clampCamera(yardFocus.clone());
    // Viewport HUD 层接收拖拽（屏幕坐标），见 Flame Camera 文档。
    await camera.viewport.add(_ViewportPanLayer());
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 角色 update 之后硬锁镜头：不用 camera.follow 追赶，避免移动时整屏抖动。
    _syncFollowCamera();
  }

  /// 绑定伙伴 ID（世界层主角）。0 / null = 未绑定。
  void setBoundEntityId(int? entityId) {
    final next = (entityId != null && entityId > 0) ? entityId : null;
    if (_boundEntityId == next) return;
    _boundEntityId = next;
    for (final entry in _markers.entries) {
      entry.value.setBoundCompanion(entry.key == _boundEntityId);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera.viewfinder.anchor = _followAnchor;
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
    _followSelected = false;
    _followedEntityId = null;
    _isPanning = true;
    final zoom = camera.viewfinder.zoom.clamp(0.01, 10.0);
    // docs: delta = (info.delta.global..negate()) / zoom
    final worldDelta = Vector2(-screenDelta.x / zoom, -screenDelta.y / zoom);
    camera.viewfinder.position = _clampCamera(
      camera.viewfinder.position + worldDelta,
    );
  }

  void onViewportPanStart() {
    _followSelected = false;
    _followedEntityId = null;
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
    // 按实际 anchor 算可视边界（非中心锚点时 halfH 公式会偏）。
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

  /// 每帧把镜头对齐到跟随目标（硬锁 + clamp）。
  ///
  /// 不用 [CameraComponent.follow]：有限 maxSpeed 追赶会在角色匀速走时产生
  /// 「镜头慢半拍再追上」的整屏抖动，尤其竖屏 clamp 边界附近更明显。
  void _syncFollowCamera() {
    if (!_followSelected || _isPanning) return;
    final id = _followedEntityId;
    if (id == null) return;
    final marker = _markers[id];
    if (marker == null) return;
    final next = _clampCamera(marker.position);
    final cur = camera.viewfinder.position;
    // 亚像素抖动：位移极小时不改 position，避免浮点抖。
    if ((next.x - cur.x).abs() < 0.05 && (next.y - cur.y).abs() < 0.05) {
      return;
    }
    camera.viewfinder.position = next;
  }

  void _focusCameraOnMarker(_LifeEntityMarker marker, {bool force = false}) {
    _followSelected = true;
    _isPanning = false;
    if (!force && _followedEntityId == marker.entity.id) {
      _syncFollowCamera();
      return;
    }
    _followedEntityId = marker.entity.id;
    camera.viewfinder.position = _clampCamera(marker.position);
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
      final isBound = _boundEntityId != null && entity.id == _boundEntityId;
      final existing = _markers[entity.id];
      if (existing == null) {
        final marker = _LifeEntityMarker(
          entity: entity,
          selected: entity.id == selectedId,
          boundCompanion: isBound,
        );
        _markers[entity.id] = marker;
        world.add(marker);
      } else {
        existing.applyEntity(entity, selected: entity.id == selectedId);
        existing.setBoundCompanion(isBound);
      }
    }

    for (final id in _markers.keys.toList(growable: false)) {
      if (liveIds.contains(id)) continue;
      _markers[id]?.removeFromParent();
      _markers.remove(id);
    }

    if (!_followSelected || _isPanning) return;

    // 只更新跟随目标 id；镜头位置由 update → _syncFollowCamera 对齐。
    if (selectedId != null && selectedId != _followedEntityId) {
      if (_markers[selectedId] != null) {
        _followedEntityId = selectedId;
      }
    }
  }

  /// 新事件 → 世界坐标上浮气泡（去重）。
  void syncRecentEvents(List<LifeEvent> events) {
    for (final event in events) {
      final text = event.desc.trim();
      if (text.isEmpty) continue;
      // 照料已有角色气泡/演出，再飘「你喂了…」会叠字 + 晃眼。
      if (event.type == 'user_feed' || event.type == 'user_pet') continue;
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
        if (marker.isCareBusy || marker.hasSpeech) continue;
        x = marker.position.x;
        y = marker.position.y - 96;
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
      // 已选中再点：不要重绑 follow、不要选中脉冲——两者叠起来像「屏幕在震」。
      final same = _followedEntityId == entityId && _followSelected;
      if (!same) marker.playSelectPulse();
      _focusCameraOnMarker(marker);
    }
    onEntityTap(entityId);
  }

  void notifyLongPress(int entityId) => onEntityLongPress?.call(entityId);

  /// 照料演出进行中（吃东西 / 享受抚摸），此时再点应走角色回复而非系统冷却条。
  bool isCareBusy(int entityId) {
    final marker = _markers[entityId];
    return marker?.isCareBusy ?? false;
  }

  /// 成功照料：食物飞入/爱心 + 角色气泡（只在 Marker 上画，不往地上刷 prop）。
  void playCarePerformance(
    int entityId,
    String action, {
    String? line,
  }) {
    final marker = _markers[entityId];
    if (marker == null) return;
    marker.playCare(action, line: line);
  }

  /// 冷却或连点：角色用台词回应，不抛系统限制感。
  void playBusyCareReply(int entityId, String action) {
    final marker = _markers[entityId];
    if (marker == null) return;
    marker.playBusyReply(action);
  }
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

/// TA 小院子固定场景（纯 Canvas，不用 emoji / 随机刷物）。
class _LifeWorldGround extends PositionComponent {
  _LifeWorldGround()
      : super(
          size: Vector2(LifeFlameGame.worldWidth, LifeFlameGame.worldHeight),
          position: Vector2.zero(),
          priority: -10,
        );

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // 天空 → 远草
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          const [
            Color(0xFFDCEEF8),
            Color(0xFFC8E6D0),
            Color(0xFFA8D49A),
            Color(0xFF8FBF7A),
          ],
          const [0.0, 0.38, 0.62, 1.0],
        ),
    );

    // 远丘
    _hill(canvas, Offset(w * 0.22, h * 0.48), w * 0.55, h * 0.22,
        const Color(0xFF7CB86E));
    _hill(canvas, Offset(w * 0.78, h * 0.46), w * 0.5, h * 0.2,
        const Color(0xFF6FAF66));
    _hill(canvas, Offset(w * 0.5, h * 0.52), w * 0.7, h * 0.18,
        const Color(0xFF85C474));

    // 近草软带
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.78),
        width: w * 1.2,
        height: h * 0.42,
      ),
      Paint()..color = const Color(0xFF6BB06A).withValues(alpha: 0.35),
    );

    // 弧形小路（通往院子中心）
    final path = Path()
      ..moveTo(80, h * 0.78)
      ..quadraticBezierTo(w * 0.38, h * 0.58, w * 0.5, h * 0.62)
      ..quadraticBezierTo(w * 0.72, h * 0.68, w - 60, h * 0.74);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD8C09A).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 48
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFEAD8B4).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round,
    );

    // 宅前落脚垫（TA 常驻区）
    final pad = Offset(w * 0.5, h * 0.60);
    canvas.drawOval(
      Rect.fromCenter(center: pad, width: 220, height: 96),
      Paint()..color = const Color(0xFFE8D9B8).withValues(alpha: 0.55),
    );
    canvas.drawOval(
      Rect.fromCenter(center: pad, width: 168, height: 70),
      Paint()..color = const Color(0xFFF3E6C8).withValues(alpha: 0.65),
    );

    // 树丛（左 / 右 / 后）
    _treeCluster(canvas, const Offset(210, 280), 1.15);
    _treeCluster(canvas, const Offset(1040, 300), 1.05);
    _treeCluster(canvas, const Offset(420, 200), 0.85);
    _treeCluster(canvas, const Offset(860, 190), 0.8);
    _bush(canvas, const Offset(300, 480), 1.0);
    _bush(canvas, const Offset(980, 500), 1.1);
    _bush(canvas, const Offset(560, 520), 0.75);

    // 矮篱 / 木桩（院子边界感）
    _fence(canvas, Offset(w * 0.28, h * 0.55), 7);
    _fence(canvas, Offset(w * 0.68, h * 0.56), 7);

    // 小屋剪影（右后，轻存在）
    _cottage(canvas, Offset(w * 0.82, h * 0.36));

    // 轻云
    _cloud(canvas, const Offset(280, 110), 1.0);
    _cloud(canvas, const Offset(920, 90), 0.85);
  }

  void _hill(
    Canvas canvas,
    Offset c,
    double ww,
    double hh,
    Color color,
  ) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: ww, height: hh),
      Paint()..color = color.withValues(alpha: 0.45),
    );
  }

  void _treeCluster(Canvas canvas, Offset base, double s) {
    final trunk = Paint()..color = const Color(0xFF8B5E3C);
    final leaf = Paint()..color = const Color(0xFF4F9A57);
    final leafDeep = Paint()..color = const Color(0xFF3E7F48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(base.dx, base.dy + 18 * s),
          width: 10 * s,
          height: 28 * s,
        ),
        Radius.circular(3 * s),
      ),
      trunk,
    );
    canvas.drawCircle(
      Offset(base.dx - 10 * s, base.dy - 6 * s),
      22 * s,
      leafDeep,
    );
    canvas.drawCircle(
      Offset(base.dx + 12 * s, base.dy - 4 * s),
      20 * s,
      leaf,
    );
    canvas.drawCircle(
      Offset(base.dx, base.dy - 22 * s),
      24 * s,
      leaf,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy + 34 * s),
        width: 36 * s,
        height: 10 * s,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.1),
    );
  }

  void _bush(Canvas canvas, Offset c, double s) {
    final p = Paint()..color = const Color(0xFF5EAA62);
    canvas.drawCircle(Offset(c.dx - 12 * s, c.dy), 14 * s, p);
    canvas.drawCircle(Offset(c.dx + 10 * s, c.dy + 2 * s), 13 * s, p);
    canvas.drawCircle(Offset(c.dx, c.dy - 8 * s), 12 * s, p);
  }

  void _fence(Canvas canvas, Offset start, int posts) {
    final wood = Paint()..color = const Color(0xFFB8956A);
    final rail = Paint()
      ..color = const Color(0xFFC9A878)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < posts; i++) {
      final x = start.dx + i * 22;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, start.dy, 6, 28),
          const Radius.circular(2),
        ),
        wood,
      );
    }
    canvas.drawLine(
      Offset(start.dx, start.dy + 8),
      Offset(start.dx + (posts - 1) * 22 + 6, start.dy + 8),
      rail,
    );
    canvas.drawLine(
      Offset(start.dx, start.dy + 18),
      Offset(start.dx + (posts - 1) * 22 + 6, start.dy + 18),
      rail,
    );
  }

  void _cottage(Canvas canvas, Offset c) {
    final wall = Paint()..color = const Color(0xFFF2E6D4).withValues(alpha: 0.9);
    final roof = Paint()..color = const Color(0xFFD4846A).withValues(alpha: 0.92);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + 18), width: 72, height: 48),
        const Radius.circular(6),
      ),
      wall,
    );
    final roofPath = Path()
      ..moveTo(c.dx - 46, c.dy)
      ..lineTo(c.dx, c.dy - 28)
      ..lineTo(c.dx + 46, c.dy)
      ..close();
    canvas.drawPath(roofPath, roof);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + 28), width: 14, height: 22),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF8B5E3C).withValues(alpha: 0.85),
    );
  }

  void _cloud(Canvas canvas, Offset c, double s) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(Offset(c.dx - 16 * s, c.dy), 14 * s, p);
    canvas.drawCircle(Offset(c.dx + 14 * s, c.dy + 2 * s), 16 * s, p);
    canvas.drawCircle(Offset(c.dx, c.dy - 8 * s), 18 * s, p);
  }
}

class _LifeEntityMarker extends PositionComponent
    with TapCallbacks, LongPressCallbacks {
  _LifeEntityMarker({
    required this.entity,
    required this.selected,
    required bool boundCompanion,
  })  : boundCompanion = boundCompanion,
        super(
          size: Vector2(92, 108),
          anchor: Anchor.center,
          position: Vector2(entity.x, entity.y),
          priority: boundCompanion ? 28 : 18,
        );

  LifeEntity entity;
  bool selected;
  bool boundCompanion;
  double _bob = 0;
  double _selectPulse = 0;
  double _selectScale = 1;
  Vector2 _target = Vector2.zero();
  final Vector2 _velocity = Vector2.zero();

  /// feed / pet / ''
  String _careAction = '';
  double _careT = 0;
  static const double _careDuration = 2.5;
  String? _speech;
  double _speechT = 0;

  bool get isCareBusy => _careT > 0.05;

  bool get hasSpeech =>
      _speechT > 0.05 && (_speech?.trim().isNotEmpty ?? false);

  void setBoundCompanion(bool value) {
    if (boundCompanion == value) return;
    boundCompanion = value;
    priority = value ? 28 : 18;
  }

  void applyEntity(LifeEntity next, {required bool selected}) {
    final wasSelected = this.selected;
    entity = next;
    this.selected = selected;
    _target = Vector2(next.x, next.y);
    if (selected && !wasSelected) playSelectPulse();
  }

  void playSelectPulse({bool soft = false}) {
    _selectPulse = soft ? 0.35 : 0.85;
    _selectScale = soft ? 1.04 : 1.1;
  }

  void playCare(String action, {String? line}) {
    _careAction = action == 'pet' ? 'pet' : 'feed';
    _careT = _careDuration;
    _selectScale = 1.12;
    final text = (line != null && line.trim().isNotEmpty)
        ? line.trim()
        : (_careAction == 'feed' ? '好好吃！' : '最喜欢你了～');
    showSpeech(text, duration: 2.2);
  }

  void playBusyReply(String action) {
    final feedBusy = const [
      '还在嚼呢…',
      '等我吃完再喂嘛～',
      '肚子正在消化中！',
      '好吃是好吃，先缓缓～',
    ];
    final petBusy = const [
      '好舒服，再等等～',
      '蹭蹭，先抱一会儿…',
      '有点害羞啦',
      '再轻轻摸摸就好啦',
    ];
    final pool = action == 'pet' ? petBusy : feedBusy;
    final i = DateTime.now().millisecond % pool.length;
    showSpeech(pool[i], duration: 1.8);
    // 连点时给一点轻反馈，不重开完整进食。
    if (_careT < 0.4) {
      _careAction = action == 'pet' ? 'pet' : 'feed';
      _careT = math.max(_careT, 0.9);
    }
  }

  void showSpeech(String text, {double duration = 2.0}) {
    _speech = text;
    _speechT = duration;
  }

  @override
  Future<void> onLoad() async {
    _target = position.clone();
  }

  @override
  void update(double dt) {
    final careBoost = isCareBusy ? 1.8 : 1.0;
    _bob += dt * 2.6 * careBoost;
    _stepTowardTarget(dt);

    if (_selectPulse > 0) {
      _selectPulse = (_selectPulse - dt * 1.8).clamp(0.0, 1.0);
    }
    _selectScale += (1.0 - _selectScale) * (1 - math.exp(-10 * dt));

    if (_careT > 0) {
      _careT = (_careT - dt).clamp(0.0, _careDuration);
      if (_careT <= 0) _careAction = '';
    }
    if (_speechT > 0) {
      _speechT = (_speechT - dt).clamp(0.0, 8.0);
      if (_speechT <= 0) _speech = null;
    }
  }

  /// 匀速靠近服务端坐标；抵达后轻微停稳，观感像 NPC 走路而非瞬移吸附。
  void _stepTowardTarget(double dt) {
    if (dt <= 0) return;
    final delta = _target - position;
    final dist = delta.length;
    if (dist < 0.4) {
      position.setFrom(_target);
      _velocity.setZero();
      return;
    }
    final maxStep = LifeFlameGame._markerMoveSpeed * dt;
    if (dist <= maxStep) {
      position.setFrom(_target);
      _velocity.setZero();
      return;
    }
    final dir = delta / dist;
    _velocity.setFrom(dir * LifeFlameGame._markerMoveSpeed);
    position += _velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    // 非绑定居民弱化；绑定 TA 为视觉主角。
    final presence = boundCompanion ? 1.0 : 0.52;
    final bodyScale = boundCompanion ? 1.0 : 0.78;
    final bobY = math.sin(_bob) * (selected ? 2.0 : 1.4) * bodyScale;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + bobY);
    canvas.scale(_selectScale * bodyScale);
    // 必须盖住台词气泡区域；半径 80 会把气泡裁成「一条线 + 小三角」。
    final dimLayer = presence < 0.99;
    if (dimLayer) {
      canvas.saveLayer(
        const Rect.fromLTWH(-130, -170, 260, 260),
        Paint()..color = Colors.white.withValues(alpha: presence),
      );
    }

    // 地面阴影
    canvas.drawOval(
      const Rect.fromLTWH(-24, 30, 48, 14),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );

    // 绑定 TA：轻伴侣光晕（未选中也有存在感）
    if (boundCompanion && !selected) {
      canvas.drawCircle(
        Offset.zero,
        38,
        Paint()
          ..color = const Color(0xFFE97891).withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
    }

    if (selected) {
      final pulse = 0.55 + 0.45 * math.sin(_bob * 2.2);
      final ringR = 36 + (1 - _selectPulse) * 10;
      final ringColor =
          boundCompanion ? const Color(0xFFE97891) : const Color(0xFF7C75DD);
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..color = ringColor.withValues(alpha: 0.12 + 0.1 * pulse)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset.zero,
        34,
        Paint()
          ..color = ringColor.withValues(alpha: 0.9)
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
            boundCompanion
                ? const Color(0xFFFFF0F3)
                : const Color(0xFFF3F0FF),
          ],
        ),
    );

    final emoji = TextPainter(
      text: TextSpan(
        text: entity.emoji.trim().isEmpty ? '🐣' : entity.emoji,
        style: TextStyle(fontSize: boundCompanion ? 34 : 28),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emoji.paint(canvas, Offset(-emoji.width / 2, -emoji.height / 2 - 2));

    // 喂食/陪伴：只在 Marker 上用 Canvas 几何演出（不用 emoji，避免缺字/旁侧色块）。
    if (_careT > 0 && _careAction.isNotEmpty) {
      final p = (1 - _careT / _careDuration).clamp(0.0, 1.0);
      if (_careAction == 'feed') {
        final fly = Curves.easeOut.transform(p);
        final foodX = ui.lerpDouble(46, 12, fly)!;
        final foodY = ui.lerpDouble(-10, -4, fly)!;
        final foodScale = ui.lerpDouble(1.1, 0.55, fly)!;
        canvas.save();
        canvas.translate(foodX, foodY);
        canvas.scale(foodScale);
        _paintCareFood(canvas);
        canvas.restore();
      } else {
        for (var i = 0; i < 3; i++) {
          final t = (p + i * 0.18).clamp(0.0, 1.0);
          final hx = -18.0 + i * 16;
          final hy = -20.0 - t * 36;
          canvas.save();
          canvas.translate(hx, hy);
          canvas.scale(0.7 + i * 0.12);
          _paintCareHeart(canvas, alpha: (1 - t * 0.35).clamp(0.35, 1.0));
          canvas.restore();
        }
      }
    }

    final name = TextPainter(
      text: TextSpan(
        text: boundCompanion ? '${entity.name} · TA' : entity.name,
        style: TextStyle(
          fontSize: boundCompanion ? 12.5 : 11,
          fontWeight: FontWeight.w800,
          color: selected
              ? (boundCompanion
                  ? const Color(0xFFB54B66)
                  : const Color(0xFF5B4B8A))
              : const Color(0xFF243447).withValues(alpha: presence),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    name.paint(canvas, Offset(-name.width / 2, 32));

    // 有台词时只留气泡，避免「状态条 + 台词 + 飘字」叠在同一点。
    final speech = _speech?.trim();
    final showSpeech =
        speech != null && speech.isNotEmpty && _speechT > 0;
    if (showSpeech) {
      _paintSpeechBubble(canvas, speech, const Offset(0, -86));
    } else if (boundCompanion || selected) {
      final label = isCareBusy
          ? (_careAction == 'feed' ? '吃东西中' : '享受中')
          : entity.actionLabel.trim();
      if (label.isNotEmpty) {
        _paintStatusChip(canvas, label, const Offset(0, -48));
      }
    }

    if (dimLayer) {
      canvas.restore(); // saveLayer
    }
    canvas.restore();
  }

  void _paintCareFood(Canvas canvas) {
    canvas.drawCircle(
      Offset.zero,
      10,
      Paint()..color = const Color(0xFFE8893A),
    );
    canvas.drawCircle(
      const Offset(-3, -3),
      2.8,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
    canvas.drawCircle(
      Offset.zero,
      10,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _paintCareHeart(Canvas canvas, {required double alpha}) {
    final paint = Paint()
      ..color = const Color(0xFFE97891).withValues(alpha: alpha);
    final path = Path()
      ..moveTo(0, 6)
      ..cubicTo(-10, -2, -8, -12, 0, -6)
      ..cubicTo(8, -12, 10, -2, 0, 6)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintStatusChip(Canvas canvas, String text, Offset center) {
    final bubble = TextPainter(
      text: TextSpan(
        text: text,
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
        center: center,
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
    bubble.paint(
      canvas,
      Offset(center.dx - bubble.width / 2, center.dy - bubble.height / 2),
    );
  }

  void _paintSpeechBubble(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3D342E),
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 140);
    final w = painter.width + 18;
    final h = painter.height + 14;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: h),
      const Radius.circular(14),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFFFDF8F0));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFFE8D5B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // 小三角指向角色
    final tip = Path()
      ..moveTo(center.dx - 6, center.dy + h / 2 - 1)
      ..lineTo(center.dx, center.dy + h / 2 + 7)
      ..lineTo(center.dx + 6, center.dy + h / 2 - 1)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFFFDF8F0));
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
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
