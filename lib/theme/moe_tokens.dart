import 'package:flutter/material.dart';

/// Moe Social 全局视觉 token（SSOT）。
///
/// 新 UI 优先引用此类或 [MoeTheme] extension，避免散落硬编码色值。
abstract final class MoeTokens {
  // ─── Color palette ───────────────────────────────────────────────
  static const Color primary = Color(0xFF7F7FD5);
  static const Color secondary = Color(0xFF86A8E7);
  static const Color accent = Color(0xFF91EAE4);
  static const Color pastelOrange = Color(0xFFFFB347);
  static const Color pageBackground = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const Color titleText = Color(0xFF333333);
  static const Color bodyText = Colors.black87;
  static const Color caption = Color(0xFF3D3D50);
  static const Color hintText = Color(0xFF9E9E9E);

  // ─── Semantic colors ──────────────────────────────────────────────
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF6F00);

  // ─── Game-specific colors ────────────────────────────────────────
  static const Color gamePageBackground = Color(0xFFFFFBF5);

  // ─── Spacing scale (4px grid) ────────────────────────────────────
  /// 4px — 极小间距，图标内边距等
  static const double spaceXs = 4.0;
  /// 8px — 小间距，紧凑元素间
  static const double spaceSm = 8.0;
  /// 12px — 中小间距
  static const double spaceMd = 12.0;
  /// 16px — 标准间距，卡片内边距
  static const double spaceLg = 16.0;
  /// 20px — 大间距
  static const double spaceXl = 20.0;
  /// 24px — 区块间距
  static const double space2xl = 24.0;
  /// 32px — 段落间距
  static const double space3xl = 32.0;
  /// 40px — 页面级大间距
  static const double space4xl = 40.0;

  // ─── Typography scale ────────────────────────────────────────────
  /// 11px — 辅助微文字（角标、徽标）
  static const double textXs = 11.0;
  /// 12px — 注释/时间戳
  static const double textSm = 12.0;
  /// 14px — 正文基准
  static const double textBase = 14.0;
  /// 15px — 稍大正文
  static const double textMd = 15.0;
  /// 18px — 小标题
  static const double textLg = 18.0;
  /// 20px — 标题
  static const double textXl = 20.0;
  /// 24px — 大标题
  static const double text2xl = 24.0;
  /// 28px — 展示级标题
  static const double text3xl = 28.0;

  // ─── Font weights ────────────────────────────────────────────────
  /// 展示级标题（Display）
  static const FontWeight fontWeightDisplay = FontWeight.w700;
  /// 标题（Title）
  static const FontWeight fontWeightTitle = FontWeight.w700;
  /// 副标题（Subtitle）
  static const FontWeight fontWeightSubtitle = FontWeight.w600;
  /// 正文（Body）
  static const FontWeight fontWeightBody = FontWeight.w400;
  /// 注释/标签（Caption）
  static const FontWeight fontWeightCaption = FontWeight.w400;

  // ─── Border radius scale ─────────────────────────────────────────
  /// 8px — 小圆角，标签/Badge
  static const double radiusSm = 8.0;
  /// 12px — 中圆角
  static const double radiusMd = 12.0;
  /// 16px — 大圆角，小组件
  static const double radiusLg = 16.0;
  /// 20px — 超大圆角
  static const double radiusXl = 20.0;
  /// 24px — 极大圆角
  static const double radius2xl = 24.0;
  /// 25px — 按钮圆角
  static const double radiusButton = 25.0;
  /// 15px — 输入框圆角
  static const double radiusInput = 15.0;
  /// 9999px — 胶囊/圆形
  static const double radiusFull = 9999.0;

  // Legacy aliases (向后兼容)
  static const double radiusCard = radiusXl; // 20
  static const double radiusCardLarge = radius2xl; // 24
  static const double radiusIconBg = 14.0;

  // ─── Gradient ────────────────────────────────────────────────────
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

  // ─── Shadow system — 统一紫色调 rgba(127,127,213, α) ────────────
  /// 小阴影 — 列表项、小卡片
  static List<BoxShadow> shadowSm() => [
        BoxShadow(
          color: const Color(0x147F7FD5), // opacity ≈ 0.08
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// 中阴影 — 卡片、浮层（等同于 cardShadow）
  static List<BoxShadow> shadowMd() => [
        BoxShadow(
          color: const Color(0x147F7FD5), // opacity ≈ 0.08
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  /// 大阴影 — 弹窗、Sheet
  static List<BoxShadow> shadowLg() => [
        BoxShadow(
          color: const Color(0x1F7F7FD5), // opacity ≈ 0.12
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ];

  /// 按钮阴影 — CTA 按钮
  static List<BoxShadow> shadowButton() => [
        BoxShadow(
          color: const Color(0x667F7FD5), // opacity ≈ 0.40
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Legacy — 使用 [shadowMd] 替代
  static List<BoxShadow> cardShadow({Color? tint, double blur = 16}) {
    return [
      BoxShadow(
        color: (tint ?? primary).withValues(alpha: 0.08),
        blurRadius: blur,
        offset: const Offset(0, 8),
      ),
    ];
  }

  // ─── Motion / Animation ──────────────────────────────────────────
  /// 列表/区块入场动效（与 [FadeInUp] 默认值对齐）。
  static const Duration motionFadeDuration = Duration(milliseconds: 300);
  static const Duration motionStaggerStep = Duration(milliseconds: 60);
  static const double motionFadeOffset = 30;
}
