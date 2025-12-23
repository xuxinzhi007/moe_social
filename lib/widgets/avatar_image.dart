import 'dart:convert';
import 'package:flutter/material.dart';

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

    // 检查是否是base64 data URI
    if (imageUrl!.startsWith('data:image')) {
      return _buildDataUriAvatar();
    }

    // 使用Image.network加载图片，通过errorBuilder处理错误
    // 这样可以确保图片加载成功时不会显示占位图
    return ClipOval(
      child: Image.network(
        imageUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            // 加载完成，显示图片
            return child;
          }
          // 加载中，显示占位图
          return _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          // 加载失败，显示占位图
          return _buildPlaceholder();
        },
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
  Widget _buildDataUriAvatar() {
    try {
      final base64String = imageUrl!.split(',')[1];
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
