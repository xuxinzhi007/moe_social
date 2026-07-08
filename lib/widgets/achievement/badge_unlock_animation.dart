import 'package:flutter/material.dart';

import '../motion/category_particle_vfx.dart';
import '../motion/moe_vfx_profile.dart';
import '../../models/gift.dart';

/// 徽章解锁全屏动效（演示 / 弹窗用）— 粒子主体，无 emoji。
class BadgeUnlockAnimation extends StatefulWidget {
  final String badgeName;
  final IconData? badgeIcon;
  final Color badgeColor;
  final VoidCallback? onAnimationComplete;

  const BadgeUnlockAnimation({
    super.key,
    required this.badgeName,
    this.badgeIcon,
    required this.badgeColor,
    this.onAnimationComplete,
  });

  @override
  State<BadgeUnlockAnimation> createState() => _BadgeUnlockAnimationState();
}

class _BadgeUnlockAnimationState extends State<BadgeUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _textAnimation;
  late List<Offset> _shapePoints;

  @override
  void initState() {
    super.initState();
    _shapePoints = CategoryParticleVfx.shapePoints(GiftCategory.special, 28);
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
    ));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward().then((_) {
      widget.onAnimationComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = MoeVfxProfile.fromContext(context);
    final panelSize = 160.0 * profile.layoutScale;
    final coreCount = profile.scaledCoreCount(28);
    final shapePoints = coreCount > 0
        ? CategoryParticleVfx.shapePoints(GiftCategory.special, coreCount)
        : _shapePoints;

    if (profile.reduceMotion) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.badgeIcon != null)
              Icon(widget.badgeIcon, size: 56, color: widget.badgeColor),
            const SizedBox(height: 16),
            Text(
              widget.badgeName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.badgeColor,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: _scaleAnimation.value,
                child: SizedBox(
                  width: panelSize,
                  height: panelSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (shapePoints.isNotEmpty)
                        CustomPaint(
                          painter: CategoryParticleClusterPainter(
                            targets: shapePoints,
                            primaryColor: widget.badgeColor,
                            secondaryColor:
                                widget.badgeColor.withValues(alpha: 0.55),
                            converge: _scaleAnimation.value.clamp(0.0, 1.0),
                            pulse: _glowAnimation.value,
                            expand: _glowAnimation.value * 0.15,
                            seed: widget.badgeName.hashCode,
                            dominantShape: CategoryParticleVfx.dominantShape(
                              GiftCategory.special,
                            ),
                          ),
                          size: Size(panelSize, panelSize),
                        ),
                      if (widget.badgeIcon != null)
                        Icon(
                          widget.badgeIcon,
                          size: 52 * profile.layoutScale,
                          color: widget.badgeColor,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Opacity(
                opacity: _textAnimation.value,
                child: Column(
                  children: [
                    Text(
                      '徽章解锁',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.badgeColor.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.badgeName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
