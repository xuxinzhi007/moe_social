import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/gift.dart';
import 'motion/category_particle_vfx.dart';

/// 礼物图标：优先网络图，否则按分类渲染迷你粒子簇（替代 emoji 贴图）。
class GiftIconWidget extends StatelessWidget {
  final Gift gift;
  final double size;
  final bool enabled;
  final double pulse;

  const GiftIconWidget({
    super.key,
    required this.gift,
    this.size = 40,
    this.enabled = true,
    this.pulse = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    final url = gift.iconUrl;
    if (url != null) {
      return Opacity(
        opacity: enabled ? 1 : 0.45,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: (size * 2).ceil(),
            memCacheHeight: (size * 2).ceil(),
            maxWidthDiskCache: (size * 2).ceil(),
            maxHeightDiskCache: (size * 2).ceil(),
            placeholder: (_, __) => _particleFallback(opacity: 0.5),
            errorWidget: (_, __, ___) => _particleFallback(),
          ),
        ),
      );
    }
    return _particleFallback();
  }

  Widget _particleFallback({double opacity = 1}) {
    final coreCount = switch (gift.level) {
      GiftLevel.basic => 10,
      GiftLevel.medium => 12,
      GiftLevel.advanced => 14,
      GiftLevel.luxury => 16,
    };
    final points = CategoryParticleVfx.shapePoints(gift.category, coreCount);
    return Opacity(
      opacity: enabled ? opacity : opacity * 0.45,
      child: CustomPaint(
        painter: CategoryParticleClusterPainter(
          targets: points,
          primaryColor: gift.color,
          secondaryColor: gift.color.withValues(alpha: 0.6),
          converge: 1,
          pulse: pulse,
          expand: 0.12,
          seed: gift.id.hashCode,
          dominantShape: CategoryParticleVfx.dominantShape(gift.category),
        ),
        size: Size(size, size),
      ),
    );
  }
}
