import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 项目统一 SVG 图标组件（品牌门面图标体系的入口）。
///
/// 图标资产位于 `assets/icons/ui/`，均为 24×24 viewBox 的手写萌系 SVG，
/// 配色取自 `MoeTokens` 色系（静态 fill/stroke，无动画，flutter_svg 安全）。
///
/// 用法：
/// ```dart
/// MoeIcon(name: 'mic')                       // 原尺寸原色
/// MoeIcon(name: 'trophy', size: 32)          // 放大
/// MoeIcon(name: 'heart', color: Colors.grey) // 单色着色（srcIn）
/// ```
///
/// 兜底策略（绝不白屏）：
/// 1. [name] 不在注册表 → 直接渲染 Material Icons 近义图标；
/// 2. SVG 资源加载/解析失败 → 通过 `errorBuilder` 降级为同一 Material 图标。
///
/// 扩展方式：
/// 1. 在 `assets/icons/ui/` 新增 `<name>.svg`（24×24 viewBox、纯静态、<5KB）；
/// 2. 在 [_assets] 注册表补充 name→路径映射；
/// 3. 在 [_fallbacks] 补充对应的近义 Material [IconData]。
class MoeIcon extends StatelessWidget {
  const MoeIcon({
    super.key,
    required this.name,
    this.size = 24,
    this.color,
  });

  /// 图标名称（见 [_assets] 注册表），如 `mic` / `trophy` / `gift`。
  final String name;

  /// 渲染尺寸（宽=高），默认 24（与 SVG viewBox 一致）。
  final double size;

  /// 可选单色着色；非空时以 `ColorFilter.srcIn` 覆盖 SVG 全部颜色，
  /// 适合需要跟随主题的图标场景。留空则展示 SVG 原生双色系。
  final Color? color;

  /// SVG 资产目录。
  static const String _assetDir = 'assets/icons/ui';

  /// name → SVG 资源路径注册表（覆盖当前全量 12 枚图标）。
  static const Map<String, String> _assets = {
    'mic': '$_assetDir/mic.svg',
    'gift': '$_assetDir/gift.svg',
    'trophy': '$_assetDir/trophy.svg',
    'star': '$_assetDir/star.svg',
    'medal': '$_assetDir/medal.svg',
    'heart': '$_assetDir/heart.svg',
    'flame': '$_assetDir/flame.svg',
    'sparkle': '$_assetDir/sparkle.svg',
    'crown': '$_assetDir/crown.svg',
    'diamond': '$_assetDir/diamond.svg',
    'calendar': '$_assetDir/calendar.svg',
    'bolt': '$_assetDir/bolt.svg',
  };

  /// name → Material Icons 近义图标兜底映射。
  static const Map<String, IconData> _fallbacks = {
    'mic': Icons.mic_rounded,
    'gift': Icons.card_giftcard_rounded,
    'trophy': Icons.emoji_events_rounded,
    'star': Icons.star_rounded,
    'medal': Icons.military_tech_rounded,
    'heart': Icons.favorite_rounded,
    'flame': Icons.local_fire_department_rounded,
    'sparkle': Icons.auto_awesome_rounded,
    'crown': Icons.workspace_premium_rounded,
    'diamond': Icons.diamond_rounded,
    'calendar': Icons.calendar_month_rounded,
    'bolt': Icons.bolt_rounded,
  };

  /// 全部已注册图标名称（供外部校验/遍历）。
  static Iterable<String> get registeredNames => _assets.keys;

  @override
  Widget build(BuildContext context) {
    final asset = _assets[name];
    if (asset == null) return _fallback();

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  /// 兜底渲染：Material Icons 近义图标；未知 name 退化为帮助图标。
  Widget _fallback() {
    return Icon(
      _fallbacks[name] ?? Icons.help_outline_rounded,
      size: size,
      color: color,
    );
  }
}
