import 'package:flutter/material.dart';

/// 礼物动效布局：全部使用 0~1 比例坐标，自动适配任意屏幕尺寸。
abstract final class GiftVfxLayout {
  /// 礼物落点（略偏上居中）。
  static const Offset anchorNorm = Offset(0.5, 0.42);

  /// 飞入起点（右下区域）。
  static const Offset flyStartNorm = Offset(0.82, 0.72);

  /// 比例坐标 → 像素（画布左上角为原点）。
  static Offset toPixels(Offset norm, Size size) =>
      Offset(norm.dx * size.width, norm.dy * size.height);

  /// 比例坐标 → [Alignment]（供 Align 组件使用，与屏幕尺寸无关）。
  static Alignment toAlignment(Offset norm) =>
      Alignment((norm.dx - 0.5) * 2, (norm.dy - 0.5) * 2);

  static Offset lerpNorm(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

  /// 当前画布尺寸：优先 LayoutBuilder，兜底 MediaQuery。
  static Size resolveSize(BuildContext context, BoxConstraints constraints) {
    if (constraints.hasBoundedWidth &&
        constraints.hasBoundedHeight &&
        constraints.maxWidth > 0 &&
        constraints.maxHeight > 0) {
      return Size(constraints.maxWidth, constraints.maxHeight);
    }
    final mq = MediaQuery.sizeOf(context);
    if (mq.width > 0 && mq.height > 0) return mq;
    return Size.zero;
  }
}
