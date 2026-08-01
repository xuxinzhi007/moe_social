import '../../constants/feature_flags.dart';

/// 小家角色渲染后端。
enum PetAvatarBackend {
  /// 现网：分层 PNG + wear_layout。
  png,

  /// LPC spritesheet 短跑（同画布 + walk/idle）。
  lpc,

  /// Spine 骨骼 + Skin/Slot 换装（需授权与资源）。
  spine,
}

/// 解析当前应使用的形象后端。
///
/// 优先级：Spine（Flag+资源）→ LPC 短跑 Flag → PNG。
PetAvatarBackend resolvePetAvatarBackend({
  bool spineAssetsReady = false,
}) {
  if (FeatureFlags.petSpineAvatar && spineAssetsReady) {
    return PetAvatarBackend.spine;
  }
  if (FeatureFlags.petLpcPrototype) {
    return PetAvatarBackend.lpc;
  }
  return PetAvatarBackend.png;
}

/// Spine 皮肤名 ↔ 产品服装 ID（C2 换装映射表）。
abstract final class PetSpineSkins {
  static String hat(String id) => id.isEmpty ? 'hat_none' : id;
  static String top(String id) => id.isEmpty ? 'top_basic' : id;
  static String bottom(String id) => id.isEmpty ? 'bottom_basic' : id;
  static String shoes(String id) => id.isEmpty ? 'shoes_basic' : id;

  /// 组合皮肤名约定：`base/{hat}/{top}/{bottom}/{shoes}`（若用单一组合 Skin）。
  /// 优先用多 Slot 换附件时可不使用本方法。
  static String combined({
    required String hatId,
    required String topId,
    required String bottomId,
    required String shoesId,
  }) {
    return [
      'base',
      hat(hatId),
      top(topId),
      bottom(bottomId),
      shoes(shoesId),
    ].join('/');
  }
}
