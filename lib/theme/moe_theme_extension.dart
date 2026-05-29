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
    required this.primaryGradient,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color pageBackground;
  final Color cardBackground;
  final LinearGradient primaryGradient;

  factory MoeTheme.light({Color? primary}) {
    final p = primary ?? MoeTokens.primary;
    return MoeTheme(
      primary: p,
      secondary: MoeTokens.secondary,
      accent: MoeTokens.accent,
      pageBackground: MoeTokens.pageBackground,
      cardBackground: MoeTokens.cardBackground,
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
    LinearGradient? primaryGradient,
  }) {
    return MoeTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      pageBackground: pageBackground ?? this.pageBackground,
      cardBackground: cardBackground ?? this.cardBackground,
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
