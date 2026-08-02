import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/pet_crop.dart';
import '../../models/pet_state.dart';
import 'pet_art.dart';
import 'pet_avatar_backend.dart';
import 'pet_avatar_stack.dart';
import 'pet_content_catalog.dart';
import 'pet_sheet_avatar.dart';
import 'pet_lpc_sheet.dart';

enum PetCarePerformance { feed, care, sleep }

/// 养成小家 Room：固定竖屏舞台；布置模式拖家具/旋转；角色可缩小拖动。
class PetRoomGame extends FlameGame {
  PetRoomGame({
    this.onFurnitureMoved,
    this.onFurnitureSelected,
    this.onActorMoved,
    this.onRoomBoundariesChanged,
    this.onFurnitureInteracted,
    this.onCropTapped,
  });

  static const double worldWidth = 720;
  static const double worldHeight = 1280;

  final void Function(
    int index,
    double x,
    double y,
    int rotation,
    double scale,
  )? onFurnitureMoved;
  final void Function(int index)? onFurnitureSelected;
  final void Function(double x, double y)? onActorMoved;
  final void Function(List<PetRoomBoundary> boundaries)?
      onRoomBoundariesChanged;

  /// 非布置模式点家具互动（如点床去睡觉）。不依赖 LLM。
  final void Function(String furnitureId)? onFurnitureInteracted;

  /// 院子菜地点击：空地种植 / 生长中浇水 / 成熟收获。
  final void Function(int plotIndex, PetCropSlot slot)? onCropTapped;

  PetProfile _profile = PetProfile.fresh();
  List<PetCropSlot> _crops = PetCropSlot.freshPlots();
  String? _fxLabel;
  double _fxT = 0;
  bool decorateMode = false;
  int? selectedFurnitureIndex;

  _RoomBackdrop? _backdrop;
  _PetActor? _actor;
  final Map<int, _FurniturePiece> _pieces = {};
  _RoomBoundaryLayer? _boundaryLayer;
  _FarmLayer? _farmLayer;
  Future<void>? _furnitureSyncInFlight;
  var _furnitureSyncQueued = false;

  void syncProfile(PetProfile profile) {
    final prev = _profile;
    final sceneChanged = profile.sceneId != prev.sceneId;
    final furnitureChanged = sceneChanged ||
        !_sameFurnitureLayout(prev.furniture, profile.furniture);
    final boundsChanged = sceneChanged ||
        !_sameBoundaryLayout(prev.roomBoundaries, profile.roomBoundaries);
    _profile = profile;
    _backdrop?.apply(profile);
    // 走路/睡觉演出中勿把角色拽回旧坐标。
    final busy = _actor?.isBusyAction == true;
    _actor?.apply(profile, forcePosition: !_actorDragging && !busy);
    // 仅饥饿/心情变化时不要拆家具重挂，避免「喂一下像整页重载」。
    if (furnitureChanged) {
      _syncFurniture();
    }
    if (boundsChanged) {
      _boundaryLayer?.apply(
        profile.roomBoundaries,
        profile.sceneId,
        decorateMode,
      );
    }
    _farmLayer?.apply(
      crops: _crops,
      sceneId: profile.sceneId,
      decorateMode: decorateMode,
    );
  }

