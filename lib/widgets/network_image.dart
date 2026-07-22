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

  @override
  Widget build(BuildContext context) {
    final resolved =
        imageUrl.isEmpty ? '' : resolveMediaUrl(imageUrl);
    final effective = resolved.isEmpty ? imageUrl : resolved;
    Widget imageWidget = CachedNetworkImage(
      imageUrl: effective,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _defaultErrorWidget(),
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
