import 'dart:convert';

import 'package:flutter/services.dart';

/// Pet Content Pack · 运行层能力 id（与 admin petContentPackCapabilities.ts 对齐）。
///
/// SSOT 文档：`docs/dev/pet-content-pack-maturity.md`
enum PetContentRuntimeCapability {
  unifiedManifestV1,
  avatarSheetCompose,
  avatarAnchorModel,
  worldObjectDef,
  furniturePlace,
  scenePresetsV2,
  interactionPickup,
  interactionUseAction,
  publishHashRollback,
}

/// 规范层 WorldObject 快照（只读 · 逐步对齐 TS WorldObjectDef）。
class PetWorldObjectDef {
  const PetWorldObjectDef({
    required this.id,
    required this.kind,
    required this.label,
    required this.assetPath,
    this.scenes = const [],
    this.draggable = true,
    this.pickupable = false,
    this.interactable = false,
  });

  final String id;
  final String kind;
  final String label;
  final String assetPath;
  final List<String> scenes;
  final bool draggable;
  final bool pickupable;
  final bool interactable;

  factory PetWorldObjectDef.fromJson(String objectId, Map<String, dynamic> json) {
    final interaction = json['interaction'];
    return PetWorldObjectDef(
      id: objectId,
      kind: '${json['kind'] ?? 'furniture'}',
      label: '${json['label'] ?? objectId}',
      assetPath: '${(json['asset'] as Map?)?['path'] ?? ''}',
      scenes: (json['scenes'] as List?)?.map((e) => '$e').toList() ?? const [],
      draggable: interaction is Map ? interaction['draggable'] != false : true,
      pickupable: interaction is Map && interaction['pickupable'] == true,
      interactable: interaction is Map && interaction['interactable'] == true,
    );
  }
}

/// 运行层：统一 content pack 注册表（P1 · 只读 scaffold）。
///
/// **未接完前**：家具仍走 [PetFurniture]；avatar 仍走 sheet/锚点 backend。
/// 不可对外宣称 pickup / scenePresets 已官方可用。
abstract final class PetContentRegistry {
  static const _manifestPath = 'assets/pet/moe_content/manifest.json';

  static bool _loaded = false;
  static Map<String, PetWorldObjectDef> _objects = const {};
  static String? _packId;
  static String? _publishVersion;

  /// 与 admin 矩阵对齐：仅 spec 已定义且 App 已接的能力返回 true。
  static bool isCapabilityReady(PetContentRuntimeCapability cap) {
    switch (cap) {
      case PetContentRuntimeCapability.unifiedManifestV1:
        return _loaded;
      case PetContentRuntimeCapability.avatarSheetCompose:
        return true;
      case PetContentRuntimeCapability.avatarAnchorModel:
        return true;
      case PetContentRuntimeCapability.worldObjectDef:
        return _loaded;
      case PetContentRuntimeCapability.furniturePlace:
        return true;
      case PetContentRuntimeCapability.scenePresetsV2:
      case PetContentRuntimeCapability.interactionPickup:
      case PetContentRuntimeCapability.interactionUseAction:
      case PetContentRuntimeCapability.publishHashRollback:
        return false;
    }
  }

  static String? get packId => _packId;
  static String? get publishVersion => _publishVersion;

  static Map<String, PetWorldObjectDef> get objects =>
      Map.unmodifiable(_objects);

  static PetWorldObjectDef? objectById(String id) => _objects[id];

  /// 尝试加载统一 manifest；缺失时静默保持 legacy 路径。
  static Future<void> loadIfPresent() async {
    try {
      final raw = await rootBundle.loadString(_manifestPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _packId = map['packId'] as String?;
      final publish = map['publish'];
      if (publish is Map) {
        _publishVersion = publish['version'] as String?;
      }
      final objectsRaw = map['objects'];
      if (objectsRaw is Map) {
        final parsed = <String, PetWorldObjectDef>{};
        for (final entry in objectsRaw.entries) {
          final id = entry.key;
          final val = entry.value;
          if (val is Map<String, dynamic>) {
            parsed[id] = PetWorldObjectDef.fromJson(id, val);
          }
        }
        _objects = parsed;
      }
      _loaded = true;
    } catch (_) {
      _loaded = false;
      _objects = const {};
    }
  }

  static void clearForTest() {
    _loaded = false;
    _objects = const {};
    _packId = null;
    _publishVersion = null;
  }
}