  static bool _sameFurnitureLayout(List<PetFurniture> a, List<PetFurniture> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.scene != y.scene ||
          x.rotation != y.rotation ||
          (x.x - y.x).abs() > 0.0001 ||
          (x.y - y.y).abs() > 0.0001 ||
          (x.scale - y.scale).abs() > 0.0001) {
        return false;
      }
    }
    return true;
  }

  static bool _sameBoundaryLayout(
    List<PetRoomBoundary> a,
    List<PetRoomBoundary> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.scene != y.scene ||
          (x.x - y.x).abs() > 0.0001 ||
          (x.y - y.y).abs() > 0.0001 ||
          (x.width - y.width).abs() > 0.0001 ||
          (x.height - y.height).abs() > 0.0001) {
        return false;
      }
    }
    return true;
  }

  void syncCrops(List<PetCropSlot> crops) {
    _crops = List.of(crops);
    _farmLayer?.apply(
      crops: _crops,
      sceneId: _profile.sceneId,
      decorateMode: decorateMode,
    );
  }

  bool get _actorDragging => _actor?.dragging == true;

  void setDecorateMode(bool enabled) {
    decorateMode = enabled;
    if (!enabled) selectedFurnitureIndex = null;
    _actor?.decorateMode = enabled;
    for (final p in _pieces.values) {
      p.decorateMode = enabled;
      p.selected = selectedFurnitureIndex == p.listIndex;
    }
    _boundaryLayer?.setDecorateMode(enabled);
    _farmLayer?.apply(
      crops: _crops,
      sceneId: _profile.sceneId,
      decorateMode: enabled,
    );
  }

  void selectFurniture(int? index) {
    selectedFurnitureIndex = index;
    for (final p in _pieces.values) {
      p.selected = index == p.listIndex;
    }
    if (index != null) onFurnitureSelected?.call(index);
  }

  void nudgeSelected(double dx, double dy) {
    final i = selectedFurnitureIndex;
    if (i == null) return;
    final piece = _pieces[i];
    if (piece == null) return;
    piece.nudgeNormalized(dx, dy);
    piece.emitMoved();
  }

  void rotateSelected() {
    final i = selectedFurnitureIndex;
    if (i == null) return;
    final piece = _pieces[i];
    if (piece == null) return;
    piece.rotate90();
    piece.emitMoved();
  }

  void scaleSelected(double delta) {
    final i = selectedFurnitureIndex;
    if (i == null) return;
    final piece = _pieces[i];
    if (piece == null) return;
    piece.nudgeScale(delta);
    piece.emitMoved();
  }

  /// 布置滑条：只改舞台尺寸，不立刻 notify（由页面 onChangeEnd 落库）。
  void scaleSelectedTo(double scale) {
    final i = selectedFurnitureIndex;
    if (i == null) return;
    final piece = _pieces[i];
    if (piece == null) return;
    piece.setScale(scale);
  }

  void playCareFx(String label) {
    _fxLabel = label;
    _fxT = 1.2;
  }

  void playCarePerformance({
    required PetCarePerformance kind,
    required String itemEmoji,
    required String dialogue,
  }) {
    _actor?.performCare(
      kind: kind,
      itemEmoji: itemEmoji,
      dialogue: dialogue,
    );
  }

  void setActorMoveInput(double x, double y) {
    _actor?.setMoveInput(Vector2(x, y));
  }

  void stopActorMoveInput() {
    _actor?.setMoveInput(Vector2.zero());
  }

  /// 点地面走路（替代摇杆）。
  void walkActorToNormalized(double nx, double ny) {
    if (decorateMode) return;
    _actor?.walkToNormalized(nx, ny);
  }

  /// 非布置模式：点家具 → 走过去并演出（床=睡觉）。纯规则，不需要模型。
  void interactWithFurniture(int index) {
    if (decorateMode) return;
    final piece = _pieces[index];
    if (piece == null) return;
    final id = piece.itemId;
    // 站在家具略下方，避免完全重叠遮住床铺。
    final standY = (piece.normY + 0.07).clamp(0.35, 0.88);
    _actor?.walkToNormalized(
      piece.normX,
      standY,
      onArrive: () {
        onFurnitureInteracted?.call(id);
        if (id.startsWith('bed')) {
          playCarePerformance(
            kind: PetCarePerformance.sleep,
            itemEmoji: '💤',
            dialogue: '晚安～去床上睡一会儿…',
          );
        } else if (id.startsWith('table')) {
          playCarePerformance(
            kind: PetCarePerformance.care,
            itemEmoji: '🪑',
            dialogue: '在桌边坐一会儿～',
          );
        } else if (id.startsWith('lamp')) {
          playCarePerformance(
            kind: PetCarePerformance.care,
            itemEmoji: '💡',
            dialogue: '灯光暖暖的，好舒服',
          );
        } else if (id.startsWith('rug')) {
          playCarePerformance(
            kind: PetCarePerformance.care,
            itemEmoji: '🧸',
            dialogue: '地毯好软呀',
          );
        } else {
          playCarePerformance(
            kind: PetCarePerformance.care,
            itemEmoji: '✨',
            dialogue: '看看这个…',
          );
        }
      },
    );
  }

  @override
  Color backgroundColor() => const Color(0xFFF3E7D8);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(worldWidth / 2, worldHeight / 2);
    _fitZoom();
    _backdrop = _RoomBackdrop();
    _actor = _PetActor(
      onMoved: (x, y) => onActorMoved?.call(x, y),
    );
    _boundaryLayer = _RoomBoundaryLayer(
      onChanged: (boundaries) => onRoomBoundariesChanged?.call(boundaries),
    );
    _farmLayer = _FarmLayer(
      onPlotTapped: (index, slot) => onCropTapped?.call(index, slot),
    );
    await world.add(_backdrop!);
    await world.add(_boundaryLayer!);
    await world.add(_farmLayer!);
    await world.add(_actor!);
    syncProfile(_profile);
    syncCrops(_crops);
  }

  void addRoomBoundary() {
    final next = [..._profile.roomBoundaries];
    next.add(PetRoomBoundary(
      id: 'wall_${DateTime.now().microsecondsSinceEpoch}',
      scene: _profile.sceneId,
      x: .5,
      y: .5,
      width: .24,
      height: .06,
    ));
    _boundaryLayer?.apply(next, _profile.sceneId, true);
    onRoomBoundariesChanged?.call(next);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fitZoom();
    camera.viewfinder.position = Vector2(worldWidth / 2, worldHeight / 2);
  }

  void _fitZoom() {
    final view = camera.viewport.size;
    if (view.x <= 0 || view.y <= 0) {
      camera.viewfinder.zoom = 1;
      return;
    }
    final zx = view.x / worldWidth;
    final zy = view.y / worldHeight;
    camera.viewfinder.zoom = zx > zy ? zx : zy;
  }

  Future<void> _syncFurniture() async {
    // 并发 sync 会把旧 piece 加回 world 却不进 _pieces，表现为「拖一下无限复制」。
    if (_furnitureSyncInFlight != null) {
      _furnitureSyncQueued = true;
      return _furnitureSyncInFlight!;
    }
    final run = _syncFurnitureBody();
    _furnitureSyncInFlight = run;
    try {
      await run;
    } finally {
      _furnitureSyncInFlight = null;
      if (_furnitureSyncQueued) {
        _furnitureSyncQueued = false;
        await _syncFurniture();
      }
    }
  }

  Future<void> _syncFurnitureBody() async {
    if (_pieces.values.any((p) => p.dragging)) return;
    final scene = _profile.sceneId;
    final desired = <int, PetFurniture>{};
    for (var i = 0; i < _profile.furniture.length; i++) {
      final f = _profile.furniture[i];
      if (f.scene != scene) continue;
      if (!PetContentCatalog.furnitureAllowedInScene(f.id, scene)) continue;
      desired[i] = f;
    }

    // 同批家具仅坐标/缩放变化：原地更新，避免拆掉重载图片（拖一下像整页刷新）。
    final sameSet = desired.length == _pieces.length &&
        desired.keys.every(_pieces.containsKey) &&
        desired.entries.every((e) => _pieces[e.key]?.itemId == e.value.id);
    if (sameSet) {
      for (final e in desired.entries) {
        _pieces[e.key]!.applyLayout(
          e.value,
          decorateMode: decorateMode,
          selected: selectedFurnitureIndex == e.key,
        );
      }
      _actor?.priority = 20;
      return;
    }

    final stale = List<_FurniturePiece>.from(_pieces.values);
    _pieces.clear();
    for (final p in stale) {
      p.removeFromParent();
    }
    for (final e in desired.entries) {
      final piece = _FurniturePiece(
        listIndex: e.key,
        item: e.value,
        decorateMode: decorateMode,
        selected: selectedFurnitureIndex == e.key,
      );
      piece.priority = 10;
      _pieces[e.key] = piece;
      await world.add(piece);
    }
    _actor?.priority = 20;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_fxT > 0) {
      _fxT -= dt;
      if (_fxT <= 0) _fxLabel = null;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final label = _fxLabel;
    if (label == null || _fxT <= 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFE97891).withValues(alpha: _fxT.clamp(0, 1)),
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final view = camera.viewport.size;
    tp.paint(canvas, Offset((view.x - tp.width) / 2, view.y * 0.28));
  }
}

