import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../moe_input_field.dart';
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

  // ─── Semantic colors (委托 MoeTokens) ────────────────────────────
  static const Color surface = MoeTokens.cardBackground;
  static const Color bodyMuted = MoeTokens.inkMuted;
  static const Color success = MoeTokens.success;
  static const Color warning = MoeTokens.warning;
  static const Color danger = MoeTokens.danger;

  // ─── Shadow — 委托 MoeTokens ─────────────────────────────────────
  static List<BoxShadow> get cardShadow => MoeTokens.shadowMd();

  // ─── Typography ──────────────────────────────────────────────────
  static TextStyle get display => const TextStyle(
        fontSize: MoeTokens.text2xl,
        fontWeight: FontWeight.w800,
        color: MoeTokens.titleText,
        height: 1.2,
      );

  static TextStyle get title => const TextStyle(
        fontSize: MoeTokens.textLg,
        fontWeight: MoeTokens.fontWeightTitle,
        color: MoeTokens.titleText,
      );

  static TextStyle get body => const TextStyle(
        fontSize: MoeTokens.textBase,
        fontWeight: MoeTokens.fontWeightBody,
        color: MoeTokens.titleText,
        height: 1.45,
      );

  static TextStyle get caption => const TextStyle(
        fontSize: MoeTokens.textSm,
        fontWeight: MoeTokens.fontWeightCaption,
        color: MoeTokens.inkMuted,
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
    return MoeFieldDecoration.decorate(
      labelText: labelText,
      hintText: hintText,
      alignLabelWithHint: alignLabelWithHint,
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
