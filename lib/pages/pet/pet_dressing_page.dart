import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../game/pet/pet_art.dart';
import '../../game/pet/pet_avatar_backend.dart';
import '../../game/pet/pet_avatar_stack.dart';
import '../../game/pet/pet_content_catalog.dart';
import '../../game/pet/pet_labels.dart';
import '../../game/pet/pet_lpc_item_thumb.dart';
import '../../game/pet/pet_lpc_sheet.dart';
import '../../game/pet/pet_moe_item_thumb.dart';
import '../../game/pet/pet_sheet_avatar.dart';
import '../../models/pet_state.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

/// 换衣间：模型锚点穿搭 + 大预览；可选微调位移/缩放/旋转。
///
/// 货架 SSOT：`content_manifest.json`（[PetContentCatalog]）。
/// 锚点：`avatar_stack.json` · `docs/dev/pet-binding-skeleton-ssot.md`。
class PetDressingPage extends StatefulWidget {
  const PetDressingPage({super.key});

  @override
  State<PetDressingPage> createState() => _PetDressingPageState();
}

class _PetDressingPageState extends State<PetDressingPage> {
  late String _hatId;
  late String _topId;
  late String _bottomId;
  late String _shoesId;
  late PetWearLayout _layout;
  PetWearLayout _anchors = PetWearLayout.defaults;
  String _activeSlot = 'top';
  var _saving = false;
  var _fineTune = false;
  final Map<String, List<String>> _sheetCatalog = {};

