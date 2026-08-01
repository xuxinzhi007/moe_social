import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';

/// AI 模块视觉 token；共享色值委托 [MoeTokens]，AI 专属渐变保留于此。
abstract final class AiBrandTokens {
  // ─── Colors — 委托 MoeTokens ─────────────────────────────────────
  static const pageBackground = MoeTokens.pageBackground;
  static const chatBackground = MoeTokens.pageBackground;
  static const primary = MoeTokens.primary;
  static const secondary = MoeTokens.secondary;
  static const accent = MoeTokens.accent;

  // ─── AI-exclusive accent / gradient colors ───────────────────────
  /// AI 气泡渐变起始色（紫红）
  static const gradientPink = Color(0xFF8A2387);

  /// AI 气泡渐变结束色（珊瑚红）
  static const gradientCoral = Color(0xFFE94057);

  /// AI 标题色（深灰蓝）
  static const titleColor = Color(0xFF1F2430);
  static const companionInkMuted = Color(0xFF6B6175);
  static const companionSurface = Color(0xFFFFFCFF);
  static const companionBorder = Color(0xFFE9DFF0);
  static const companionGlow = Color(0xFFFFE6EF);

  // ─── AI-exclusive gradients ──────────────────────────────────────
  /// 用户气泡渐变（紫红 → 珊瑚红）
  static const userBubbleGradient = LinearGradient(
    colors: [gradientPink, gradientCoral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = MoeTokens.heroGradient;

  /// AI 身份标识渐变（低透明度）
  static const identityGradient = LinearGradient(
    colors: [Color(0x1A8A2387), Color(0x14E94057)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
