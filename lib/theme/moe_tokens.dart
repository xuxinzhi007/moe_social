import 'package:flutter/material.dart';

/// Moe Social 全局视觉 token（SSOT）。
///
/// 采用「静奢雾蓝鸢尾（Refined Slate & Periwinkle）」调色板：
/// 低饱和、微暖云母底色、清晰墨色字阶与极细微环境光阴影，摒弃廉价 AI 霓虹渐变与重度发光阴影。
abstract final class MoeTokens {
  // ─── Color palette（精致产品级低饱和色阶）────────────────────────
  /// 核心品牌色：静谧鸢尾蓝（克制、现代、耐看，取代旧 #7F7FD5 塑料紫）
  static const Color primary = Color(0xFF5E6AD2);

  /// 次级品牌色：柔雾矢车菊蓝
  static const Color secondary = Color(0xFF7C8CF8);

  /// 轻点缀色：青瓷薄荷（低饱和度清透点缀）
  static const Color accent = Color(0xFF64D2C8);

  /// 辅助温暖色阶（降低刺眼荧光感，转为莫兰迪柔和调）
  static const Color pastelOrange = Color(0xFFF2994A);
  static const Color pastelTeal = Color(0xFF38B2AC);
  static const Color pastelBlue = Color(0xFF60A5FA);
  static const Color pastelPink = Color(0xFFEC7A9A);

  // ─── Neutral & Ink Hierarchy（墨色文字与中性灰阶）────────────────
  static const Color inkDark = Color(0xFF181A20);
  static const Color inkMuted = Color(0xFF646A7A);
  static const Color lineSoft = Color(0xFFE6E8F0);
  static const Color softLavenderBg = Color(0xFFF6F7FC);
  static const Color softChipBg = Color(0xFFF0F2F8);

  /// 微暖云母灰白底色，与纯白卡片形成自然呼吸层次，久看不累。
  static const Color pageBackground = Color(0xFFF6F7FB);

  /// 纯净高对比卡片表面。
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color titleText = Color(0xFF181A20);
  static const Color bodyText = Color(0xFF2E323D);
  static const Color caption = Color(0xFF525866);
  static const Color hintText = Color(0xFF8F96A6);

  // ─── Semantic colors（沉稳语义色）────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFE11D48);
  static const Color warning = Color(0xFFD97706);

  // ─── Game-specific colors ────────────────────────────────────────
  static const Color gamePageBackground = Color(0xFFFAF8F5);

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

  // ─── Feed media scale ───────────────────────────────────────────
  static const double postMediaFeedAspectRatio = 16 / 9;
  static const double postMediaFeedMinHeight = 120.0;
  static const double postMediaFeedMaxHeight = 200.0;

  static const double postMediaDetailAspectRatio = 16 / 9;
  static const double postMediaDetailMinHeight = 160.0;
  static const double postMediaDetailMaxHeight = 320.0;

  static const double postMediaFeedGridMaxHeight = 200.0;
  static const double postMediaDetailGridMaxHeight = 320.0;

  // ─── Typography scale ────────────────────────────────────────────
  static const double textXs = 11.0;
  static const double textSm = 12.0;
  static const double textBase = 14.0;
  static const double textMd = 15.0;
  static const double textLg = 17.0;
  static const double textXl = 20.0;
  static const double text2xl = 24.0;
  static const double text3xl = 28.0;

  // ─── Font weights ────────────────────────────────────────────────
  static const FontWeight fontWeightDisplay = FontWeight.w700;
  static const FontWeight fontWeightTitle = FontWeight.w700;
  static const FontWeight fontWeightSubtitle = FontWeight.w600;
  static const FontWeight fontWeightBody = FontWeight.w400;
  static const FontWeight fontWeightCaption = FontWeight.w500;

  // ─── Border radius scale ─────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 24.0;
  static const double radiusButton = 16.0;
  static const double radiusInput = 14.0;
  static const double radiusFull = 9999.0;

  // Legacy aliases (向后兼容)
  static const double radiusCard = radiusXl; // 20
  static const double radiusCardLarge = radius2xl; // 24
  static const double radiusIconBg = 14.0;

