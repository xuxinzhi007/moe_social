import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/moe_tokens.dart';

/// 统一的 shimmer 骨架包裹器，与 [skeleton_loading.dart] 配色一致。
class MoeShimmer extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const MoeShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1200),
  });

  static const Color defaultBaseColor = Color(0xFFE0E0E0);
  static const Color defaultHighlightColor = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? defaultBaseColor,
      highlightColor: highlightColor ?? defaultHighlightColor,
      period: period,
      child: child,
    );
  }
}

/// 单行占位块，供 AI / 通用 loading 骨架复用。
class MoeShimmerBlock extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const MoeShimmerBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = MoeTokens.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