class _RoomBackdrop extends PositionComponent
    with TapCallbacks, HasGameReference<PetRoomGame> {
  PetProfile _profile = PetProfile.fresh();
  ui.Image? _bgImage;
  String _sceneId = 'living';
  int _bgGen = 0;
  Vector2? _tapMark;
  double _tapMarkT = 0;

  void apply(PetProfile profile) {
    final sceneChanged = profile.sceneId != _sceneId;
    _profile = profile;
    if (!sceneChanged) return;
    _sceneId = profile.sceneId;
    // 先清掉旧图，立刻露出场景色；再异步加载新背景，避免「切了标签画面不变」。
    _bgImage = null;
    unawaited(_loadBg());
  }

  Future<void> _loadBg() async {
    final gen = ++_bgGen;
    final scene = _sceneId;
    final img = await PetArt.loadImage(PetArt.roomBg(scene));
    if (gen != _bgGen) return;
    _bgImage = img;
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(PetRoomGame.worldWidth, PetRoomGame.worldHeight);
    priority = 0;
    _sceneId = _profile.sceneId;
    await _loadBg();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.decorateMode) return;
    final nx = (event.localPosition.x / size.x).clamp(0.12, 0.88);
    final ny = (event.localPosition.y / size.y).clamp(0.35, 0.88);
    _tapMark = Vector2(nx * size.x, ny * size.y);
    _tapMarkT = 0.55;
    game.walkActorToNormalized(nx, ny);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_tapMarkT > 0) {
      _tapMarkT = math.max(0, _tapMarkT - dt);
      if (_tapMarkT == 0) _tapMark = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final bg = _bgImage;
    if (bg != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, w, h),
        image: bg,
        fit: BoxFit.cover,
      );
    } else {
      final colors = switch (_profile.sceneId) {
        'yard' => const [Color(0xFFB8D9C4), Color(0xFFE8F5E9)],
        'bedroom' => const [Color(0xFFD4C4E8), Color(0xFFF8F0FF)],
        _ => const [Color(0xFFFFE0C2), Color(0xFFFFF6EE)],
      };
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), colors),
      );
    }
    final mark = _tapMark;
    if (mark != null && _tapMarkT > 0) {
      final t = (_tapMarkT / 0.55).clamp(0.0, 1.0);
      final r = 10 + 16 * (1 - t);
      canvas.drawCircle(
        Offset(mark.x, mark.y),
        r,
        Paint()
          ..color = const Color(0xFFE97891).withValues(alpha: 0.55 * t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        Offset(mark.x, mark.y),
        5,
        Paint()..color = const Color(0xFFE97891).withValues(alpha: 0.35 * t),
      );
    }
  }
}

