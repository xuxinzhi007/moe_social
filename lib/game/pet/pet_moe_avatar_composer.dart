import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'pet_art.dart';
import 'pet_lpc_sheet.dart';

/// Moe 官方 avatar 包：读 manifest + 分层 sheet 运行时 compose（任意槽位组合）。
///
/// SSOT：`assets/pet/moe_content/avatar/manifest.json`
class PetMoeAvatarComposer {
  PetMoeAvatarComposer._(this._cfg);

  static const _packRoot = 'assets/pet/moe_content/avatar/';

  final _MoeManifest _cfg;

  static PetMoeAvatarComposer? _cache;

  static Future<PetMoeAvatarComposer> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('${_packRoot}manifest.json');
      _cache = PetMoeAvatarComposer._(_MoeManifest.parse(jsonDecode(raw)));
    } catch (_) {
      _cache = PetMoeAvatarComposer._(_MoeManifest.empty);
    }
    return _cache!;
  }

  static void clearCache() => _cache = null;

  List<String> itemIdsForSlot(String slot) {
    final items = _cfg.slots[slot];
    if (items == null || items.isEmpty) return const [];
    final ids = items.keys.toList()..sort();
    return ids;
  }

  String? labelForItem(String slot, String id) {
    if (id.isEmpty) return null;
    return _cfg.slots[slot]?[id]?.label;
  }

  Future<PetLpcSheet?> composeOutfit({
    required String hatId,
    required String topId,
    required String bottomId,
    required String shoesId,
  }) async {
    final walkPaths = _pathsFor(
      hatId: hatId,
      topId: topId,
      bottomId: bottomId,
      shoesId: shoesId,
      idle: false,
    );
    final idlePaths = _pathsFor(
      hatId: hatId,
      topId: topId,
      bottomId: bottomId,
      shoesId: shoesId,
      idle: true,
    );
    final walk = await _composite(walkPaths);
    final idle = await _composite(idlePaths);
    if (walk == null || idle == null) return null;
    return PetLpcSheet.fromImages(walk: walk, idle: idle);
  }

  /// 换衣 rail：仅该部件 idle·down·帧0（与 admin 部件缩略图一致）。
  Future<ui.Image?> composePartThumb(String slot, String itemId) async {
    if (itemId.isEmpty) return null;
    final rel = _cfg.slots[slot]?[itemId]?.idle;
    if (rel == null || rel.isEmpty) return null;
    final sheet = await _loadLayer('$_packRoot$rel');
    if (sheet == null) return null;
    final cell = _cfg.cellSize;
    final row = 2; // down
    final bytes = Uint8List.fromList(
      img.encodePng(
        img.copyCrop(sheet, x: 0, y: row * cell, width: cell, height: cell),
      ),
    );
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  List<String> _pathsFor({
    required String hatId,
    required String topId,
    required String bottomId,
    required String shoesId,
    required bool idle,
  }) {
    String? pathForKey(String key) {
      final base = _cfg.base[key];
      if (base != null) {
        return idle ? base.idle : base.walk;
      }
      final slotId = switch (key) {
        'hat' => hatId,
        'top' => topId,
        'bottom' => bottomId,
        'shoes' => shoesId,
        _ => '',
      };
      if (slotId.isEmpty) return null;
      final entry = _cfg.slots[key]?[slotId];
      if (entry == null) return null;
      return idle ? entry.idle : entry.walk;
    }

    final out = <String>[];
    for (final key in _cfg.composeOrder) {
      final rel = pathForKey(key);
      if (rel != null && rel.isNotEmpty) {
        out.add('$_packRoot$rel');
      }
    }
    return out;
  }

  static Future<img.Image?> _loadLayer(String assetPath) async {
    if (!await PetArt.exists(assetPath)) return null;
    final data = await rootBundle.load(assetPath);
    return img.decodeImage(data.buffer.asUint8List());
  }

  static Future<ui.Image?> _composite(List<String> paths) async {
    if (paths.isEmpty) return null;
    img.Image? canvas;
    for (final path in paths) {
      final layer = await _loadLayer(path);
      if (layer == null) continue;
      if (canvas == null) {
        canvas = img.Image.from(layer);
        continue;
      }
      if (canvas.width != layer.width || canvas.height != layer.height) {
        continue;
      }
      img.compositeImage(canvas, layer);
    }
    if (canvas == null) return null;
    _knockoutOpaqueBlack(canvas);
    final bytes = Uint8List.fromList(img.encodePng(canvas));
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  static void _knockoutOpaqueBlack(img.Image image) {
    for (final p in image) {
      if (p.a > 0 && p.r < 22 && p.g < 22 && p.b < 22) {
        p.a = 0;
      }
    }
  }
}

class _LayerPaths {
  const _LayerPaths({required this.walk, required this.idle, this.label});
  final String walk;
  final String idle;
  final String? label;
}

class _MoeManifest {
  _MoeManifest({
    required this.cellSize,
    required this.composeOrder,
    required this.base,
    required this.slots,
  });

  final int cellSize;
  final List<String> composeOrder;
  final Map<String, _LayerPaths> base;
  final Map<String, Map<String, _LayerPaths>> slots;

  static final empty = _MoeManifest(
    cellSize: 64,
    composeOrder: const [
      'body',
      'bottom',
      'top',
      'shoes',
      'head',
      'face',
      'hat',
      'hair'
    ],
    base: const {},
    slots: const {},
  );

  static _MoeManifest parse(Object? json) {
    final root = Map<String, dynamic>.from(json as Map);
    final cellSize = (root['cellSize'] as num?)?.toInt() ?? 64;
    final composeOrder =
        (root['composeOrder'] as List?)?.map((e) => '$e').toList() ??
            empty.composeOrder;

    _LayerPaths? parsePaths(Map<String, dynamic>? m) {
      if (m == null) return null;
      final walk = m['walk'] as String?;
      final idle = m['idle'] as String?;
      if (walk == null || idle == null) return null;
      return _LayerPaths(
        walk: walk,
        idle: idle,
        label: m['label'] as String?,
      );
    }

    final base = <String, _LayerPaths>{};
    final baseMap = root['base'] as Map<String, dynamic>?;
    if (baseMap != null) {
      for (final e in baseMap.entries) {
        final p = parsePaths(Map<String, dynamic>.from(e.value as Map));
        if (p != null) base[e.key] = p;
      }
    }

    final slots = <String, Map<String, _LayerPaths>>{};
    final slotsMap = root['slots'] as Map<String, dynamic>?;
    if (slotsMap != null) {
      for (final slot in slotsMap.entries) {
        final items = slot.value as Map<String, dynamic>;
        slots[slot.key] = {};
        for (final item in items.entries) {
          final p = parsePaths(Map<String, dynamic>.from(item.value as Map));
          if (p != null) slots[slot.key]![item.key] = p;
        }
      }
    }

    if (base.isEmpty) return empty;
    return _MoeManifest(
      cellSize: cellSize,
      composeOrder: composeOrder,
      base: base,
      slots: slots,
    );
  }
}
