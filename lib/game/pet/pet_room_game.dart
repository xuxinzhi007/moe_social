import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/pet_state.dart';
import 'pet_art.dart';

/// 养成小家 Room：固定竖屏舞台；布置模式拖家具/旋转；角色可缩小拖动。
class PetRoomGame extends FlameGame {
  PetRoomGame({
    this.onFurnitureMoved,
    this.onFurnitureSelected,
    this.onActorMoved,
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

  PetProfile _profile = PetProfile.fresh();
  String? _fxLabel;
  double _fxT = 0;
  bool decorateMode = false;
  int? selectedFurnitureIndex;

  _RoomBackdrop? _backdrop;
  _PetActor? _actor;
  final Map<int, _FurniturePiece> _pieces = {};

  void syncProfile(PetProfile profile) {
    _profile = profile;
    _backdrop?.apply(profile);
    _actor?.apply(profile, forcePosition: !_actorDragging);
    _syncFurniture();
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
    await world.add(_backdrop!);
    await world.add(_actor!);
    syncProfile(_profile);
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

  static const double actorW = 200;
  static const double actorH = 268;

  final void Function(double x, double y) onMoved;

  PetProfile _profile = PetProfile.fresh();
  ui.Image? _character;
  ui.Image? _shoes;
  ui.Image? _bottom;
  ui.Image? _top;
  ui.Image? _hat;
  String _wearKey = '';
  bool decorateMode = false;
  bool dragging = false;

  double get normX =>
      (position.x / PetRoomGame.worldWidth).clamp(0.12, 0.88);
  double get normY =>
      (position.y / PetRoomGame.worldHeight).clamp(0.35, 0.88);

  void apply(PetProfile profile, {bool forcePosition = true}) {
    _profile = profile;
    if (forcePosition && !dragging) {
      _placeFromNorm(profile.actorX, profile.actorY);
    }
    _load();
  }

  void _placeFromNorm(double nx, double ny) {
    position = Vector2(
      nx.clamp(0.12, 0.88) * PetRoomGame.worldWidth,
      ny.clamp(0.35, 0.88) * PetRoomGame.worldHeight,
    );
  }

  Future<void> _load() async {
    _character =
        await PetArt.loadImage(PetArt.model) ?? await PetArt.loadImage(PetArt.body);
    // 仅服装 id 变化时重载贴图；ox/oy/scale/rot 在 render 时读取。
    final key =
        '${_profile.hatId}|${_profile.topId}|${_profile.bottomId}|${_profile.shoesId}';
    if (key == _wearKey &&
        _shoes != null &&
        _bottom != null &&
        _top != null) {
      return;
    }
    _wearKey = key;
    _shoes = await _loadSlot('shoes', _profile.shoesId);
    _bottom = await _loadSlot('bottom', _profile.bottomId);
    _top = await _loadSlot('top', _profile.topId);
    _hat = _profile.hatId.isEmpty
        ? null
        : await _loadSlot('hat', _profile.hatId);
  }

  Future<ui.Image?> _loadSlot(String slot, String id) async {
    final path = await PetArt.resolveClothesPath(slot, id);
    if (path == null) return null;
    return PetArt.loadImage(path);
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(actorW, actorH);
    anchor = Anchor.center;
    priority = 20;
    _placeFromNorm(_profile.actorX, _profile.actorY);
    await _load();
  }

  /// 按换衣间保存的 ox/oy/scale/rot 画单层（不再铺满角色）。
  void _paintWearLayer(
    Canvas canvas,
    ui.Image? image,
    PetWearLayer layer,
  ) {
    if (image == null) return;
    final w = size.x * layer.scale.clamp(0.15, 1.2);
    final h = size.y * layer.scale.clamp(0.15, 1.2);
    final cx = size.x / 2 + layer.ox * size.x;
    final cy = size.y / 2 + layer.oy * size.y;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.save();
    canvas.translate(cx, cy);
    if (layer.rot != 0) {
      canvas.rotate(layer.rot * math.pi / 180);
    }
    paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.contain);
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final img = _character;
    if (img != null) {
      paintImage(canvas: canvas, rect: rect, image: img, fit: BoxFit.contain);
    } else {
      canvas.drawOval(rect.deflate(10), Paint()..color = const Color(0xFFFFB7C5));
    }
    final layout = _profile.wearLayout;
    _paintWearLayer(canvas, _shoes, layout.shoes);
    _paintWearLayer(canvas, _bottom, layout.bottom);
    _paintWearLayer(canvas, _top, layout.top);
    _paintWearLayer(canvas, _hat, layout.hat);
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
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // 布置模式优先拖家具；非布置时可拖角色走动。
    if (decorateMode) {
      event.continuePropagation = true;
      return;
    }
    dragging = true;
    priority = 40;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (decorateMode || !dragging) return;
    position += event.localDelta;
    _placeFromNorm(normX, normY);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!dragging) return;
    dragging = false;
    priority = 20;
    onMoved(normX, normY);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    dragging = false;
    priority = 20;
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

  int get rotation => _item.rotation;
  double get itemScale => _item.scale;

  double get normX =>
      (position.x / PetRoomGame.worldWidth).clamp(0.08, 0.92);
  double get normY =>
      (position.y / PetRoomGame.worldHeight).clamp(0.18, 0.92);

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