class _PetActor extends PositionComponent
    with DragCallbacks, HasGameReference<PetRoomGame> {
  _PetActor({required this.onMoved});

  static const double pngW = 200;
  static const double pngH = 268;
  static const double lpcSize = 112;
  static const double _walkSpeed = 90;
  static const double _animFps = 9;

  final void Function(double x, double y) onMoved;
  final math.Random _rng = math.Random();

  PetProfile _profile = PetProfile.fresh();
  PetAvatarStack? _stack;
  PetLpcSheet? _lpc;
  String _wearKey = '';
  bool decorateMode = false;
  bool dragging = false;
  bool _placed = false;

  /// 移动目标（世界坐标）；null = 站立。含闲逛与「点家具走过去」。
  Vector2? _wanderTarget;
  void Function()? _arriveCallback;
  bool _intentWalk = false;
  double _idleWait = 0.8;
  double _animT = 0;
  int _frame = 0;
  int _dir = 2; // down
  bool _moving = false;
  Vector2 _moveInput = Vector2.zero();
  PetCarePerformance? _carePerformance;
  String _careEmoji = '';
  String _careDialogue = '';
  double _careT = 0;

  void performCare({
    required PetCarePerformance kind,
    required String itemEmoji,
    required String dialogue,
  }) {
    _carePerformance = kind;
    _careEmoji = itemEmoji;
    _careDialogue = dialogue;
    _careT = kind == PetCarePerformance.sleep ? 2.6 : 1.8;
    _wanderTarget = null;
    _arriveCallback = null;
    _intentWalk = false;
  }

  void setMoveInput(Vector2 input) {
    final wasMoving = _moveInput.length2 > 0.0001;
    _moveInput = input.length2 > 1 ? input.normalized() : input;
    if (_moveInput.length2 > 0.0001) {
      _wanderTarget = null;
      _arriveCallback = null;
      _intentWalk = false;
      _idleWait = 1.0;
    } else if (wasMoving) {
      onMoved(normX, normY);
    }
  }

  /// 走到归一化坐标；到达后回调（点床睡觉等，不需要模型）。
  void walkToNormalized(
    double nx,
    double ny, {
    void Function()? onArrive,
  }) {
    _moveInput = Vector2.zero();
    _intentWalk = true;
    _arriveCallback = onArrive;
    _wanderTarget = Vector2(
      nx.clamp(0.12, 0.88) * PetRoomGame.worldWidth,
      ny.clamp(0.35, 0.88) * PetRoomGame.worldHeight,
    );
    _idleWait = 9999;
    _frame = 0;
  }

  /// 走路目标中 / 照料演出中：外部 sync 不要硬拽坐标。
  bool get isBusyAction =>
      _intentWalk ||
      _wanderTarget != null && _arriveCallback != null ||
      _careT > 0;

  bool get _useSheet {
    final b = resolvePetAvatarBackend();
    return b == PetAvatarBackend.lpc || b == PetAvatarBackend.moe;
  }

  double get normX => (position.x / PetRoomGame.worldWidth).clamp(0.12, 0.88);
  double get normY => (position.y / PetRoomGame.worldHeight).clamp(0.35, 0.88);

  void apply(PetProfile profile, {bool forcePosition = true}) {
    _profile = profile;
    if (!dragging) {
      if (!_placed) {
        _placeFromNorm(profile.actorX, profile.actorY);
        _placed = true;
      } else if (!_useSheet && forcePosition) {
        // PNG 模式：跟随存档坐标；LPC 闲逛中勿每帧拽回。
        _placeFromNorm(profile.actorX, profile.actorY);
      }
    }
    _load();
  }

  void _placeFromNorm(double nx, double ny) {
    position = Vector2(
      nx.clamp(0.12, 0.88) * PetRoomGame.worldWidth,
      ny.clamp(0.35, 0.88) * PetRoomGame.worldHeight,
    );
  }

  bool _canOccupy(Vector2 candidate) {
    final radius = _useSheet ? lpcSize * .2 : pngW * .12;
    for (final boundary in _profile.roomBoundaries) {
      if (boundary.scene != _profile.sceneId) continue;
      final rect = Rect.fromCenter(
        center: Offset(
          boundary.x * PetRoomGame.worldWidth,
          boundary.y * PetRoomGame.worldHeight,
        ),
        width: boundary.width * PetRoomGame.worldWidth + radius * 2,
        height: boundary.height * PetRoomGame.worldHeight + radius * 2,
      );
      if (rect.contains(Offset(candidate.x, candidate.y))) return false;
    }
    return true;
  }

  void _moveWithinRoom(Vector2 delta) {
    final horizontal = Vector2(position.x + delta.x, position.y);
    if (_canOccupy(horizontal)) position.x = horizontal.x;
    final vertical = Vector2(position.x, position.y + delta.y);
    if (_canOccupy(vertical)) position.y = vertical.y;
    _placeFromNorm(normX, normY);
  }

  Future<void> _load() async {
    // LPC/Moe sheet：合成失败必须回落 Paper PNG，禁止长期蓝块占位。
    final key =
        '${_profile.hatId}|${_profile.topId}|${_profile.bottomId}|${_profile.shoesId}';
    if (_useSheet) {
      if (key == _wearKey && (_lpc != null || _stack != null)) return;
      _wearKey = key;
      _lpc = await PetSheetAvatar.composeOutfit(
        hatId: _profile.hatId,
        topId: _profile.topId,
        bottomId: _profile.bottomId,
        shoesId: _profile.shoesId,
      );
      if (_lpc != null) {
        size = Vector2(lpcSize, lpcSize);
        _stack = null;
        return;
      }
      // sheet 失败 → Paper
    }
    size = Vector2(pngW, pngH);
    _lpc = null;
    if (key == _wearKey && _stack != null && !_useSheet) return;
    _stack = await PetAvatarStack.compose(
      hatId: _profile.hatId,
      topId: _profile.topId,
      bottomId: _profile.bottomId,
      shoesId: _profile.shoesId,
    );
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(_useSheet ? lpcSize : pngW, _useSheet ? lpcSize : pngH);
    anchor = Anchor.center;
    priority = 20;
    _placeFromNorm(_profile.actorX, _profile.actorY);
    _placed = true;
    await _load();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_careT > 0) {
      _careT = math.max(0, _careT - dt);
      if (_careT == 0) _carePerformance = null;
    }
    if (decorateMode || dragging) {
      _moving = false;
      return;
    }

    if (_moveInput.length2 > 0.0001) {
      final delta = _moveInput.normalized() * (_walkSpeed * 1.35 * dt);
      _moveWithinRoom(delta);
      _dir = PetLpcSheet.dirFromVelocity(delta.x, delta.y);
      _moving = true;
    } else if (_wanderTarget != null) {
      final to = _wanderTarget! - position;
      final dist = to.length;
      if (dist < 8) {
        final cb = _arriveCallback;
        _arriveCallback = null;
        final wasIntent = _intentWalk;
        _intentWalk = false;
        _wanderTarget = null;
        _idleWait = wasIntent ? 2.4 : 1.2 + _rng.nextDouble() * 2.4;
        _moving = false;
        onMoved(normX, normY);
        cb?.call();
      } else {
        final speed = _walkSpeed * (_intentWalk ? 1.25 : 1.0);
        final step = math.min(speed * dt, dist);
        final delta = to.normalized() * step;
        _moveWithinRoom(delta);
        _dir = PetLpcSheet.dirFromVelocity(delta.x, delta.y);
        _moving = true;
      }
    } else if (!_useSheet || _lpc == null) {
      _moving = false;
      return;
    } else {
      _idleWait -= dt;
      _moving = false;
      if (_idleWait <= 0) {
        _pickWanderTarget();
      }
    }

    _animT += dt;
    final step = 1 / _animFps;
    while (_animT >= step) {
      _animT -= step;
      final cols = _moving ? PetLpcSheet.walkCols : PetLpcSheet.idleCols;
      _frame = (_frame + 1) % cols;
    }
  }

  void _pickWanderTarget() {
    final nx = 0.18 + _rng.nextDouble() * 0.64;
    final ny = 0.42 + _rng.nextDouble() * 0.40;
    _intentWalk = false;
    _arriveCallback = null;
    _wanderTarget = Vector2(
      nx * PetRoomGame.worldWidth,
      ny * PetRoomGame.worldHeight,
    );
    _frame = 0;
  }

  @override
  void render(Canvas canvas) {
    final careSpan = _carePerformance == PetCarePerformance.sleep ? 2.6 : 1.8;
    final careProgress = (1 - _careT / careSpan).clamp(0.0, 1.0);
    final isEating = _carePerformance == PetCarePerformance.feed;
    final isSleeping = _carePerformance == PetCarePerformance.sleep;
    final bob = _careT > 0 && !isSleeping
        ? math.sin(careProgress * math.pi * 4) * 5
        : 0.0;
    canvas.save();
    // 睡觉时略微躺下（压扁 + 下沉），不需要额外骨骼动画。
    if (isSleeping) {
      canvas.translate(size.x * 0.1, size.y * 0.18);
      canvas.rotate(-0.55);
      canvas.scale(1.05, 0.72);
    }
    canvas.translate(0, bob);
    final sheet = _lpc;
    if (sheet != null) {
      sheet.paint(
        canvas,
        Size(size.x, size.y),
        dir: _dir,
        moving: _moving,
        frame: _frame,
      );
    } else {
      final stack = _stack;
      if (stack != null) {
        stack.paint(
          canvas,
          Size(size.x, size.y),
          _profile.wearLayout,
        );
      } else {
        // 仅真正无资源时用粉色椭圆；禁止蓝色方块占位。
        canvas.drawOval(
          Rect.fromLTWH(0, 0, size.x, size.y).deflate(10),
          Paint()..color = const Color(0xFFFFB7C5),
        );
      }
    }
    final name = TextPainter(
      text: TextSpan(
        text: _profile.name,
        style: const TextStyle(
          color: Color(0xFF5A4638),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    name.paint(canvas, Offset((size.x - name.width) / 2, size.y - 2));
    canvas.restore();

    if (_careT <= 0) return;
    if (isEating) {
      final food = TextPainter(
        text: TextSpan(text: _careEmoji, style: const TextStyle(fontSize: 28)),
        textDirection: TextDirection.ltr,
      )..layout();
      final fromX = size.x + 16;
      final toX = size.x * 0.58;
      food.paint(
        canvas,
        Offset(fromX + (toX - fromX) * careProgress, size.y * 0.34),
      );
    } else if (isSleeping) {
      final zzz = TextPainter(
        text: TextSpan(
          text: _careEmoji,
          style: TextStyle(
            fontSize: 22 + 6 * math.sin(careProgress * math.pi * 2),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      zzz.paint(canvas, Offset(size.x * 0.72, -18 - 10 * careProgress));
    }
    _paintSpeechBubble(canvas);
  }

  void _paintSpeechBubble(Canvas canvas) {
    final bubble = TextPainter(
      text: TextSpan(
        text: _careDialogue,
        style: const TextStyle(
          color: Color(0xFF5A4638),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 170);
    final rect = Rect.fromLTWH(
      (size.x - bubble.width) / 2 - 11,
      -bubble.height - 42,
      bubble.width + 22,
      bubble.height + 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );
    final tail = Path()
      ..moveTo(size.x * 0.48, rect.bottom)
      ..lineTo(size.x * 0.58, rect.bottom)
      ..lineTo(size.x * 0.53, rect.bottom + 9)
      ..close();
    canvas.drawPath(
        tail, Paint()..color = Colors.white.withValues(alpha: 0.94));
    bubble.paint(canvas, Offset(rect.left + 11, rect.top + 8));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (decorateMode) {
      event.continuePropagation = true;
      return;
    }
    dragging = true;
    _wanderTarget = null;
    _moving = false;
    priority = 40;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (decorateMode || !dragging) return;
    _moveWithinRoom(event.localDelta);
    final d = event.localDelta;
    if (d.x.abs() + d.y.abs() > 0.5) {
      _dir = PetLpcSheet.dirFromVelocity(d.x, d.y);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!dragging) return;
    dragging = false;
    priority = 20;
    _idleWait = 0.6 + _rng.nextDouble();
    onMoved(normX, normY);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    dragging = false;
    priority = 20;
  }
}

class _RoomBoundaryLayer extends PositionComponent
    with HasGameReference<PetRoomGame> {
  _RoomBoundaryLayer({required this.onChanged});

  final void Function(List<PetRoomBoundary> boundaries) onChanged;
  List<PetRoomBoundary> _boundaries = const [];
  String _scene = 'living';
  bool _decorateMode = false;
  final List<_RoomBoundaryPiece> _pieces = [];

  @override
  Future<void> onLoad() async {
    size = Vector2(PetRoomGame.worldWidth, PetRoomGame.worldHeight);
    priority = 25;
  }

  void setDecorateMode(bool value) {
    _decorateMode = value;
    for (final piece in _pieces) {
      piece.decorateMode = value;
    }
  }

  void apply(
      List<PetRoomBoundary> boundaries, String scene, bool decorateMode) {
    _boundaries = List.of(boundaries);
    _scene = scene;
    _decorateMode = decorateMode;
    // 拖拽中勿整层重建，否则会丢手势且拖感变卡。
    if (_pieces.any((p) => p.dragging)) {
      for (final piece in _pieces) {
        piece.decorateMode = decorateMode;
      }
      return;
    }
    _rebuild();
  }

  void _rebuild() {
    for (final piece in _pieces) {
      piece.removeFromParent();
    }
    _pieces.clear();
    for (final boundary in _boundaries.where((item) => item.scene == _scene)) {
      final piece = _RoomBoundaryPiece(
        boundary: boundary,
        decorateMode: _decorateMode,
        onChanged: _update,
      );
      _pieces.add(piece);
      add(piece);
    }
  }

  void _update(PetRoomBoundary next) {
    final index = _boundaries.indexWhere((item) => item.id == next.id);
    if (index < 0) return;
    _boundaries[index] = next;
    onChanged(List.of(_boundaries));
  }
}

enum _BoundaryDragMode { move, resize }

class _RoomBoundaryPiece extends PositionComponent with DragCallbacks {
  _RoomBoundaryPiece({
    required this.boundary,
    required this.decorateMode,
    required this.onChanged,
  });

  PetRoomBoundary boundary;
  bool decorateMode;
  final void Function(PetRoomBoundary boundary) onChanged;
  _BoundaryDragMode _mode = _BoundaryDragMode.move;
  bool dragging = false;

  static const double _handleSize = 26;

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
    _applyBoundary();
  }

  void _applyBoundary() {
    position = Vector2(
      boundary.x * PetRoomGame.worldWidth,
      boundary.y * PetRoomGame.worldHeight,
    );
    size = Vector2(
      boundary.width * PetRoomGame.worldWidth,
      boundary.height * PetRoomGame.worldHeight,
    );
  }

  void _save() {
    boundary = boundary.copyWith(
      x: (position.x / PetRoomGame.worldWidth).clamp(.04, .96),
      y: (position.y / PetRoomGame.worldHeight).clamp(.12, .94),
      width: (size.x / PetRoomGame.worldWidth).clamp(.03, .9),
      height: (size.y / PetRoomGame.worldHeight).clamp(.03, .8),
    );
    _applyBoundary();
    onChanged(boundary);
  }

  @override
  void render(Canvas canvas) {
    if (!decorateMode) return;
    final rect = size.toRect();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF966A55).withValues(alpha: .22),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = const Color(0xFF8A5D49).withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final handle = Rect.fromCenter(
      center: Offset(size.x, size.y),
      width: _handleSize,
      height: _handleSize,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, const Radius.circular(5)),
      Paint()..color = const Color(0xFF8A5D49),
    );
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!decorateMode) return false;
    return point.x >= -_handleSize / 2 &&
        point.y >= -_handleSize / 2 &&
        point.x <= size.x + _handleSize / 2 &&
        point.y <= size.y + _handleSize / 2;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!decorateMode) {
      event.continuePropagation = true;
      return;
    }
    dragging = true;
    final local = event.localPosition;
    _mode = local.x > size.x - _handleSize && local.y > size.y - _handleSize
        ? _BoundaryDragMode.resize
        : _BoundaryDragMode.move;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!decorateMode || !dragging) return;
    if (_mode == _BoundaryDragMode.resize) {
      size += event.localDelta;
      size.x = size.x.clamp(24, PetRoomGame.worldWidth * .9);
      size.y = size.y.clamp(24, PetRoomGame.worldHeight * .8);
    } else {
      position += event.localDelta;
    }
    // 仅本地移动；松手再 _save，避免每帧 notify→整层重建导致卡顿/丢手势。
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!dragging) return;
    dragging = false;
    _save();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (!dragging) return;
    dragging = false;
    _save();
  }
}

