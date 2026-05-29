import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';

/// AI 模块视觉 token；共享色值委托 [MoeTokens]，AI 专属渐变保留于此。
abstract final class AiBrandTokens {
  static const pageBackground = MoeTokens.pageBackground;
  static const chatBackground = MoeTokens.pageBackground;
  static const primary = MoeTokens.primary;
  static const secondary = MoeTokens.secondary;
  static const accent = MoeTokens.accent;
  static const gradientPink = Color(0xFF8A2387);
  static const gradientCoral = Color(0xFFE94057);
  static const titleColor = Color(0xFF1F2430);

  static const userBubbleGradient = LinearGradient(
    colors: [gradientPink, gradientCoral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = MoeTokens.heroGradient;

  static const identityGradient = LinearGradient(
    colors: [Color(0x1A8A2387), Color(0x14E94057)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
