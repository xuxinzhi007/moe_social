import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/media_url.dart';
import 'motion/moe_shimmer.dart';

/// 统一的网络图片组件
/// 自动处理加载状态、错误处理和占位图
class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const NetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  /// 只按一边缩小解码。宽高同时传给缓存时，Android 会按目标矩形重编码整张原图，
  /// 大图会一直停在占位上；全屏查看器不走这套缩放，所以点开能看到原图。
  int? _cacheEdge() {
    int? edgeOf(double? value) {
      if (value == null || !value.isFinite || value <= 0) return null;
      return (value * 2).ceil().clamp(1, 2048);
    }

    return edgeOf(width) ?? edgeOf(height);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = imageUrl.isEmpty ? '' : resolveMediaUrl(imageUrl);
    final effective = resolved.isEmpty ? imageUrl : resolved;
    final cacheEdge = _cacheEdge();
    Widget imageWidget = CachedNetworkImage(
      imageUrl: effective,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheEdge,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(),
    );

    // 如果有圆角，添加裁剪
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// 默认占位图 — Shimmer 骨架屏，避免滚动时 spinner 闪烁
  Widget _defaultPlaceholder() {
    return MoeShimmer(
      child: Container(
        width: width,
        height: height,
        color: Colors.white,
      ),
    );
  }

  /// 默认错误占位图
  Widget _defaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF0F0F0),
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.grey[350],
        size: (width != null && height != null)
            ? (width! < height! ? width! * 0.3 : height! * 0.3)
            : 32,
      ),
    );
  }
}
