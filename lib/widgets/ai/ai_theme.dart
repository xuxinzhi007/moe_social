import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import 'ai_brand_tokens.dart';

/// AI 酒馆模块：间距、圆角、阴影、文字样式（色彩见 [AiBrandTokens]）。
///
/// 基础间距/圆角/阴影委托给 [MoeTokens]，AI 专属值保留于此。
abstract final class AiTheme {
  // ─── Border radius ───────────────────────────────────────────────
  // 映射到 MoeTokens 标准阶梯
  static const double radiusSm = MoeTokens.radiusMd; // 12
  /// AI 专属中圆角（输入框、卡片等）
  static const double radiusAiCard = 18;
  static const double radiusLg = MoeTokens.radius2xl; // 24
  /// AI 专属 Sheet 圆角
  static const double radiusSheet = 28;

  // ─── Spacing ─────────────────────────────────────────────────────
  static const double pagePadding = MoeTokens.spaceLg; // 16
  static const double cardPadding = MoeTokens.spaceLg; // 16
  static const double sectionGap = MoeTokens.spaceMd; // 12
  static const double sectionGapLg = MoeTokens.space2xl; // 24

  // ─── Semantic colors ─────────────────────────────────────────────
  static const Color surface = MoeTokens.cardBackground;
  static const Color bodyMuted = Color(0xFF757575);
  static const Color success = Color(0xFF00A86B);
  static const Color warning = Color(0xFFE6A700);
  static const Color danger = Color(0xFFE94057);

  // ─── Shadow — 委托 MoeTokens ─────────────────────────────────────
  /// AI 卡片阴影（基于 MoeTokens.shadowMd，略微调整偏移以适配 AI 卡片）
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AiBrandTokens.primary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  // ─── Typography ──────────────────────────────────────────────────
  static TextStyle get display => const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AiBrandTokens.titleColor,
        height: 1.2,
      );

  static TextStyle get title => const TextStyle(
        fontSize: MoeTokens.textLg,
        fontWeight: MoeTokens.fontWeightTitle,
        color: AiBrandTokens.titleColor,
      );

  static TextStyle get body => const TextStyle(
        fontSize: MoeTokens.textBase,
        fontWeight: MoeTokens.fontWeightBody,
        color: AiBrandTokens.titleColor,
        height: 1.45,
      );

  static TextStyle get caption => TextStyle(
        fontSize: MoeTokens.textSm,
        fontWeight: MoeTokens.fontWeightCaption,
        color: Colors.grey.shade600,
        height: 1.35,
      );

  static TextStyle get mono => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFamily: 'monospace',
        color: AiBrandTokens.titleColor,
      );

  // ─── Input decoration ────────────────────────────────────────────
  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: const Color(0xFFF7F8FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusAiCard),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusAiCard),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusAiCard),
        borderSide: const BorderSide(color: AiBrandTokens.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg - 2, // 14
        vertical: MoeTokens.spaceMd, // 12
      ),
    );
  }

  // ─── Button styles ───────────────────────────────────────────────
  static ButtonStyle primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AiBrandTokens.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
      ),
    );
  }

  static ButtonStyle secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AiBrandTokens.primary,
      backgroundColor: AiBrandTokens.primary.withValues(alpha: 0.06),
      minimumSize: const Size.fromHeight(48),
      side: BorderSide(
        color: AiBrandTokens.primary.withValues(alpha: 0.34),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
      ),
    );
  }

  static ButtonStyle dangerButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: danger,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
      ),
    );
  }
}
