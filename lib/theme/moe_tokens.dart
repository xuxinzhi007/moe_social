import 'package:flutter/material.dart';

/// Moe Social 全局视觉 token（SSOT）。
///
/// 新 UI 优先引用此类或 [MoeTheme] extension，避免散落硬编码色值。
abstract final class MoeTokens {
  static const Color primary = Color(0xFF7F7FD5);
  static const Color secondary = Color(0xFF86A8E7);
  static const Color accent = Color(0xFF91EAE4);
  static const Color pastelOrange = Color(0xFFFFB347);
  static const Color pageBackground = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const Color titleText = Color(0xFF333333);
  static const Color bodyText = Colors.black87;
  static const Color hintText = Color(0xFF9E9E9E);

  static const double radiusCard = 20;
  static const double radiusCardLarge = 24;
  static const double radiusButton = 30;
  static const double radiusIconBg = 14;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [primary, secondary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> cardShadow({Color? tint, double blur = 16}) {
    return [
      BoxShadow(
        color: (tint ?? primary).withValues(alpha: 0.08),
        blurRadius: blur,
        offset: const Offset(0, 8),
      ),
    ];
  }

  /// 列表/区块入场动效（与 [FadeInUp] 默认值对齐）。
  static const Duration motionFadeDuration = Duration(milliseconds: 300);
  static const Duration motionStaggerStep = Duration(milliseconds: 60);
  static const double motionFadeOffset = 30;
}
