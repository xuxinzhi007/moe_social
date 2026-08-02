import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/pet_state.dart';
import 'pet_art.dart';
import 'pet_avatar_backend.dart';
import 'pet_avatar_stack.dart';
import 'pet_sheet_avatar.dart';
import 'pet_lpc_sheet.dart';

enum PetCarePerformance { feed, care }

/// 养成小家 Room：固定竖屏舞台；布置模式拖家具/旋转；角色可缩小拖动。
class PetRoomGame extends FlameGame {
  PetRoomGame({
    this.onFurnitureMoved,
    this.onFurnitureSelected,
    this.onActorMoved,
    this.onRoomBoundariesChanged,
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

  PetProfile _profile = PetProfile.fresh();
  String? _fxLabel;
  double _fxT = 0;
  bool decorateMode = false;
  int? selectedFurnitureIndex;

  _RoomBackdrop? _backdrop;
  _PetActor? _actor;
  final Map<int, _FurniturePiece> _pieces = {};
  _RoomBoundaryLayer? _boundaryLayer;

  void syncProfile(PetProfile profile) {
    _profile = profile;
    _backdrop?.apply(profile);
    _actor?.apply(profile, forcePosition: !_actorDragging);
    _syncFurniture();
    _boundaryLayer?.apply(
        profile.roomBoundaries, profile.sceneId, decorateMode);
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
    await world.add(_backdrop!);
    await world.add(_boundaryLayer!);
    await world.add(_actor!);
    syncProfile(_profile);
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
    if (_pieces.values.any((p) => p.dragging)) return;
    for (final p in _pieces.values) {
      p.removeFromParent();
    }
    _pieces.clear();
    final scene = _profile.sceneId;
    for (var i = 0; i < _profile.furniture.length; i++) {
      final f = _profile.furniture[i];
      if (f.scene != scene) continue;
      final piece = _FurniturePiece(
        listIndex: i,
        item: f,
        decorateMode: decorateMode,
        selected: selectedFurnitureIndex == i,
      );
      piece.priority = 10;
      _pieces[i] = piece;
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
    with HasGameReference<PetRoomGame> {
  PetProfile _profile = PetProfile.fresh();
  ui.Image? _bgImage;

  void apply(PetProfile profile) {
    _profile = profile;
    _loadBg();
  }

  Future<void> _loadBg() async {
    _bgImage = await PetArt.loadImage(PetArt.roomBg(_profile.sceneId));
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(PetRoomGame.worldWidth, PetRoomGame.worldHeight);
    priority = 0;
    await _loadBg();
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
      return;
    }
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

  /// LPC 自主移动目标（世界坐标）；null = 站立等待下一次闲逛。
  Vector2? _wanderTarget;
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
    _careT = 1.8;
    _wanderTarget = null;
  }

  void setMoveInput(Vector2 input) {
    final wasMoving = _moveInput.length2 > 0.0001;
    _moveInput = input.length2 > 1 ? input.normalized() : input;
    if (_moveInput.length2 > 0.0001) {
      _wanderTarget = null;
      _idleWait = 1.0;
    } else if (wasMoving) {
      onMoved(normX, normY);
    }
  }

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
    } else if (!_useSheet || _lpc == null) {
      _moving = false;
      return;
    } else {
      if (_wanderTarget == null) {
        _idleWait -= dt;
        _moving = false;
        if (_idleWait <= 0) {
          _pickWanderTarget();
        }
      } else {
        final to = _wanderTarget! - position;
        final dist = to.length;
        if (dist < 4) {
          _wanderTarget = null;
          _idleWait = 1.2 + _rng.nextDouble() * 2.4;
          _moving = false;
          onMoved(normX, normY);
        } else {
          final step = math.min(_walkSpeed * dt, dist);
          final delta = to.normalized() * step;
          _moveWithinRoom(delta);
          _dir = PetLpcSheet.dirFromVelocity(delta.x, delta.y);
          _moving = true;
        }
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
    _wanderTarget = Vector2(
      nx * PetRoomGame.worldWidth,
      ny * PetRoomGame.worldHeight,
    );
    _frame = 0;
  }

  @override
  void render(Canvas canvas) {
    final careProgress = (1 - _careT / 1.8).clamp(0.0, 1.0);
    final isEating = _carePerformance == PetCarePerformance.feed;
    final bob = _careT > 0 ? math.sin(careProgress * math.pi * 4) * 5 : 0.0;
    canvas.save();
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
    if (!decorateMode) return;
    final local = event.localPosition;
    _mode = local.x > size.x - _handleSize && local.y > size.y - _handleSize
        ? _BoundaryDragMode.resize
        : _BoundaryDragMode.move;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!decorateMode) return;
    if (_mode == _BoundaryDragMode.resize) {
      size += event.localDelta;
      size.x = size.x.clamp(24, PetRoomGame.worldWidth * .9);
      size.y = size.y.clamp(24, PetRoomGame.worldHeight * .8);
    } else {
      position += event.localDelta;
    }
    _save();
  }

  @override
  void onDragEnd(DragEndEvent event) => _save();

  @override
  void onDragCancel(DragCancelEvent event) => _save();
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

  int get rotation => _item.rotation;
  double get itemScale => _item.scale;

  double get normX => (position.x / PetRoomGame.worldWidth).clamp(0.08, 0.92);
  double get normY => (position.y / PetRoomGame.worldHeight).clamp(0.18, 0.92);

  void nudgeNormalized(double dx, double dy) {
    _placeFromNorm(normX + dx, normY + dy);
  }

  void nudgeScale(double delta) {
    _applyScale(_item.scale + delta);
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
    if (!decorateMode) return;
    game.selectFurniture(listIndex);
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