  @override
  void initState() {
    super.initState();
    final p = context.read<PetProvider>().profile;
    _hatId = p.hatId;
    _topId = p.topId;
    _bottomId = p.bottomId;
    _shoesId = p.shoesId;
    _layout = p.wearLayout;
    _loadAnchors();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    await PetContentCatalog.load();
    if (_sheetMode) {
      const slots = ['hat', 'top', 'bottom', 'shoes'];
      final m = <String, List<String>>{};
      for (final s in slots) {
        m[s] = await PetSheetAvatar.itemIdsForSlot(s);
      }
      if (!mounted) return;
      setState(() {
        _sheetCatalog
          ..clear()
          ..addAll(m);
      });
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadAnchors() async {
    final cfg = await PetAvatarStackConfig.load();
    if (!mounted) return;
    setState(() => _anchors = cfg.wearAnchors);
  }

  /// LPC：lpc_catalog 槽位；Paper：content_manifest。均含「无」。
  List<String> get _activeIds {
    if (_sheetMode) {
      final ids = _sheetCatalog[_activeSlot] ?? const <String>[];
      return ['', ...ids];
    }
    return PetContentCatalog.clothesIds(_activeSlot);
  }

  String get _activeId => switch (_activeSlot) {
        'hat' => _hatId,
        'top' => _topId,
        'bottom' => _bottomId,
        _ => _shoesId,
      };

  /// 选单品：空=脱下；有货=贴到模型锚点（正式方案默认）。
  void _setActiveId(String id) {
    setState(() {
      if (_activeSlot == 'hat') {
        _hatId = id;
      } else if (_activeSlot == 'top') {
        _topId = id;
      } else if (_activeSlot == 'bottom') {
        _bottomId = id;
      } else {
        _shoesId = id;
      }
      if (id.isNotEmpty) {
        _layout = _layout.updateSlot(_activeSlot, _anchors.slot(_activeSlot));
      }
    });
  }

  void _resetActiveToAnchor() {
    if (_activeId.isEmpty) return;
    setState(() {
      _layout = _layout.updateSlot(_activeSlot, _anchors.slot(_activeSlot));
    });
  }

  void _updateLayer(PetWearLayer layer) {
    setState(() => _layout = _layout.updateSlot(_activeSlot, layer));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final pet = context.read<PetProvider>();
    await pet.saveOutfit(
      hatId: _hatId,
      topId: _topId,
      bottomId: _bottomId,
      shoesId: _shoesId,
      wearLayout: _layout,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    MoeToast.success(context, '穿着已保存到小家');
    Navigator.pop(context);
  }

  String? _asset(String slot, String id) {
    if (id.isEmpty) return null;
    final path = PetArt.resolveClothes(slot, id);
    return path.isEmpty ? null : path;
  }

  static const _railPad = 12.0;

  bool get _sheetMode => PetSheetAvatar.isActive;

  bool get _moeMode => resolvePetAvatarBackend() == PetAvatarBackend.moe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5EE),
        foregroundColor: const Color(0xFF5A4638),
        elevation: 0,
        title: const Text(
          '换衣间',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE97891),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 预览与下方衣柜同宽（_railPad），纵向吃满剩余高度（非正方形）。
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_railPad, 0, _railPad, 8),
                child: _DressPreview(
                  hatId: _hatId,
                  topId: _topId,
                  bottomId: _bottomId,
                  shoesId: _shoesId,
                  layout: _layout,
                  activeSlot: _activeSlot,
                  fineTune: !_sheetMode && _fineTune && _activeId.isNotEmpty,
                  onUpdateActive: _updateLayer,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_railPad, 0, _railPad, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _sheetMode
                          ? (_activeId.isEmpty
                              ? '${_moeMode ? 'Moe' : 'LPC'} · 未穿 · manifest 槽位'
                              : '${_moeMode ? 'Moe' : 'LPC'} · ${PetLabels.of(_activeId)} · 分层叠穿')
                          : (_activeId.isEmpty
                              ? '未穿 · 点「无」可脱下'
                              : '${PetLabels.of(_activeId)} · '
                                  '${(_layout.slot(_activeSlot).scale * 100).round()}%'
                                  ' · ${_layout.slot(_activeSlot).rot.round()}°'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A7364),
                      ),
                    ),
                  ),
                  if (!_sheetMode && _fineTune)
                    TextButton(
                      onPressed:
                          _activeId.isEmpty ? null : _resetActiveToAnchor,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE97891),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('复位'),
                    ),
                  if (!_sheetMode)
                    FilterChip(
                      label: const Text('微调'),
                      selected: _fineTune,
                      onSelected: _activeId.isEmpty
                          ? null
                          : (v) => setState(() => _fineTune = v),
                      selectedColor: const Color(0xFFFFE4EC),
                      checkmarkColor: const Color(0xFFE97891),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _fineTune
                            ? const Color(0xFFE97891)
                            : const Color(0xFF5A4638),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _railPad),
              child: _SlotSelector(
                active: _activeSlot,
                onSelect: (s) => setState(() {
                  _activeSlot = s;
                  _fineTune = false;
                }),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(_railPad, 0, _railPad, 12),
                itemCount: _activeIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final id = _activeIds[i];
                  final on = id == _activeId;
                  final asset = _sheetMode ? null : _asset(_activeSlot, id);
                  return Material(
                    color: on
                        ? const Color(0xFFFFE4EC)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _setActiveId(id),
                      child: Container(
                        width: 88,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: on
                                ? const Color(0xFFE97891)
                                : const Color(0x22000000),
                            width: on ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: id.isEmpty
                                  ? const Icon(
                                      Icons.block,
                                      color: Color(0xFFB0A090),
                                    )
                                  : _sheetMode
                                      ? (_moeMode
                                          ? PetMoeItemThumb(
                                              slot: _activeSlot,
                                              itemId: id,
                                            )
                                          : PetLpcItemThumb(
                                              slot: _activeSlot,
                                              itemId: id,
                                              hatId: _hatId,
                                              topId: _topId,
                                              bottomId: _bottomId,
                                              shoesId: _shoesId,
                                            ))
                                      : Image.asset(
                                          asset ?? '',
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.checkroom_rounded,
                                          ),
                                        ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              id.isEmpty ? '无' : PetLabels.of(id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    on ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotSelector extends StatelessWidget {
  const _SlotSelector({required this.active, required this.onSelect});

  final String active;
  final ValueChanged<String> onSelect;

  static const _items = [
    (id: 'hat', label: '帽', icon: Icons.face_retouching_natural),
    (id: 'top', label: '衣', icon: Icons.checkroom_rounded),
    (id: 'bottom', label: '裤', icon: Icons.dry_cleaning_rounded),
    (id: 'shoes', label: '鞋', icon: Icons.hiking_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33E97891)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE97891).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: active == item.id
                      ? const Color(0xFFFFE4EC)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => onSelect(item.id),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Icon(
                            item.icon,
                            size: 18,
                            color: active == item.id
                                ? const Color(0xFFE97891)
                                : const Color(0xFF8A7364),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: active == item.id
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: active == item.id
                                  ? const Color(0xFFE97891)
                                  : const Color(0xFF5A4638),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DressPreview extends StatefulWidget {
  const _DressPreview({
    required this.hatId,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
    required this.layout,
    required this.activeSlot,
    required this.fineTune,
    required this.onUpdateActive,
  });

  final String hatId;
  final String topId;
  final String bottomId;
  final String shoesId;
  final PetWearLayout layout;
  final String activeSlot;
  final bool fineTune;
  final ValueChanged<PetWearLayer> onUpdateActive;

  @override
  State<_DressPreview> createState() => _DressPreviewState();
}

class _DressPreviewState extends State<_DressPreview>
    with SingleTickerProviderStateMixin {
  PetAvatarStack? _stack;
  PetLpcSheet? _lpc;
  List<PetAvatarLayerStatus> _status = const [];
  var _showStatus = false;
  String _key = '';
  late final AnimationController _idleCtrl;
  var _idleFrame = 0;

  bool get _sheetMode => PetSheetAvatar.isActive;

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _idleCtrl.addListener(() {
      if (!_sheetMode || !mounted) return;
      final f = (_idleCtrl.value * PetLpcSheet.idleCols).floor() %
          PetLpcSheet.idleCols;
      if (f != _idleFrame) setState(() => _idleFrame = f);
    });
    _reload();
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DressPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key =
        '${widget.hatId}|${widget.topId}|${widget.bottomId}|${widget.shoesId}';
    if (key != _key) _reload();
  }

  Future<void> _reload() async {
    final key =
        '${widget.hatId}|${widget.topId}|${widget.bottomId}|${widget.shoesId}';
    _key = key;
    if (_sheetMode) {
      final sheet = await PetSheetAvatar.composeOutfit(
        hatId: widget.hatId,
        topId: widget.topId,
        bottomId: widget.bottomId,
        shoesId: widget.shoesId,
      );
      if (!mounted || _key != key) return;
      setState(() {
        _lpc = sheet;
        _stack = null;
      });
      return;
    }
    final results = await Future.wait([
      PetAvatarStack.compose(
        hatId: widget.hatId,
        topId: widget.topId,
        bottomId: widget.bottomId,
        shoesId: widget.shoesId,
      ),
      PetAvatarStackConfig.diagnose(),
    ]);
    if (!mounted || _key != key) return;
    setState(() {
      _stack = results[0] as PetAvatarStack;
      _lpc = null;
      _status = results[1] as List<PetAvatarLayerStatus>;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stack = _stack;
    final lpc = _lpc;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8F2), Color(0xFFFFE8DC)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x44E97891)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC48B9A).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 外框与衣柜同宽拉高；角色仍在居中正方形画布上画，避免竖框拉伸服装。
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final panel = Size(side, side);
                  return SizedBox(
                    width: side,
                    height: side,
                    child: stack == null && lpc == null
                        ? const Center(child: MoeLoading(size: 32))
                        : stack != null
                            ? Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: PetAvatarStackView(
                                      stack: stack,
                                      layout: widget.layout,
                                    ),
                                  ),
                                  if (widget.fineTune)
                                    _WearEditor(
                                      panel: panel,
                                      layer:
                                          widget.layout.slot(widget.activeSlot),
                                      onChanged: widget.onUpdateActive,
                                    ),
                                ],
                              )
                            : CustomPaint(
                                painter: _LpcFramePainter(
                                  sheet: lpc!,
                                  frame: _idleFrame,
                                ),
                              ),
                  );
                },
              ),
            ),
            if (stack != null || lpc != null)
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _showStatus = !_showStatus),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _showStatus
                            ? Icons.info_rounded
                            : Icons.info_outline_rounded,
                        size: 18,
                        color: lpc != null
                            ? const Color(0xFF8A7364)
                            : (stack!.layeredBody
                                ? const Color(0xFF8A7364)
                                : const Color(0xFFE97891)),
                      ),
                    ),
                  ),
                ),
              ),
            if (_showStatus && lpc != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Text(
                      'LPC · 选部位换装 · 预览与单品缩略图均走 catalog 叠层',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A4638),
                      ),
                    ),
                  ),
                ),
              ),
            if (_showStatus && stack != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stack.layeredBody
                              ? '分层 · ${stack.orderIds.join(' → ')}'
                              : '合体模式 · 缺 head/torso 分层资源',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5A4638),
                          ),
                        ),
                        for (final s in _status)
                          Text(
                            '${s.ready ? '✓' : '✗'} ${s.label}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: s.ready
                                  ? const Color(0xFF66BB6A)
                                  : const Color(0xFFE57373),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LpcFramePainter extends CustomPainter {
  _LpcFramePainter({required this.sheet, required this.frame});

  final PetLpcSheet sheet;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    sheet.paint(canvas, size, dir: 2, moving: false, frame: frame);
  }

  @override
  bool shouldRepaint(covariant _LpcFramePainter old) =>
      old.frame != frame || old.sheet != sheet;
}

