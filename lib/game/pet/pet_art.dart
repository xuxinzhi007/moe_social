import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 养成美术路径与缺图探测。
///
/// 正式资源在 `assets/pet/`（英文蛇形）。源素材可放在
/// `assets/avatars/flutter角色图/`，再同步到本目录。
class PetArt {
  const PetArt._();

  static String roomBg(String sceneId) => 'assets/pet/room/${sceneId}_bg.png';

  static const body = 'assets/pet/character/body.png';
  static const model = 'assets/pet/character/model.png';
  static const ear = 'assets/pet/character/ear.png';
  static const babyHead = 'assets/pet/character/baby_head.png';
  static const monsterHead = 'assets/pet/adventure/monster_head.png';

  static String clothes(String slotId) {
    if (slotId.isEmpty) return '';
    return 'assets/pet/clothes/$slotId.png';
  }

  static String furniture(String id) => 'assets/pet/furniture/$id.png';

  static const coin = 'assets/pet/ui/coin.png';

  /// 装扮 ID → 实际文件（缺专用图时回落到基础款）。
  static String resolveClothes(String slot, String id) {
    if (id.isEmpty) {
      return slot == 'hat' ? '' : clothes('${slot}_basic');
    }
    return clothes(id);
  }

  /// 有专用图用专用图，否则回落同槽基础款（舞台叠穿用）。
  static Future<String?> resolveClothesPath(String slot, String id) async {
    final primary = resolveClothes(slot, id);
    if (primary.isNotEmpty && await exists(primary)) return primary;
    final fallback = switch (slot) {
      'hat' => clothes('hat_cap'),
      'top' => clothes('top_basic'),
      'bottom' => clothes('bottom_basic'),
      'shoes' => clothes('shoes_basic'),
      _ => '',
    };
    if (fallback.isNotEmpty && await exists(fallback)) return fallback;
    return null;
  }

  /// 家具 ID → 资源路径（未知 ID 按前缀回落）。
  static String resolveFurniture(String id) {
    const known = {
      'bed_basic',
      'bed_cozy',
      'table_wood',
      'lamp_basic',
      'lamp_soft',
      'rug_basic',
      'rug_heart',
      'window_lace',
    };
    if (known.contains(id)) {
      // cozy/soft/heart 暂复用基础款图
      final file = switch (id) {
        'bed_cozy' => 'bed_basic',
        'lamp_soft' => 'lamp_basic',
        'rug_heart' => 'rug_basic',
        _ => id,
      };
      return furniture(file);
    }
    final prefix = id.split('_').first;
    return switch (prefix) {
      'bed' => furniture('bed_basic'),
      'table' || 'desk' => furniture('table_wood'),
      'lamp' => furniture('lamp_basic'),
      'rug' => furniture('rug_basic'),
      'window' => furniture('window_lace'),
      _ => furniture(id),
    };
  }

  static Future<bool> exists(String assetPath) async {
    if (assetPath.isEmpty) return false;
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 加载 PNG；1×1 占位视为无效。
  static Future<ui.Image?> loadImage(String assetPath) async {
    if (assetPath.isEmpty) return null;
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (frame.image.width <= 2 && frame.image.height <= 2) {
        return null;
      }
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}
