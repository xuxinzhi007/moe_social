import 'package:flutter/material.dart';

/// 关系层伙伴头像：优先 [avatarUrl]，否则 emoji 回退。
class CompanionAvatar extends StatelessWidget {
  const CompanionAvatar({
    super.key,
    required this.emoji,
    this.avatarUrl = '',
    this.size = 80,
    this.borderRadius,
    this.backgroundColor,
  });

  final String emoji;
  final String avatarUrl;
  final double size;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.32);
    final url = avatarUrl.trim();
    final face = emoji.trim().isNotEmpty ? emoji.trim() : '🐾';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.78),
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url.isEmpty
          ? Text(face, style: TextStyle(fontSize: size * 0.48))
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => Text(
                face,
                style: TextStyle(fontSize: size * 0.48),
              ),
            ),
    );
  }
}
