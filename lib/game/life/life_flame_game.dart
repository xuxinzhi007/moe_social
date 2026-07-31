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

  final void Function(int entityId) onEntityTap;
  final void Function(int entityId)? onEntityLongPress;

  final Map<int, _LifeEntityMarker> _markers = {};
  final Set<String> _seenEventKeys = {};
  final List<_WorldLooseProp> _looseProps = [];

  bool _followSelected = true;
  bool _isPanning = false;
  int? _followedEntityId;
  double _propSpawnAcc = 0;
  static const int _maxLooseProps = 14;
  static const double _propSpawnInterval = 3.6;

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
    // 开局撒一点地上物，避免空旷。
    for (var i = 0; i < 6; i++) {
      _spawnLooseProp(force: true);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 角色 update 之后硬锁镜头：不用 camera.follow 追赶，避免移动时整屏抖动。
    _syncFollowCamera();
    _tickLoosePropSpawner(dt);
    _tickLoosePropInteractions();
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
    final halfW = view.x / (2 * zoom);
    final halfH = view.y / (2 * zoom);
    return Vector2(
      pos.x.clamp(halfW, math.max(halfW, worldWidth - halfW)),
      pos.y.clamp(halfH, math.max(halfH, worldHeight - halfH)),
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

  void _tickLoosePropSpawner(double dt) {
    _propSpawnAcc += dt;
    if (_propSpawnAcc < _propSpawnInterval) return;
    _propSpawnAcc = 0;
    _looseProps.removeWhere((p) => p.parent == null);
    if (_looseProps.length >= _maxLooseProps) return;
    _spawnLooseProp();
  }

  void _spawnLooseProp({bool force = false}) {
    if (!force && _looseProps.length >= _maxLooseProps) return;
    final rng = math.Random();
    final kindRoll = rng.nextDouble();
    final String kind;
    final String label;
    final int variant;
    final double life;
    if (kindRoll < 0.45) {
      kind = 'food';
      variant = rng.nextInt(3);
      label = const ['果子', '浆果', '胡萝卜'][variant];
      life = 22 + rng.nextDouble() * 16;
    } else if (kindRoll < 0.7) {
      kind = 'shiny';
      variant = rng.nextInt(2);
      label = const ['亮晶晶', '小花'][variant];
      life = 16 + rng.nextDouble() * 12;
    } else {
      kind = 'decor';
      variant = rng.nextInt(3);
      label = const ['落叶', '小蘑菇', '石头'][variant];
      life = 28 + rng.nextDouble() * 20;
    }
    final prop = _WorldLooseProp(
      kind: kind,
      label: label,
      variant: variant,
      maxLife: life,
      position: Vector2(
        80 + rng.nextDouble() * (worldWidth - 160),
        80 + rng.nextDouble() * (worldHeight - 160),
      ),
    );
    _looseProps.add(prop);
    world.add(prop);
  }

  /// 居民靠近地上物：食物捡起吃掉，闪光物欣赏，装饰物拨弄一下。
  void _tickLoosePropInteractions() {
    if (_looseProps.isEmpty || _markers.isEmpty) return;
    for (final marker in _markers.values) {
      if (marker.isCareBusy) continue;
      for (final prop in _looseProps) {
        if (prop.claimed || prop.parent == null) continue;
        final d = marker.position.distanceTo(prop.position);
        if (d > 46) continue;
        prop.claimed = true;
        switch (prop.kind) {
          case 'food':
            marker.playCare('feed', line: '捡到${prop.label}，真香！');
            prop.beginCollectToward(marker);
            break;
          case 'shiny':
            marker.showSpeech('哇，${prop.label}好漂亮～', duration: 1.6);
            prop.beginCollectToward(marker);
            break;
          default:
            marker.showSpeech('拨弄了一下${prop.label}', duration: 1.4);
            prop.beginFadeOut();
            break;
        }
        break;
      }
    }
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
    // 静态氛围点缀（不交互），减轻空旷感。
    _drawProp(canvas, const Offset(420, 220), '🌲', 38);
    _drawProp(canvas, const Offset(780, 180), '🌳', 36);
    _drawProp(canvas, const Offset(150, 400), '🌾', 26);
    _drawProp(canvas, const Offset(1100, 420), '🌻', 30);
    _drawProp(canvas, const Offset(600, 560), '🪴', 28);
    _drawProp(canvas, const Offset(980, 300), '☁️', 30);
    _drawProp(canvas, const Offset(340, 300), '🌺', 26);
    _drawProp(canvas, const Offset(720, 400), '🪨', 24);
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
    // 选中呼吸幅度收一点，避免跟镜头叠成「整屏在抖」。
    final bobY = math.sin(_bob) * (selected ? 2.2 : 1.6);
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

    // 喂食：食物从侧边飞到嘴边；抚摸：爱心上浮。
    if (_careT > 0 && _careAction.isNotEmpty) {
      final p = (1 - _careT / _careDuration).clamp(0.0, 1.0);
      if (_careAction == 'feed') {
        final fly = Curves.easeOut.transform(p.clamp(0.0, 1.0));
        final foodX = ui.lerpDouble(48, 10, fly)!;
        final foodY = ui.lerpDouble(-8, -6, fly)!;
        final foodScale = ui.lerpDouble(1.15, 0.55, fly)!;
        final food = TextPainter(
          text: TextSpan(
            text: '🍖',
            style: TextStyle(fontSize: 22 * foodScale),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        food.paint(
          canvas,
          Offset(foodX - food.width / 2, foodY - food.height / 2),
        );
      } else {
        for (var i = 0; i < 3; i++) {
          final t = (p + i * 0.18).clamp(0.0, 1.0);
          final heart = TextPainter(
            text: TextSpan(
              text: i.isEven ? '💕' : '✨',
              style: TextStyle(fontSize: 14 + i * 2.0),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final hx = -18.0 + i * 16;
          final hy = -20.0 - t * 36;
          canvas.save();
          canvas.translate(hx, hy);
          heart.paint(
            canvas,
            Offset(-heart.width / 2, -heart.height / 2),
          );
          canvas.restore();
        }
      }
    }

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

    // 有台词时只留气泡，避免「状态条 + 台词 + 飘字」叠在同一点。
    final speech = _speech?.trim();
    final showSpeech =
        speech != null && speech.isNotEmpty && _speechT > 0;
    if (showSpeech) {
      _paintSpeechBubble(canvas, speech, const Offset(0, -78));
    } else {
      final label = isCareBusy
          ? (_careAction == 'feed' ? '吃东西中' : '享受中')
          : entity.actionLabel.trim();
      if (label.isNotEmpty) {
        _paintStatusChip(canvas, label, const Offset(0, -42));
      }
    }

    canvas.restore();
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

/// 地上临时物：会过期消失；食物/闪光可被居民靠近捡起。
///
/// 用 Canvas 几何绘制（不用 emoji）——模拟器/部分 Android 字体缺字形会显示白块 X。
class _WorldLooseProp extends PositionComponent {
  _WorldLooseProp({
    required this.kind,
    required this.label,
    required this.variant,
    required this.maxLife,
    required Vector2 position,
  }) : life = maxLife,
       super(
         position: position.clone(),
         size: Vector2(36, 36),
         anchor: Anchor.center,
         priority: 12,
       );

  final String kind; // food | shiny | decor
  final String label;
  final int variant;
  final double maxLife;
  double life;
  bool claimed = false;
  _LifeEntityMarker? _collectTarget;
  bool _fading = false;

  void beginCollectToward(_LifeEntityMarker marker) {
    _collectTarget = marker;
  }

  void beginFadeOut() {
    _fading = true;
    life = math.min(life, 0.45);
  }

  @override
  void update(double dt) {
    if (!claimed) {
      life -= dt;
      if (life <= 0) {
        removeFromParent();
      }
      return;
    }
    final target = _collectTarget;
    if (target != null && target.parent != null) {
      final dest = target.position + Vector2(8, -6);
      final delta = dest - position;
      final dist = delta.length;
      if (dist < 8) {
        removeFromParent();
        return;
      }
      position += delta.normalized() * math.min(dist, 140 * dt);
      life -= dt;
      if (life <= 0) removeFromParent();
      return;
    }
    if (_fading) {
      life -= dt;
      if (life <= 0) removeFromParent();
    } else {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final fade = claimed
        ? 0.55
        : (life < 4 ? (life / 4).clamp(0.25, 1.0) : 1.0);
    final bob = math.sin(life * 3.2) * 1.6;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + bob);
    canvas.drawOval(
      const Rect.fromLTWH(-10, 10, 20, 7),
      Paint()..color = Colors.black.withValues(alpha: 0.12 * fade),
    );
    switch (kind) {
      case 'food':
        _paintFood(canvas, fade, variant);
        break;
      case 'shiny':
        _paintShiny(canvas, fade, variant);
        break;
      default:
        _paintDecor(canvas, fade, variant);
        break;
    }
    canvas.restore();
  }

  void _paintFood(Canvas canvas, double fade, int v) {
    final colors = const [
      Color(0xFFE85D4C),
      Color(0xFFC43B6E),
      Color(0xFFE8893A),
    ];
    final fill = colors[v % colors.length].withValues(alpha: fade);
    canvas.drawCircle(Offset.zero, 11, Paint()..color = fill);
    canvas.drawCircle(
      const Offset(-3, -3),
      3.2,
      Paint()..color = Colors.white.withValues(alpha: 0.35 * fade),
    );
    canvas.drawCircle(
      Offset.zero,
      11,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _paintShiny(Canvas canvas, double fade, int v) {
    final fill = (v.isEven ? const Color(0xFFFFC84A) : const Color(0xFF7EC8FF))
        .withValues(alpha: fade);
    final path = Path()
      ..moveTo(0, -12)
      ..lineTo(3.5, -3.5)
      ..lineTo(12, 0)
      ..lineTo(3.5, 3.5)
      ..lineTo(0, 12)
      ..lineTo(-3.5, 3.5)
      ..lineTo(-12, 0)
      ..lineTo(-3.5, -3.5)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _paintDecor(Canvas canvas, double fade, int v) {
    if (v % 3 == 0) {
      // 落叶
      final leaf = Path()
        ..moveTo(0, -10)
        ..quadraticBezierTo(12, -2, 0, 11)
        ..quadraticBezierTo(-12, -2, 0, -10)
        ..close();
      canvas.drawPath(
        leaf,
        Paint()..color = const Color(0xFFD98A3A).withValues(alpha: fade),
      );
      return;
    }
    if (v % 3 == 1) {
      // 蘑菇
      canvas.drawCircle(
        const Offset(0, -4),
        10,
        Paint()..color = const Color(0xFFE85D4C).withValues(alpha: fade),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.5, -2, 7, 12),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFF5E6D0).withValues(alpha: fade),
      );
      return;
    }
    // 石头
    final rock = Path()
      ..moveTo(-11, 4)
      ..lineTo(-6, -8)
      ..lineTo(5, -10)
      ..lineTo(11, 2)
      ..lineTo(4, 10)
      ..lineTo(-8, 9)
      ..close();
    canvas.drawPath(
      rock,
      Paint()..color = const Color(0xFF8A93A0).withValues(alpha: fade),
    );
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
