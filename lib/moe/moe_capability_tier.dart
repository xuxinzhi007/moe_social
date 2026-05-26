/// Moe Core 能力档位（与后端 [CapabilityTier] 一致）。
abstract final class MoeCapabilityTier {
  static const String s0 = 's0';
  static const String s1 = 's1';
  static const String s2 = 's2'; // 默认 7B
  static const String s3 = 's3';

  static const String defaultTier = s2;
}
