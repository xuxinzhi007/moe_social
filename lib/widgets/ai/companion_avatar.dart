import 'package:flutter/material.dart';

import '../../utils/media_url.dart';

/// 关系层伙伴头像：优先 [avatarUrl]。没有图、或还是默认表情时，用小星。
class CompanionAvatar extends StatelessWidget {
  static const defaultAsset = 'assets/branding/xiaoxing_mascot.png';

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
    final url = resolveMediaUrl(avatarUrl);
    final mascot = _usesMascot(emoji);
    final fallback = mascot
        ? Image.asset(
            defaultAsset,
            fit: BoxFit.contain,
            width: size,
            height: size,
          )
        : Text(
            emoji.trim(),
            style: TextStyle(fontSize: size * 0.48),
          );
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
          ? fallback
          : Image.network(
              url,
              fit: url.contains('xiaoxing_mascot')
                  ? BoxFit.contain
                  : BoxFit.cover,
              width: size,
              height: size,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }

  static bool _usesMascot(String emoji) {
    switch (emoji.trim()) {
      case '':
      case '🐾':
      case '🐥':
      case '⭐':
        return true;
      default:
        return false;
    }
  }
}