/// 微调手柄：位移 / 四角缩放 / 顶柄旋转（支持非正方形预览框）。
class _WearEditor extends StatelessWidget {
  const _WearEditor({
    required this.panel,
    required this.layer,
    required this.onChanged,
  });

  final Size panel;
  final PetWearLayer layer;
  final ValueChanged<PetWearLayer> onChanged;

  static const double _handle = 18;
  static const Color _accent = Color(0xFFE97891);
  static const double _scaleGain = 2.8;

  Offset get _center => Offset(
        panel.width / 2 + layer.ox * panel.width,
        panel.height / 2 + layer.oy * panel.height,
      );

  Size get _box {
    final s = layer.scale.clamp(0.15, 1.2);
    return Size(panel.width * s, panel.height * s);
  }

  void _moveBy(Offset delta) {
    onChanged(
      layer.copyWith(
        ox: (layer.ox + delta.dx / panel.width).clamp(-0.45, 0.45),
        oy: (layer.oy + delta.dy / panel.height).clamp(-0.5, 0.5),
      ),
    );
  }

  void _scaleByCorner(Alignment corner, Offset delta) {
    final sx = corner.x;
    final sy = corner.y;
    final norm = math.min(panel.width, panel.height);
    final deltaScale = (delta.dx * sx + delta.dy * sy) / norm * _scaleGain;
    onChanged(
      layer.copyWith(scale: (layer.scale + deltaScale).clamp(0.18, 1.15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    final c = _center;
    final child = Transform.rotate(
      angle: layer.rot * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => _moveBy(d.delta),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: _accent, width: 2.5),
                ),
              ),
            ),
          ),
          Positioned(
            left: box.width / 2 - (_handle + 6) / 2,
            top: -36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    onChanged(
                      layer.copyWith(rot: layer.rot + d.delta.dx * 1.35),
                    );
                  },
                  child: Container(
                    width: _handle + 6,
                    height: _handle + 6,
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.rotate_right_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(width: 2, height: 12, color: _accent),
              ],
            ),
          ),
          for (final corner in const [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: corner,
              child: Transform.translate(
                offset: Offset(
                  corner.x * (_handle / 2),
                  corner.y * (_handle / 2),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => _scaleByCorner(corner, d.delta),
                  child: Container(
                    width: _handle,
                    height: _handle,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _accent, width: 2.5),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.3),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Positioned(
      left: c.dx - box.width / 2,
      top: c.dy - box.height / 2,
      width: box.width,
      height: box.height,
      child: child,
    );
  }
}
