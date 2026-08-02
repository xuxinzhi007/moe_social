import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/pet_state.dart';

/// 内容清单条目（服装 / 家具）。
class PetContentItem {
  const PetContentItem({
    required this.id,
    required this.label,
    required this.asset,
    this.slot,
    this.scenes = const [],
    this.kind = 'clothes',
    this.price,
  });

  final String id;
  final String label;
  final String asset;
  final String? slot;
  final List<String> scenes;
  final String kind;
  final int? price;
}

/// Paper 正式内容骨架：只读 `content_manifest` / `shop_catalog` / `room_composition`。
///
/// SSOT：`docs/dev/pet-binding-skeleton-ssot.md`
abstract final class PetContentCatalog {
  static const manifestPath = 'assets/pet/config/content_manifest.json';
  static const shopPath = 'assets/pet/config/shop_catalog.json';
  static const roomPath = 'assets/pet/config/room_composition.json';

  static bool _loaded = false;
  static final Map<String, List<PetContentItem>> _clothes = {
    'hat': [],
    'top': [],
    'bottom': [],
    'shoes': [],
  };
  static List<PetContentItem> _furniture = const [];
  static List<PetContentItem> _shop = const [];
  static Map<String, double> _furnScale = const {
    'rug': 1.55,
    'bed': 1.25,
    'table': 1.1,
    'lamp': 1.0,
    'window': 1.3,
  };
  static double _actorFootY = 0.64;
  static double _actorHeightNorm = 0.24;
  static List<PetFurniture> _starterFurniture = const [];

