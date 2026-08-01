import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'pet_art.dart';
import 'pet_lpc_sheet.dart';

/// 按 [lpc_catalog.json] 叠层合成 walk/idle sheet（换衣间 + 小家共用）。
class PetLpcComposer {
  PetLpcComposer._(this._cfg);

  final _LpcCatalog _cfg;

  static PetLpcComposer? _cache;

  static Future<PetLpcComposer> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw =
          await rootBundle.loadString('assets/pet/config/lpc_catalog.json');
      _cache = PetLpcComposer._(_LpcCatalog.parse(jsonDecode(raw)));
    } catch (_) {
      _cache = PetLpcComposer._(_LpcCatalog.fallback);
    }
    return _cache!;
  }

  /// 测试/热更 catalog 后清缓存。
  static void clearCache() => _cache = null;

  /// catalog 中某槽位已配置的单品 id（不含「无」）。
  List<String> itemIdsForSlot(String slot) {
    final items = _cfg.slotLayers[slot];
    if (items == null || items.isEmpty) return const [];
    final ids = items.keys.toList()..sort();
    return ids;
  }

  /// 单品对应 LPC 层路径（idle / walk）；catalog 未配置则 null。
  String? layerPathForItem(
    String slot,
    String id, {
    required bool idle,
  }) {
    if (id.isEmpty) return null;
    final m = _cfg.slotLayers[slot]?[id];
    if (m == null) return null;
    final list = idle ? m.idle : m.walk;
    return list.isEmpty ? null : list.first;
  }

  /// 合成指定装扮 id 的 sheet；空槽跳过。
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
    if (walk == null || idle == null) {
      return PetLpcSheet.load();
    }
    return PetLpcSheet.fromImages(walk: walk, idle: idle);
  }

  List<String> _pathsFor({
    required String hatId,
    required String topId,
    required String bottomId,
    required String shoesId,
    required bool idle,
  }) {
    String? layer(String name) =>
        idle ? _cfg.baseLayers[name]?.$2 : _cfg.baseLayers[name]?.$1;

    String? slot(String slotName, String id) {
      if (id.isEmpty) return null;
      final m = _cfg.slotLayers[slotName]?[id];
      if (m == null) return null;
      final list = idle ? m.idle : m.walk;
      return list.isEmpty ? null : list.first;
    }

    final out = <String>[];
    void add(String? p) {
      if (p != null && p.isNotEmpty) out.add(p);
    }

    // z 序：body → 裤 → 衣 → 鞋 → 头 → 脸 → 帽 → 发
    add(layer('body'));
    add(slot('bottom', bottomId));
    add(slot('top', topId));
    add(slot('shoes', shoesId));
    add(layer('head'));
    add(layer('face'));
    add(slot('hat', hatId));
    add(layer('hair'));
    return out;
  }

  static Future<ui.Image?> _composite(List<String> paths) async {
    if (paths.isEmpty) return null;
    img.Image? canvas;
    for (final path in paths) {
      if (!await PetArt.exists(path)) continue;
      final data = await rootBundle.load(path);
      final layer = img.decodeImage(data.buffer.asUint8List());
      if (layer == null) continue;
      if (canvas == null) {
        // 首层作底，保留 PNG 透明通道；勿用空 Image()（默认不透明黑底）。
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

  /// 合成误用不透明黑底时，清掉应透明区域。
  static void _knockoutOpaqueBlack(img.Image image) {
    for (final p in image) {
      if (p.a > 0 && p.r < 22 && p.g < 22 && p.b < 22) {
        p.a = 0;
      }
    }
  }
}

class _LpcCatalog {
  _LpcCatalog({
    required this.baseLayers,
    required this.slotLayers,
  });

  /// name → (walkPath, idlePath)
  final Map<String, (String, String)> baseLayers;
  final Map<String, Map<String, _SlotLayers>> slotLayers;

  static final fallback = _LpcCatalog(
    baseLayers: {
      'body': (
        'assets/pet/lpc/layers/body_walk.png',
        'assets/pet/lpc/layers/body_idle.png',
      ),
      'head': (
        'assets/pet/lpc/layers/head_walk.png',
        'assets/pet/lpc/layers/head_idle.png',
      ),
      'face': (
        'assets/pet/lpc/layers/face_walk.png',
        'assets/pet/lpc/layers/face_idle.png',
      ),
      'hair': (
        'assets/pet/lpc/layers/hair_walk.png',
        'assets/pet/lpc/layers/hair_idle.png',
      ),
    },
    slotLayers: const {},
  );

  static _LpcCatalog parse(Map<String, dynamic> json) {
    final baseLayers = <String, (String, String)>{};
    final baseMap = json['base'] as Map<String, dynamic>?;
    if (baseMap != null) {
      for (final e in baseMap.entries) {
        final m = Map<String, dynamic>.from(e.value as Map);
        baseLayers[e.key] = ('${m['walk']}', '${m['idle']}');
      }
    }

    if (baseLayers.isEmpty) {
      return fallback;
    }

    final slotsRaw = json['slotLayers'] as Map<String, dynamic>? ?? {};
    final slotLayers = <String, Map<String, _SlotLayers>>{};
    for (final slot in slotsRaw.entries) {
      final items = slot.value as Map<String, dynamic>;
      slotLayers[slot.key] = {};
      for (final item in items.entries) {
        final m = item.value as Map<String, dynamic>;
        slotLayers[slot.key]![item.key] = _SlotLayers(
          walk: (m['walk'] as List?)?.map((e) => '$e').toList() ?? [],
          idle: (m['idle'] as List?)?.map((e) => '$e').toList() ?? [],
        );
      }
    }
    return _LpcCatalog(baseLayers: baseLayers, slotLayers: slotLayers);
  }
}

class _SlotLayers {
  const _SlotLayers({required this.walk, required this.idle});
  final List<String> walk;
  final List<String> idle;
}