  // ─── Surface elevation system ────────────────────────────────────
  static const Color surface0 = pageBackground; // 页面背景
  static const Color surface1 = cardBackground; // 卡片
  static const Color surface2 = Color(0xFFFCFDFF); // 浮层 / Sheet
  static const Color surface3 = Color(0xFFFFFFFF); // 最高层 Tooltip / Dialog

  /// 1px 极细中性冷灰描边，塑造干净利落的现代卡片边界。
  static const Color surfaceBorder = Color(0xFFE6E8F0);

  // ─── Gradient system（同色系微光泽过渡，告别刺眼跨色霓虹）────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5E6AD2), Color(0xFF7280E8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF5E6AD2), Color(0xFF7C8CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 按钮微光泽渐变 — 主 CTA（深浅鸢尾同色系过渡）。
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [Color(0xFF5E6AD2), Color(0xFF6E7AE2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 柔和表面微渐变 — 次级背景。
  static const LinearGradient gradientSoft = LinearGradient(
    colors: [Color(0xFFF3F4FB), Color(0xFFEEF1FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 暖调柔和渐变。
  static const LinearGradient gradientKawaii = LinearGradient(
    colors: [Color(0xFFFDF2F6), Color(0xFFF3F4FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 清透雾面渐变。
  static const LinearGradient gradientMintBlush = LinearGradient(
    colors: [Color(0xFFF2FBF9), Color(0xFFF6F7FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color mintSoft = Color(0xFFD5F5F0);
  static const Color greyDisabled = Color(0xFFC4CAD4);

  /// 页面背景微渐变。
  static const LinearGradient gradientPageBg = LinearGradient(
    colors: [Color(0xFFF9FAFD), pageBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// 文字渐变遮罩。
  static const LinearGradient gradientText = LinearGradient(
    colors: [Color(0xFF4F59B8), Color(0xFF6E7AE2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadow system — 极低透明度自然环境光阴影 ──────────────────
  /// 小阴影 — 列表项、小卡片
  static List<BoxShadow> shadowSm() => const [
        BoxShadow(
          color: Color(0x0A181A20), // ~4% 冷黑环境光
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// 中阴影 — 卡片、浮层
  static List<BoxShadow> shadowMd() => const [
        BoxShadow(
          color: Color(0x0D181A20), // ~5% 冷黑环境光
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  /// 大阴影 — 弹窗、Sheet
  static List<BoxShadow> shadowLg() => const [
        BoxShadow(
          color: Color(0x14181A20), // ~8%
          blurRadius: 32,
          offset: Offset(0, 12),
        ),
      ];

  /// 按钮阴影 — 克制的底部承托阴影
  static List<BoxShadow> shadowButton() => [
        BoxShadow(
          color: primary.withValues(alpha: 0.18),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  /// Legacy — 使用 [shadowMd] 替代
  static List<BoxShadow> cardShadow({Color? tint, double blur = 12}) {
    return [
      BoxShadow(
        color: (tint ?? inkDark).withValues(alpha: 0.05),
        blurRadius: blur,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// 双层精致卡片阴影
  static List<BoxShadow> shadowCard() => const [
        BoxShadow(
          color: Color(0x08181A20),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x0A181A20),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ];

  /// 双层浮层阴影 — 弹窗 / Sheet 使用。
  static List<BoxShadow> shadowElevated() => const [
        BoxShadow(
          color: Color(0x0A181A20),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x12181A20),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ];

  /// 按钮微光晕阴影
  static List<BoxShadow> shadowGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  // ─── Glassmorphism / Blur ────────────────────────────────────────
  static const double blurHeavy = 24.0;
  static const double blurMedium = 16.0;
  static const double blurLight = 10.0;

  // ─── Motion / Animation ──────────────────────────────────────────
  static const Duration motionFadeDuration = Duration(milliseconds: 280);
  static const Duration motionStaggerStep = Duration(milliseconds: 50);
  static const double motionFadeOffset = 20;
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionMedium = Duration(milliseconds: 240);
  static const Duration motionSlow = Duration(milliseconds: 360);
  static const double motionPressScale = 0.97;
  static const double motionPressScaleStrong = 0.94;
  static const double motionSheetOffset = 20;
}
