import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';

/// AI 模块视觉 token；共享色值全部委托 [MoeTokens]（Airy Moe 唯一主题基座），
/// 仅保留少量 AI 专属点缀渐变。
abstract final class AiBrandTokens {
  // ─── Colors — 委托 MoeTokens (Airy Moe) ──────────────────────────
  static const pageBackground = MoeTokens.pageBackground;
  static const chatBackground = MoeTokens.pageBackground;
  static const primary = MoeTokens.primary;
  static const secondary = MoeTokens.secondary;
  static const accent = MoeTokens.accent;

  /// AI 标题色（统一对齐 [MoeTokens.titleText]）
  static const titleColor = MoeTokens.titleText;
  static const companionInkMuted = MoeTokens.inkMuted;
  static const companionSurface = MoeTokens.surface1;
  static const companionBorder = MoeTokens.surfaceBorder;
  static const companionGlow = Color(0xFFFFE6EF);

  // ─── AI-exclusive accent / gradient colors ───────────────────────
  /// AI 气泡渐变起始色（薰衣草紫）
  static const gradientPink = MoeTokens.primary;

  /// AI 气泡渐变结束色（雾面蓝）
  static const gradientCoral = MoeTokens.secondary;

  // ─── AI-exclusive gradients ──────────────────────────────────────
  /// 用户气泡渐变（对齐 Airy Moe 品牌主轴）
  static const userBubbleGradient = MoeTokens.primaryGradient;

  static const heroGradient = MoeTokens.heroGradient;

  /// AI 身份标识渐变（低透明度）
  static const identityGradient = LinearGradient(
    colors: [Color(0x1A7F7FD5), Color(0x1486A8E7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
