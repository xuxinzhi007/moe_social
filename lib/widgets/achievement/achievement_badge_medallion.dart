import 'package:flutter/material.dart';

import '../../../models/achievement_badge.dart';
import '../motion/moe_motion.dart';
import 'achievement_badge_visuals.dart';

class AchievementBadgeMedallion extends StatefulWidget {
  final AchievementBadge badge;
  final double diameter;
  final bool unlocked;
  final bool showLockBadge;

  const AchievementBadgeMedallion({
    super.key,
    required this.badge,
    required this.diameter,
    required this.unlocked,
    this.showLockBadge = true,
  });

  @override
  State<AchievementBadgeMedallion> createState() =>
      _AchievementBadgeMedallionState();
}

class _AchievementBadgeMedallionState extends State<AchievementBadgeMedallion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  bool get _shouldAnimate => widget.unlocked && !moeReduceMotion(context);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.5, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant AchievementBadgeMedallion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimationState();
  }

  void _syncAnimationState() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
      return;
    }
    if (_controller.isAnimating) {
      _controller.stop();
    }
    if (_controller.value != 0) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final size = widget.diameter;
    final isUnlocked = widget.unlocked;

    final content = Transform(
      transform: Matrix4.identity()
        ..rotateZ(_rotationAnimation.value)
        ..scaleByDouble(_scaleAnimation.value, _scaleAnimation.value, 1, 1),
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isUnlocked
                ? badge.rarity.tierGradient
                : [Colors.grey.shade300, Colors.grey.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isUnlocked
                  ? badge.rarity.tierGradient.last.withValues(
                      alpha: _glowAnimation.value * 0.5,
                    )
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: size * 0.2,
              spreadRadius: size * 0.05,
            ),
          ],
        ),
        padding: EdgeInsets.all(size * 0.1),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isUnlocked
                  ? [Colors.white, Colors.white.withValues(alpha: 0.8)]
                  : [Colors.grey.shade100, Colors.grey.shade200],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                achievementIconForId(badge.id),
                size: size * 0.5,
                color: isUnlocked ? badge.color : Colors.grey.shade400,
              ),
              if (!isUnlocked && widget.showLockBadge)
                Positioned(
                  child: Container(
                    width: size * 0.3,
                    height: size * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (isUnlocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: badge.rarity.tierGradient.first.withValues(
                          alpha: 0.6,
                        ),
                        width: size * 0.02,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: badge.rarity.tierGradient.last.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: size * 0.1,
                          spreadRadius: size * 0.02,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!_shouldAnimate) {
      return content;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => child!,
      child: content,
    );
  }
}