enum _FurnDragMode { move, scale, rotate }

class _FurniturePiece extends PositionComponent
    with DragCallbacks, TapCallbacks, HasGameReference<PetRoomGame> {
  _FurniturePiece({
    required this.listIndex,
    required PetFurniture item,
    required this.decorateMode,
    required this.selected,
  }) : _item = item;

  static const double baseW = 140;
  static const double baseH = 170;
  static const double handle = 22;
  static const double rotateReach = 36;

  final int listIndex;
  PetFurniture _item;
  bool decorateMode;
  bool selected;
  bool dragging = false;
  _FurnDragMode _mode = _FurnDragMode.move;
  double? _lastAngle;
  ui.Image? _image;

  String get itemId => _item.id;
  int get rotation => _item.rotation;
  double get itemScale => _item.scale;

  /// 布置松手后的原地刷新：不重载贴图，避免「拖一下像重新加载」。
  void applyLayout(
    PetFurniture item, {
    required bool decorateMode,
    required bool selected,
  }) {
    final idChanged = item.id != _item.id;
    _item = item;
    this.decorateMode = decorateMode;
    this.selected = selected;
    if (dragging) return;
    size = Vector2(baseW * _item.scale, baseH * _item.scale);
    _placeFromNorm(_item.x, _item.y);
    if (idChanged) {
      unawaited(_loadImage());
    }
  }

  double get normX => (position.x / PetRoomGame.worldWidth).clamp(0.08, 0.92);
  double get normY => (position.y / PetRoomGame.worldHeight).clamp(0.18, 0.92);

  void nudgeNormalized(double dx, double dy) {
    _placeFromNorm(normX + dx, normY + dy);
  }

  void nudgeScale(double delta) {
    _applyScale(_item.scale + delta);
  }

  void setScale(double scale) {
    _applyScale(scale);
  }

  void rotate90() {
    _item = _item.copyWith(rotation: (_item.rotation + 90) % 360);
  }

  void emitMoved() {
    game.onFurnitureMoved?.call(
      listIndex,
      normX,
      normY,
      rotation,
      itemScale,
    );
  }

  void _applyScale(double s) {
    _item = _item.copyWith(scale: s.clamp(0.35, 2.2));
    size = Vector2(baseW * _item.scale, baseH * _item.scale);
  }

  void _placeFromNorm(double nx, double ny) {
    position = Vector2(
      nx.clamp(0.08, 0.92) * PetRoomGame.worldWidth,
      ny.clamp(0.18, 0.92) * PetRoomGame.worldHeight,
    );
  }

  Future<void> _loadImage() async {
    _image = await PetArt.loadImage(PetArt.resolveFurniture(_item.id));
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(baseW * _item.scale, baseH * _item.scale);
    anchor = Anchor.center;
    _placeFromNorm(_item.x, _item.y);
    await _loadImage();
  }

  bool _nearCorner(Vector2 local) {
    final pts = [
      Vector2(0, 0),
      Vector2(size.x, 0),
      Vector2(0, size.y),
      Vector2(size.x, size.y),
    ];
    for (final p in pts) {
      if ((local - p).length <= handle * 1.4) return true;
    }
    return false;
  }

  bool _nearRotateHandle(Vector2 local) {
    final tip = Vector2(size.x / 2, -rotateReach);
    return (local - tip).length <= handle * 1.6;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_item.rotation * math.pi / 180);
    canvas.translate(-size.x / 2, -size.y / 2);
    final img = _image;
    if (img != null) {
      paintImage(canvas: canvas, rect: rect, image: img, fit: BoxFit.contain);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(8), const Radius.circular(12)),
        Paint()..color = const Color(0xFFB0BEC5),
      );
    }
    canvas.restore();

    if (!decorateMode) return;
    final stroke = Paint()
      ..color = selected ? const Color(0xFFE97891) : const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 4 : 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(14)),
      stroke,
    );
    if (!selected) return;

    // 旋转柄
    final midX = size.x / 2;
    canvas.drawLine(
      Offset(midX, 4),
      Offset(midX, -rotateReach + 8),
      Paint()
        ..color = const Color(0xFFE97891)
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      Offset(midX, -rotateReach),
      handle / 2,
      Paint()..color = const Color(0xFFE97891),
    );

    // 四角缩放柄
    for (final p in [
      Offset(0, 0),
      Offset(size.x, 0),
      Offset(0, size.y),
      Offset(size.x, size.y),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: handle, height: handle),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: handle, height: handle),
          const Radius.circular(4),
        ),
        Paint()
          ..color = const Color(0xFFE97891)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (super.containsLocalPoint(point)) return true;
    if (!decorateMode || !selected) return false;
    // 四角 + 顶柄超出本体，扩大命中以便拖拽。
    final pad = handle * 1.2;
    return point.x >= -pad &&
        point.x <= size.x + pad &&
        point.y >= -rotateReach - pad &&
        point.y <= size.y + pad;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (decorateMode) {
      game.selectFurniture(listIndex);
      return;
    }
    game.interactWithFurniture(listIndex);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!decorateMode) {
      event.continuePropagation = true;
      return;
    }
    dragging = true;
    game.selectFurniture(listIndex);
    priority = 30;
    final local = event.localPosition;
    if (_nearRotateHandle(local)) {
      _mode = _FurnDragMode.rotate;
      _lastAngle = math.atan2(
        local.y - size.y / 2,
        local.x - size.x / 2,
      );
    } else if (_nearCorner(local)) {
      _mode = _FurnDragMode.scale;
      _lastAngle = null;
    } else {
      _mode = _FurnDragMode.move;
      _lastAngle = null;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!decorateMode || !dragging) return;
    switch (_mode) {
      case _FurnDragMode.move:
        position += event.localDelta;
        _placeFromNorm(normX, normY);
      case _FurnDragMode.scale:
        final center = size / 2;
        final local = event.localEndPosition;
        final prev = local - event.localDelta;
        final prevDist = (prev - center).length;
        final nextDist = (local - center).length;
        if (prevDist > 8) {
          _applyScale(_item.scale * (nextDist / prevDist));
        }
      case _FurnDragMode.rotate:
        final local = event.localEndPosition;
        final ang = math.atan2(
          local.y - size.y / 2,
          local.x - size.x / 2,
        );
        final prev = _lastAngle;
        if (prev != null) {
          var deg = (ang - prev) * 180 / math.pi;
          if (deg > 180) deg -= 360;
          if (deg < -180) deg += 360;
          final next = ((_item.rotation + deg.round()) % 360 + 360) % 360;
          _item = _item.copyWith(rotation: next);
        }
        _lastAngle = ang;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!dragging) return;
    dragging = false;
    priority = 10;
    _lastAngle = null;
    emitMoved();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    dragging = false;
    priority = 10;
    _lastAngle = null;
  }
}

