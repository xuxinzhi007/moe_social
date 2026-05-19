import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';

/// AI 酒馆模块：间距、圆角、阴影、文字样式（色彩见 [AiBrandTokens]）。
abstract final class AiTheme {
  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusSheet = 28;

  static const double pagePadding = 16;
  static const double cardPadding = 16;
  static const double sectionGap = 12;
  static const double sectionGapLg = 24;

  static const Color surface = Colors.white;
  static const Color bodyMuted = Color(0xFF757575);
  static const Color success = Color(0xFF00A86B);
  static const Color warning = Color(0xFFE6A700);
  static const Color danger = Color(0xFFE94057);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AiBrandTokens.primary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static TextStyle get display => const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AiBrandTokens.titleColor,
        height: 1.2,
      );

  static TextStyle get title => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AiBrandTokens.titleColor,
      );

  static TextStyle get body => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AiBrandTokens.titleColor,
        height: 1.45,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.grey.shade600,
        height: 1.35,
      );

  static TextStyle get mono => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFamily: 'monospace',
        color: AiBrandTokens.titleColor,
      );

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
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AiBrandTokens.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  static ButtonStyle primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AiBrandTokens.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
    );
  }

  static ButtonStyle dangerButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: danger,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
    );
  }
}
