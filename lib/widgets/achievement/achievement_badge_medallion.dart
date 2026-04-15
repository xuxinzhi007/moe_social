import 'package:flutter/material.dart';
import '../../../models/achievement_badge.dart';
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
  State<AchievementBadgeMedallion> createState() => _AchievementBadgeMedallionState();
}

class _AchievementBadgeMedallionState extends State<AchievementBadgeMedallion> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final size = widget.diameter;
    final isUnlocked = widget.unlocked;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..rotateZ(_rotationAnimation.value)
            ..scale(_scaleAnimation.value),
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
                      ? badge.rarity.tierGradient.last.withOpacity(_glowAnimation.value * 0.5)
                      : Colors.black.withOpacity(0.1),
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
                      ? [Colors.white, Colors.white.withOpacity(0.8)]
                      : [Colors.grey.shade100, Colors.grey.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 中心图标
                  Icon(
                    achievementIconForId(badge.id),
                    size: size * 0.5,
                    color: isUnlocked ? badge.color : Colors.grey.shade400,
                  ),
                  // 锁定标记
                  if (!isUnlocked && widget.showLockBadge)
                    Positioned(
                      child: Container(
                        width: size * 0.3,
                        height: size * 0.3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.6),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  // 稀有度光环（仅解锁状态）
                  if (isUnlocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: badge.rarity.tierGradient.first.withOpacity(0.6),
                            width: size * 0.02,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: badge.rarity.tierGradient.last.withOpacity(0.3),
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
      },
    );
  }
}
