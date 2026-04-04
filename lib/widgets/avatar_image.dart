import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/media_url.dart';

/// 简化的网络头像组件
/// 使用Flutter内置组件，自动处理错误和加载状态
class NetworkAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final IconData placeholderIcon;
  final Color? placeholderColor;

  const NetworkAvatarImage({
    super.key,
    this.imageUrl,
    this.radius = 50,
    this.backgroundColor,
    this.placeholderIcon = Icons.person,
    this.placeholderColor,
  });

  @override
  Widget build(BuildContext context) {
    // 如果URL为空，显示占位图
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    final resolved = resolveMediaUrl(imageUrl);

    // 检查是否是base64 data URI
    if (resolved.startsWith('data:image')) {
      return _buildDataUriAvatarFrom(resolved);
    }

    if (resolved.isEmpty) {
      return _buildPlaceholder();
    }

    // 使用CachedNetworkImage加载图片，自动缓存
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      ),
    );
  }

  /// 构建占位图
  Widget _buildPlaceholder() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      child: Icon(
        placeholderIcon,
        size: radius,
        color: placeholderColor ?? Colors.grey[600],
      ),
    );
  }

  /// 构建base64图片
  Widget _buildDataUriAvatarFrom(String dataUri) {
    try {
      final base64String = dataUri.split(',')[1];
      final bytes = base64Decode(base64String);
      
      return ClipOval(
        child: Image.memory(
          bytes,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // base64图片加载失败时显示占位图
            return _buildPlaceholder();
          },
        ),
      );
    } catch (e) {
      // 解析失败，显示占位图
      return _buildPlaceholder();
    }
  }
}
