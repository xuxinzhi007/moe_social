import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../game/pet/pet_labels.dart';
import '../../models/pet_state.dart';
import '../../providers/pet_provider.dart';

/// 换衣间整页：左侧选中驱动，右侧大预览变换（位移 / 四角缩放 / 顶柄旋转）。
class PetDressingPage extends StatefulWidget {
  const PetDressingPage({super.key});

  @override
  State<PetDressingPage> createState() => _PetDressingPageState();
}

class _PetDressingPageState extends State<PetDressingPage> {
  static const _hats = [
    '',
    'hat_cap',
    'hat_beret',
    'hat_crown',
    'hat_bow',
    'hat_earmuff',
    'hat_vip_star',
  ];
  static const _tops = [
    'top_basic',
    'top_hoodie',
    'top_tee',
    'top_coat',
    'top_dress',
    'top_vest',
  ];
  static const _bottoms = [
    'bottom_basic',
    'bottom_skirt',
    'bottom_jeans',
    'bottom_shorts',
    'bottom_pants',
    'bottom_overall',
  ];
  static const _shoes = [
    'shoes_basic',
    'shoes_sneaker',
    'shoes_boot',
    'shoes_sandal',
    'shoes_slipper',
    'shoes_heel',
  ];

  late String _hatId;
  late String _topId;
  late String _bottomId;
  late String _shoesId;
  late PetWearLayout _layout;
  String _activeSlot = 'hat';
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<PetProvider>().profile;
    _hatId = p.hatId;
    _topId = p.topId;
    _bottomId = p.bottomId;
    _shoesId = p.shoesId;
    _layout = p.wearLayout;
  }

  List<String> get _activeIds => switch (_activeSlot) {
        'hat' => _hats,
        'top' => _tops,
        'bottom' => _bottoms,
        _ => _shoes,
      };

  String get _activeId => switch (_activeSlot) {
        'hat' => _hatId,
        'top' => _topId,
        'bottom' => _bottomId,
        _ => _shoesId,
      };

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('穿着已保存到小家')),
    );
    Navigator.pop(context);
  }

  String? _asset(String slot, String id) {
    if (slot == 'hat' && id.isEmpty) return null;
    return switch (slot) {
      'hat' => 'assets/pet/clothes/hat_cap.png',
      'top' => 'assets/pet/clothes/top_basic.png',
      'bottom' => 'assets/pet/clothes/bottom_basic.png',
      'shoes' => 'assets/pet/clothes/shoes_basic.png',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final previewSize = (media.width * 0.52).clamp(220.0, 340.0);

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '左侧选部位与单品 → 仅编辑该层：拖动位移 · 四角缩放 · 顶柄旋转',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A4638).withValues(alpha: 0.7),
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧：槽位 + 单品（驱动选中态）
                  SizedBox(
                    width: media.width * 0.42,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _SlotSelector(
                            active: _activeSlot,
                            onSelect: (s) => setState(() => _activeSlot = s),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '编辑：${PetLabels.of(_activeId)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF5A4638),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                            itemCount: _activeIds.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final id = _activeIds[i];
                              final on = id == _activeId;
                              final asset = _asset(_activeSlot, id);
                              return Material(
                                color: on
                                    ? const Color(0xFFFFE4EC)
                                    : Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _setActiveId(id),
                                  child: Container(
                                    height: 72,
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
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: id.isEmpty
                                              ? const Icon(
                                                  Icons.block,
                                                  color: Color(0xFFB0A090),
                                                )
                                              : Image.asset(
                                                  asset ?? '',
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                    Icons.checkroom_rounded,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            id.isEmpty
                                                ? '无'
                                                : PetLabels.of(id),
                                            style: TextStyle(
                                              fontWeight: on
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              fontSize: 13,
                                            ),
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
                  // 右侧：大预览（仅 active 层可操作）
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 12, 12),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: _DressPreview(
                                size: previewSize,
                                hatId: _hatId,
                                topId: _topId,
                                bottomId: _bottomId,
                                shoesId: _shoesId,
                                layout: _layout,
                                activeSlot: _activeSlot,
                                assetOf: _asset,
                                onUpdateActive: _updateLayer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '缩放 ${( _layout.slot(_activeSlot).scale * 100).round()}%'
                            ' · 旋转 ${_layout.slot(_activeSlot).rot.round()}°',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A7364),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

class _DressPreview extends StatelessWidget {
  const _DressPreview({
    required this.size,
    required this.hatId,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
    required this.layout,
    required this.activeSlot,
    required this.assetOf,
    required this.onUpdateActive,
  });

  final double size;
  final String hatId;
  final String topId;
  final String bottomId;
  final String shoesId;
  final PetWearLayout layout;
  final String activeSlot;
  final String? Function(String slot, String id) assetOf;
  final ValueChanged<PetWearLayer> onUpdateActive;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        constraints: BoxConstraints(maxWidth: size, maxHeight: size),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E8),
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
        clipBehavior: Clip.none,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panel = constraints.biggest.shortestSide;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/pet/character/model.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/pet/character/body.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.pets_rounded, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final entry in [
                  ('shoes', shoesId),
                  ('bottom', bottomId),
                  ('top', topId),
                  ('hat', hatId),
                ])
                  if (assetOf(entry.$1, entry.$2) != null)
                    _WearEditor(
                      panelSize: panel,
                      asset: assetOf(entry.$1, entry.$2)!,
                      layer: layout.slot(entry.$1),
                      interactive: entry.$1 == activeSlot,
                      onChanged: onUpdateActive,
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 仅 [interactive] 层响应手势，避免右侧误点切层。
class _WearEditor extends StatelessWidget {
  const _WearEditor({
    required this.panelSize,
    required this.asset,
    required this.layer,
    required this.interactive,
    required this.onChanged,
  });

  final double panelSize;
  final String asset;
  final PetWearLayer layer;
  final bool interactive;
  final ValueChanged<PetWearLayer> onChanged;

  static const double _handle = 18;
  static const Color _accent = Color(0xFFE97891);
  static const double _scaleGain = 2.8;

  Offset get _center => Offset(
        panelSize / 2 + layer.ox * panelSize,
        panelSize / 2 + layer.oy * panelSize,
      );

  double get _side => panelSize * layer.scale.clamp(0.15, 1.2);

  void _moveBy(Offset delta) {
    onChanged(
      layer.copyWith(
        ox: (layer.ox + delta.dx / panelSize).clamp(-0.45, 0.45),
        oy: (layer.oy + delta.dy / panelSize).clamp(-0.5, 0.5),
      ),
    );
  }

  void _scaleByCorner(Alignment corner, Offset delta) {
    final sx = corner.x;
    final sy = corner.y;
    final deltaScale =
        (delta.dx * sx + delta.dy * sy) / panelSize * _scaleGain;
    onChanged(
      layer.copyWith(scale: (layer.scale + deltaScale).clamp(0.18, 1.15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final side = _side;
    final c = _center;
    final child = Transform.rotate(
      angle: layer.rot * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: interactive
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => _moveBy(d.delta),
                    child: _layerBody(selected: true),
                  )
                : IgnorePointer(child: _layerBody(selected: false)),
          ),
          if (interactive) ...[
            Positioned(
              left: side / 2 - (_handle + 6) / 2,
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
        ],
      ),
    );

    return Positioned(
      left: c.dx - side / 2,
      top: c.dy - side / 2,
      width: side,
      height: side,
      child: child,
    );
  }

  Widget _layerBody({required bool selected}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: selected ? Border.all(color: _accent, width: 2.5) : null,
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
