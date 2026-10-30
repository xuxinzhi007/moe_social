import 'package:flutter/material.dart';

import 'moe_tokens.dart';

/// 可通过 [ThemeProvider] 动态主色的 Moe 主题扩展。
@immutable
class MoeTheme extends ThemeExtension<MoeTheme> {
  const MoeTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.pageBackground,
    required this.cardBackground,
    required this.surfaceBorder,
    required this.titleText,
    required this.hintText,
    required this.primaryGradient,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color pageBackground;
  final Color cardBackground;
  final Color surfaceBorder;
  final Color titleText;
  final Color hintText;
  final LinearGradient primaryGradient;

  factory MoeTheme.light({Color? primary}) {
    final p = primary ?? MoeTokens.primary;
    return MoeTheme(
      primary: p,
      secondary: MoeTokens.secondary,
      accent: MoeTokens.accent,
      pageBackground: MoeTokens.pageBackground,
      cardBackground: MoeTokens.cardBackground,
      surfaceBorder: MoeTokens.surfaceBorder,
      titleText: MoeTokens.titleText,
      hintText: MoeTokens.hintText,
      primaryGradient: LinearGradient(
        colors: [p, MoeTokens.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  factory MoeTheme.dark({Color? primary}) {
    final p = primary ?? MoeTokens.primary;
    return MoeTheme(
      primary: p,
      secondary: MoeTokens.secondary,
      accent: MoeTokens.accent,
      pageBackground: const Color(0xFF121212),
      cardBackground: const Color(0xFF1E1E1E),
      surfaceBorder: const Color(0x26FFFFFF),
      titleText: Colors.white,
      hintText: const Color(0xFF9E9E9E),
      primaryGradient: LinearGradient(
        colors: [p, MoeTokens.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static MoeTheme of(BuildContext context) {
    return Theme.of(context).extension<MoeTheme>() ?? MoeTheme.light();
  }

  @override
  MoeTheme copyWith({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? pageBackground,
    Color? cardBackground,
    Color? surfaceBorder,
    Color? titleText,
    Color? hintText,
    LinearGradient? primaryGradient,
  }) {
    return MoeTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      pageBackground: pageBackground ?? this.pageBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      titleText: titleText ?? this.titleText,
      hintText: hintText ?? this.hintText,
      primaryGradient: primaryGradient ?? this.primaryGradient,
    );
  }

  @override
  MoeTheme lerp(ThemeExtension<MoeTheme>? other, double t) {
    if (other is! MoeTheme) return this;
    return MoeTheme(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      pageBackground:
          Color.lerp(pageBackground, other.pageBackground, t) ?? pageBackground,
      cardBackground:
          Color.lerp(cardBackground, other.cardBackground, t) ?? cardBackground,
      surfaceBorder:
          Color.lerp(surfaceBorder, other.surfaceBorder, t) ?? surfaceBorder,
      titleText: Color.lerp(titleText, other.titleText, t) ?? titleText,
      hintText: Color.lerp(hintText, other.hintText, t) ?? hintText,
      primaryGradient: LinearGradient(
        colors: [
          Color.lerp(primaryGradient.colors.first,
                  other.primaryGradient.colors.first, t) ??
              primary,
          Color.lerp(primaryGradient.colors.last,
                  other.primaryGradient.colors.last, t) ??
              secondary,
        ],
        begin: primaryGradient.begin,
        end: primaryGradient.end,
      ),
    );
  }
}