/// 院子菜地：QQ 农场式网格地块；仅 yard 可见。
class _FarmLayer extends PositionComponent with HasGameReference<PetRoomGame> {
  _FarmLayer({required this.onPlotTapped});

  final void Function(int index, PetCropSlot slot) onPlotTapped;

  /// 田块单元格（世界像素）。
  static const cellW = 108.0;
  static const cellH = 98.0;
  static const gap = 8.0;
  static const plotW = 100.0;
  static const plotH = 92.0;

  List<PetCropSlot> _crops = PetCropSlot.freshPlots();
  String _scene = 'living';
  bool _decorateMode = false;
  final List<_FarmPlot> _plots = [];
  ui.Image? soil;
  ui.Image? sprout;
  ui.Image? grow;
  ui.Image? ripe;
  ui.Image? seedBag;
  ui.Image? seedShop;
  bool _visible = false;
  late Rect _fieldRect;

  static double get _gridWidth =>
      PetCropSlot.gridCols * cellW + (PetCropSlot.gridCols - 1) * gap;
  static double get _gridHeight =>
      PetCropSlot.gridRows * cellH + (PetCropSlot.gridRows - 1) * gap;

  Vector2 _cellCenter(int index) {
    final col = PetCropSlot.colOf(index);
    final row = PetCropSlot.rowOf(index);
    final originX = (PetRoomGame.worldWidth - _gridWidth) / 2;
    // 偏下 ind 草地中央，给顶栏/状态条留空。
    final originY = PetRoomGame.worldHeight * 0.52;
    return Vector2(
      originX + col * (cellW + gap) + cellW / 2,
      originY + row * (cellH + gap) + cellH / 2,
    );
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(PetRoomGame.worldWidth, PetRoomGame.worldHeight);
    priority = 12;
    final originX = (PetRoomGame.worldWidth - _gridWidth) / 2;
    final originY = PetRoomGame.worldHeight * 0.52;
    _fieldRect = Rect.fromLTWH(
      originX - 18,
      originY - 18,
      _gridWidth + 36,
      _gridHeight + 36,
    );

    // 素材多为黑底导出，抠掉近黑背景。
    soil = await PetArt.loadImage(PetArt.farmSoil, knockoutDarkBg: true);
    sprout =
        await PetArt.loadImage(PetArt.farmCropSprout, knockoutDarkBg: true);
    grow = await PetArt.loadImage(PetArt.farmCropGrow, knockoutDarkBg: true);
    ripe = await PetArt.loadImage(PetArt.farmCropRipe, knockoutDarkBg: true);
    seedBag = await PetArt.loadImage(PetArt.farmSeedBag, knockoutDarkBg: true);
    seedShop =
        await PetArt.loadImage(PetArt.farmSeedShop, knockoutDarkBg: true);

    for (var i = 0; i < PetCropSlot.plotCount; i++) {
      final plot = _FarmPlot(
        index: i,
        layer: this,
        onTap: () {
          if (_decorateMode || _scene != 'yard') return;
          final slot = i < _crops.length
              ? _crops[i]
              : PetCropSlot(index: i, stage: PetCropStage.empty);
          onPlotTapped(i, slot);
        },
      );
      plot.position = _cellCenter(i);
      _plots.add(plot);
      await add(plot);
    }
    _refreshVisibility();
  }

