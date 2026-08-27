import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';

/// 全局未读角标 — 数字角标 / 纯红点两种模式，尺寸与颜色走 [MoeTokens]。
///
/// 用法：
/// ```dart
/// // 数字角标（>99 折叠为 99+）
/// MoeBadgeDot.count(count: 12)
///
/// // 纯红点
/// MoeBadgeDot.dot()
/// ```
class MoeBadgeDot extends StatelessWidget {
  /// 数字角标模式。[count] 需 > 0；> 99 时显示「99+」。
  const MoeBadgeDot.count({
    super.key,
    required this.count,
    this.color = MoeTokens.danger,
    this.borderColor,
    this.dotSize = _defaultDotSize,
  }) : _isDotOnly = false;

  /// 纯红点模式（不显示数字）。
  const MoeBadgeDot.dot({
    super.key,
    this.color = MoeTokens.danger,
    this.borderColor,
    this.dotSize = _defaultDotSize,
  })  : count = 0,
        _isDotOnly = true;

  static const double _defaultDotSize = 8.0;

  /// 未读数；仅数字模式生效。
  final int count;

  /// 角标底色，默认语义危险色 [MoeTokens.danger]。
  final Color color;

  /// 可选描边色（底栏图标上需要近白描边分隔时使用）。
  final Color? borderColor;

  /// 纯红点直径，默认 8px。
  final double dotSize;

  final bool _isDotOnly;

  @override
  Widget build(BuildContext context) {
    if (_isDotOnly) {
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.2)
              : null,
        ),
      );
    }

    // 防御：count 模式下非正数不渲染。
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: MoeTokens.surface1,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}
