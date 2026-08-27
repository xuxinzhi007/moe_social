import 'package:flutter/material.dart';

/// 通用吸顶 [SliverPersistentHeaderDelegate] — 固定高度 + Material 底色，
/// 吸顶后轻微 elevation 提示层级。
///
/// 统一替代各页面私有实现（首页 Feed 筛选栏 / 社区分段栏等）。
class MoePinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  MoePinnedHeaderDelegate({
    required this.height,
    required this.child,
    required this.background,
    this.elevation = 0.5,
    this.shadowColor =
        const Color(0x26000000), // ui-hardcode: ignore const 默认值需字面量（black @ ~15%，.withValues 非 const）
  });

  /// 吸顶区固定高度（minExtent == maxExtent）。
  final double height;

  /// 吸顶内容。
  final Widget child;

  /// 吸顶底色（一般传页面背景色，避免透出下层内容）。
  final Color background;

  /// 吸顶时的 elevation。
  final double elevation;

  /// 阴影颜色。
  final Color shadowColor;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: background,
      elevation: overlapsContent || shrinkOffset > 0 ? elevation : 0,
      shadowColor: shadowColor,
      child: SizedBox(height: height, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant MoePinnedHeaderDelegate oldDelegate) {
    return height != oldDelegate.height ||
        background != oldDelegate.background ||
        elevation != oldDelegate.elevation ||
        shadowColor != oldDelegate.shadowColor ||
        child != oldDelegate.child;
  }
}