  void apply({
    required List<PetCropSlot> crops,
    required String sceneId,
    required bool decorateMode,
  }) {
    _crops = List.of(crops);
    _scene = sceneId;
    _decorateMode = decorateMode;
    for (var i = 0; i < _plots.length; i++) {
      final slot = i < _crops.length
          ? _crops[i]
          : PetCropSlot(index: i, stage: PetCropStage.empty);
      _plots[i].position = _cellCenter(i);
      _plots[i].apply(slot);
    }
    _refreshVisibility();
  }

  void _refreshVisibility() {
    _visible = _scene == 'yard' && !_decorateMode;
    for (final p in _plots) {
      p.visible = _visible;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_visible) return;
    // 田畦底板 + 网格线（QQ 农场感）。
    canvas.drawRRect(
      RRect.fromRectAndRadius(_fieldRect, const Radius.circular(18)),
      Paint()..color = const Color(0x668B6B45),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(_fieldRect.deflate(4), const Radius.circular(14)),
      Paint()..color = const Color(0x552E7D4F),
    );
    final line = Paint()
      ..color = const Color(0x55FFF8E7)
      ..strokeWidth = 1.5;
    final originX = (PetRoomGame.worldWidth - _gridWidth) / 2;
    final originY = PetRoomGame.worldHeight * 0.52;
    for (var c = 1; c < PetCropSlot.gridCols; c++) {
      final x = originX + c * (cellW + gap) - gap / 2;
      canvas.drawLine(
        Offset(x, originY),
        Offset(x, originY + _gridHeight),
        line,
      );
    }
    for (var r = 1; r < PetCropSlot.gridRows; r++) {
      final y = originY + r * (cellH + gap) - gap / 2;
      canvas.drawLine(
        Offset(originX, y),
        Offset(originX + _gridWidth, y),
        line,
      );
    }

    final shop = seedShop;
    if (shop != null) {
      final rect = Rect.fromCenter(
        center: Offset(size.x * 0.88, originY - 36),
        width: 120,
        height: 120,
      );
      paintImage(canvas: canvas, rect: rect, image: shop, fit: BoxFit.contain);
    }
  }
}

