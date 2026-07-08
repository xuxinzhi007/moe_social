import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'moe_motion.dart';

/// 动效性能档位（按平台 / 屏幕 / 无障碍自动推导）。
enum MoeVfxTier {
  low,
  standard,
  high,
}

/// 礼物 / 成就粒子动效的运行时配置（移动端优先）。
class MoeVfxProfile {
  final MoeVfxTier tier;
  final bool reduceMotion;
  final bool isNativeMobile;
  final bool isWeb;
  final bool isCompact;
  final double layoutScale;
  final double particleScale;
  final bool enableLuxuryFlash;
  final bool enableBurstParticles;
  final bool enableHaptics;
  final double flyInOffset;

  const MoeVfxProfile({
    required this.tier,
    required this.reduceMotion,
    required this.isNativeMobile,
    required this.isWeb,
    required this.isCompact,
    required this.layoutScale,
    required this.particleScale,
    required this.enableLuxuryFlash,
    required this.enableBurstParticles,
    required this.enableHaptics,
    required this.flyInOffset,
  });

  /// 无 [BuildContext] 时的兜底（队列回放等场景）。
  static const MoeVfxProfile standard = MoeVfxProfile(
    tier: MoeVfxTier.standard,
    reduceMotion: false,
    isNativeMobile: true,
    isWeb: false,
    isCompact: false,
    layoutScale: 1,
    particleScale: 0.85,
    enableLuxuryFlash: true,
    enableBurstParticles: true,
    enableHaptics: true,
    flyInOffset: 200,
  );

  factory MoeVfxProfile.fromContext(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reduce = moeReduceMotion(context);
    final width = mq.size.width;
    final height = mq.size.height;
    final compact = width < 360 || height < 640;
    final isWeb = kIsWeb;
    final isNativeMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    final tier = _resolveTier(
      reduceMotion: reduce,
      isWeb: isWeb,
      isCompact: compact,
      isNativeMobile: isNativeMobile,
    );

    final particleScale = switch (tier) {
      MoeVfxTier.low => 0.5,
      MoeVfxTier.standard => isNativeMobile ? 0.85 : 0.75,
      MoeVfxTier.high => isNativeMobile ? 1.0 : 0.85,
    };

    return MoeVfxProfile(
      tier: tier,
      reduceMotion: reduce,
      isNativeMobile: isNativeMobile,
      isWeb: isWeb,
      isCompact: compact,
      layoutScale: compact ? 0.9 : 1.0,
      particleScale: particleScale,
      enableLuxuryFlash:
          !reduce && !isWeb && tier != MoeVfxTier.low && isNativeMobile,
      enableBurstParticles: !reduce && tier != MoeVfxTier.low,
      enableHaptics: isNativeMobile && !reduce,
      flyInOffset: compact
          ? 160
          : isWeb
              ? 140
              : 220,
    );
  }

  static MoeVfxTier _resolveTier({
    required bool reduceMotion,
    required bool isWeb,
    required bool isCompact,
    required bool isNativeMobile,
  }) {
    if (reduceMotion || isWeb) return MoeVfxTier.low;
    if (isNativeMobile && !isCompact) return MoeVfxTier.high;
    if (isNativeMobile) return MoeVfxTier.standard;
    return MoeVfxTier.standard;
  }

  int scaledBurstCount(int base) {
    if (!enableBurstParticles && reduceMotion) return 0;
    if (!enableBurstParticles) return (base * 0.6).round().clamp(8, base);
    return (base * particleScale).round().clamp(8, base);
  }

  int scaledCoreCount(int base) {
    if (reduceMotion) return 0;
    return (base * particleScale).round().clamp(8, base);
  }

  Duration scaledDuration(Duration base) {
    if (reduceMotion) {
      return Duration(milliseconds: (base.inMilliseconds * 0.55).round());
    }
    if (tier == MoeVfxTier.low) {
      return Duration(milliseconds: (base.inMilliseconds * 0.75).round());
    }
    return base;
  }
}
