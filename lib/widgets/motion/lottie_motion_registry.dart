import '../../models/gift.dart';
import 'moe_vfx_profile.dart';

/// Lottie 模板路径注册表（按档位，不按 SKU）。
///
/// 二期可在此接 CDN / `gift.lottie_asset` 覆盖。
abstract final class LottieMotionRegistry {
  static const giftsDir = 'assets/lottie/gifts';

  static const giftBurstBasic = '$giftsDir/gift_burst_basic.json';
  static const giftBurstMedium = '$giftsDir/gift_burst_medium.json';
  static const giftBurstAdvanced = '$giftsDir/gift_burst_advanced.json';
  static const giftBurstLuxury = '$giftsDir/gift_burst_luxury.json';

  /// 预载优先队列（冷启动 / 打开礼物面板时）。
  static const List<String> giftPrecacheAssets = [
    giftBurstBasic,
    giftBurstMedium,
    giftBurstAdvanced,
    giftBurstLuxury,
  ];

  /// Web / 低端将 luxury 降为 advanced，避免全屏重模板。
  static GiftLevel effectiveGiftLevel(GiftLevel level, MoeVfxProfile profile) {
    if (level == GiftLevel.luxury &&
        (profile.isWeb || profile.tier == MoeVfxTier.low)) {
      return GiftLevel.advanced;
    }
    return level;
  }

  static String giftBurst(GiftLevel level) {
    return switch (level) {
      GiftLevel.basic => giftBurstBasic,
      GiftLevel.medium => giftBurstMedium,
      GiftLevel.advanced => giftBurstAdvanced,
      GiftLevel.luxury => giftBurstLuxury,
    };
  }

  static String giftBurstFor(Gift gift, MoeVfxProfile profile) {
    return giftBurst(effectiveGiftLevel(gift.level, profile));
  }

  /// 二期：单礼物覆盖；一期恒为 null。
  static String? giftOverride(String giftId) => null;
}