class _FarmPlot extends PositionComponent with TapCallbacks {
  _FarmPlot({
    required this.index,
    required this.layer,
    required this.onTap,
  });

  final int index;
  final _FarmLayer layer;
  final VoidCallback onTap;
  PetCropSlot _slot = const PetCropSlot(index: 0, stage: PetCropStage.empty);
  PetCropStage? _lastStage;
  bool visible = false;
  double _pulse = 0;
  double _pop = 0;

  void apply(PetCropSlot slot) {
    if (_lastStage != null && _lastStage != slot.stage) {
      _pop = 1;
    }
    _lastStage = slot.stage;
    _slot = slot;
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(_FarmLayer.plotW, _FarmLayer.plotH);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    if (_slot.isRipe) _pulse += dt * 5;
    if (_pop > 0) _pop = math.max(0, _pop - dt * 2.8);
  }

  ui.Image? get _cropImage => switch (_slot.stage) {
        PetCropStage.seed => layer.sprout,
        PetCropStage.sprout => layer.grow,
        PetCropStage.ripe => layer.ripe,
        PetCropStage.empty => null,
      };

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final popScale = 1 + 0.18 * Curves.easeOutBack.transform(_pop.clamp(0, 1));
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(popScale);
    canvas.translate(-size.x / 2, -size.y / 2);

    final soilImg = layer.soil;
    final soilRect = Rect.fromLTWH(10, 42, size.x - 20, size.y - 48);
    if (soilImg != null) {
      paintImage(
        canvas: canvas,
        rect: soilRect,
        image: soilImg,
        fit: BoxFit.contain,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(soilRect, const Radius.circular(12)),
        Paint()..color = const Color(0xFF8D6E4C),
      );
    }

    final crop = _cropImage;
    final bob = _slot.isRipe ? math.sin(_pulse) * 5 : 0.0;
    if (crop != null) {
      final h = _slot.isRipe
          ? 78.0
          : (_slot.stage == PetCropStage.sprout ? 68.0 : 56.0);
      final cropRect = Rect.fromCenter(
        center: Offset(size.x / 2, 40 + bob),
        width: h * 0.95,
        height: h,
      );
      paintImage(
        canvas: canvas,
        rect: cropRect,
        image: crop,
        fit: BoxFit.contain,
      );
    } else {
      final bag = layer.seedBag;
      if (bag != null) {
        paintImage(
          canvas: canvas,
          rect: Rect.fromCenter(
            center: Offset(size.x / 2, 36),
            width: 40,
            height: 40,
          ),
          image: bag,
          fit: BoxFit.contain,
        );
      }
    }

    // 空地不刷「种菜」字，网格更干净；只提示浇水/可收。
    if (!_slot.isEmpty) {
      final tipText = _slot.isRipe
          ? '收!'
          : (_slot.canWater
              ? (_slot.stage == PetCropStage.seed ? '浇' : '再浇')
              : '');
      if (tipText.isNotEmpty) {
        final tipColor =
            _slot.isRipe ? const Color(0xFFE97891) : const Color(0xFF5C9EAD);
        final tip = TextPainter(
          text: TextSpan(
            text: tipText,
            style: TextStyle(
              color: tipColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Color(0xCCFFFFFF), blurRadius: 4),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tip.paint(canvas, Offset((size.x - tip.width) / 2, size.y - 14));
      }
    }
    canvas.restore();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!visible) return false;
    return super.containsLocalPoint(point);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!visible) return;
    onTap();
  }
}