  static bool get isLoaded => _loaded;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await _loadManifest();
      await _loadShop();
      await _loadRoom();
    } catch (e, st) {
      debugPrint('PetContentCatalog.load: $e\n$st');
      _applyBuiltinFallback();
    }
    if (_clothes.values.every((e) => e.isEmpty)) {
      _applyBuiltinFallback();
    }
    _loaded = true;
  }

  /// 测试或热更后强制重载。
  static void clearForTest() {
    _loaded = false;
    for (final k in _clothes.keys) {
      _clothes[k] = [];
    }
    _furniture = const [];
    _shop = const [];
    _starterFurniture = const [];
  }

  static List<PetContentItem> clothes(String slot) =>
      List.unmodifiable(_clothes[slot] ?? const []);

  /// 含「无」空串，供换衣间货架。
  static List<String> clothesIds(String slot) => [
        '',
        ...clothes(slot).map((e) => e.id),
      ];

  static List<PetContentItem> furniture({String? scene}) {
    if (scene == null || scene.isEmpty) {
      return List.unmodifiable(_furniture);
    }
    return _furniture
        .where((f) => f.scenes.isEmpty || f.scenes.contains(scene))
        .toList(growable: false);
  }

  /// 家具是否允许出现在该场景（院子不放室内灯/桌等）。
  static bool furnitureAllowedInScene(String id, String scene) {
    for (final e in _furniture) {
      if (e.id != id) continue;
      if (e.scenes.isEmpty) return true;
      return e.scenes.contains(scene);
    }
    // 未知家具：只留室内，避免院子穿帮。
    return scene == 'living' || scene == 'bedroom';
  }

  /// 清掉「场景不允许」的家具（修复旧存档院子里的台灯/木桌）。
  static List<PetFurniture> pruneFurnitureScenes(List<PetFurniture> input) {
    return PetFurniture.sanitize(
      input.where((f) => furnitureAllowedInScene(f.id, f.scene)).toList(),
    );
  }

  static List<PetContentItem> shopItems() => List.unmodifiable(_shop);

  static String? labelOf(String id) {
    if (id.isEmpty) return '无';
    for (final list in _clothes.values) {
      for (final e in list) {
        if (e.id == id) return e.label;
      }
    }
    for (final e in _furniture) {
      if (e.id == id) return e.label;
    }
    for (final e in _shop) {
      if (e.id == id) return e.label;
    }
    return null;
  }

  static String? assetOf(String id) {
    if (id.isEmpty) return null;
    for (final list in _clothes.values) {
      for (final e in list) {
        if (e.id == id) return e.asset;
      }
    }
    for (final e in _furniture) {
      if (e.id == id) return e.asset;
    }
    return null;
  }

  static double furnitureDefaultScale(String id) {
    final kind = id.split('_').first;
    return _furnScale[kind] ?? 1.0;
  }

  static double get actorFootY => _actorFootY;
  static double get actorHeightNorm => _actorHeightNorm;

  static List<PetFurniture> starterFurniture() =>
      List<PetFurniture>.from(_starterFurniture);

  static Future<void> _loadManifest() async {
    final raw = await rootBundle.loadString(manifestPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final clothes = json['clothes'];
    if (clothes is Map) {
      for (final slot in ['hat', 'top', 'bottom', 'shoes']) {
        final list = clothes[slot];
        if (list is! List) continue;
        _clothes[slot] = [
          for (final e in list)
            if (e is Map)
              PetContentItem(
                id: '${e['id'] ?? ''}',
                label: '${e['label'] ?? e['id'] ?? ''}',
                asset: '${e['asset'] ?? ''}',
                slot: slot,
                kind: 'clothes',
              ),
        ].where((e) => e.id.isNotEmpty && e.asset.isNotEmpty).toList();
      }
    }
    final furn = json['furniture'];
    if (furn is List) {
      _furniture = [
        for (final e in furn)
          if (e is Map)
            PetContentItem(
              id: '${e['id'] ?? ''}',
              label: '${e['label'] ?? e['id'] ?? ''}',
              asset: '${e['asset'] ?? ''}',
              scenes:
                  (e['scenes'] as List?)?.map((x) => '$x').toList() ?? const [],
              kind: 'furniture',
            ),
      ].where((e) => e.id.isNotEmpty && e.asset.isNotEmpty).toList();
    }
  }

  static Future<void> _loadShop() async {
    try {
      final raw = await rootBundle.loadString(shopPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final items = json['items'];
      if (items is! List) return;
      _shop = [
        for (final e in items)
          if (e is Map)
            PetContentItem(
              id: '${e['id'] ?? ''}',
              label: '${e['label'] ?? e['id'] ?? ''}',
              asset: assetOf('${e['id'] ?? ''}') ?? '',
              slot: e['slot'] == null ? null : '${e['slot']}',
              kind: '${e['kind'] ?? 'clothes'}',
              price: (e['price'] as num?)?.toInt(),
            ),
      ].where((e) => e.id.isNotEmpty).toList();
    } catch (_) {
      // 商店可选
    }
  }

  static Future<void> _loadRoom() async {
    try {
      final raw = await rootBundle.loadString(roomPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final actor = json['actor'];
      if (actor is Map) {
        _actorFootY = (actor['footY'] as num?)?.toDouble() ?? _actorFootY;
        _actorHeightNorm = (actor['displayHeightNorm'] as num?)?.toDouble() ??
            _actorHeightNorm;
      }
      final defaults = json['furnitureDefaults'];
      if (defaults is Map) {
        final next = <String, double>{..._furnScale};
        for (final e in defaults.entries) {
          final v = e.value;
          if (v is Map && v['scale'] is num) {
            next['${e.key}'] = (v['scale'] as num).toDouble();
          }
        }
        _furnScale = next;
      }
      final scenes = json['scenes'];
      if (scenes is Map) {
        final slots = <PetFurniture>[];
        for (final entry in scenes.entries) {
          final sceneId = '${entry.key}';
          final body = entry.value;
          if (body is! Map) continue;
          final list = body['slots'];
          if (list is! List) continue;
          for (final s in list) {
            if (s is! Map) continue;
            final id = '${s['id'] ?? ''}';
            if (id.isEmpty) continue;
            slots.add(
              PetFurniture(
                id: id,
                x: (s['x'] as num?)?.toDouble() ?? 0.5,
                y: (s['y'] as num?)?.toDouble() ?? 0.6,
                scene: sceneId,
                rotation: (s['rotation'] as num?)?.toInt() ?? 0,
                scale: (s['scale'] as num?)?.toDouble() ??
                    furnitureDefaultScale(id),
              ),
            );
          }
        }
        if (slots.isNotEmpty) _starterFurniture = slots;
      }
    } catch (_) {
      // 构图可选
    }
    if (_starterFurniture.isEmpty) {
      _starterFurniture = _builtinStarter;
    }
  }

  static void _applyBuiltinFallback() {
    _clothes['hat'] = const [
      PetContentItem(
        id: 'hat_cap',
        label: '帽子',
        asset: 'assets/pet/clothes/hat_cap.png',
        slot: 'hat',
      ),
    ];
    _clothes['top'] = const [
      PetContentItem(
        id: 'top_basic',
        label: '基础上衣',
        asset: 'assets/pet/clothes/top_basic.png',
        slot: 'top',
      ),
    ];
    _clothes['bottom'] = const [
      PetContentItem(
        id: 'bottom_basic',
        label: '基础下装',
        asset: 'assets/pet/clothes/bottom_basic.png',
        slot: 'bottom',
      ),
    ];
    _clothes['shoes'] = const [
      PetContentItem(
        id: 'shoes_basic',
        label: '基础鞋',
        asset: 'assets/pet/clothes/shoes_basic.png',
        slot: 'shoes',
      ),
    ];
    _furniture = const [
      PetContentItem(
        id: 'bed_basic',
        label: '小床',
        asset: 'assets/pet/furniture/bed_basic.png',
        scenes: ['living', 'bedroom'],
        kind: 'furniture',
      ),
      PetContentItem(
        id: 'table_wood',
        label: '木桌',
        asset: 'assets/pet/furniture/table_wood.png',
        scenes: ['living'],
        kind: 'furniture',
      ),
      PetContentItem(
        id: 'lamp_basic',
        label: '台灯',
        asset: 'assets/pet/furniture/lamp_basic.png',
        scenes: ['living', 'bedroom'],
        kind: 'furniture',
      ),
      PetContentItem(
        id: 'rug_basic',
        label: '地毯',
        asset: 'assets/pet/furniture/rug_basic.png',
        scenes: ['living', 'bedroom'],
        kind: 'furniture',
      ),
      PetContentItem(
        id: 'window_lace',
        label: '窗纱',
        asset: 'assets/pet/furniture/window_lace.png',
        scenes: ['living', 'bedroom'],
        kind: 'furniture',
      ),
    ];
    if (_starterFurniture.isEmpty) {
      _starterFurniture = _builtinStarter;
    }
  }

  static const _builtinStarter = <PetFurniture>[
    PetFurniture(
        id: 'rug_basic', x: 0.50, y: 0.76, scene: 'living', scale: 1.55),
    PetFurniture(
        id: 'window_lace', x: 0.76, y: 0.26, scene: 'living', scale: 1.3),
    PetFurniture(
        id: 'bed_basic', x: 0.22, y: 0.54, scene: 'living', scale: 1.2),
    PetFurniture(
        id: 'table_wood', x: 0.58, y: 0.60, scene: 'living', scale: 1.1),
    PetFurniture(
        id: 'lamp_basic', x: 0.82, y: 0.48, scene: 'living', scale: 1.0),
    PetFurniture(
        id: 'rug_basic', x: 0.50, y: 0.76, scene: 'bedroom', scale: 1.45),
    PetFurniture(
        id: 'bed_basic', x: 0.30, y: 0.55, scene: 'bedroom', scale: 1.25),
    PetFurniture(
        id: 'lamp_basic', x: 0.74, y: 0.48, scene: 'bedroom', scale: 1.05),
    // yard：无室内家具起步槽，菜地/商店由 Flame 种菜层绘制。
  ];
}
