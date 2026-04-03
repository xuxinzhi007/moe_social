import 'package:flutter/material.dart';
import '../../models/achievement_badge.dart';
import 'achievement_badge_visuals.dart';

/// 双层圆环 + 中心图标的徽章主体，带稀有度光晕
class AchievementBadgeMedallion extends StatelessWidget {
  const AchievementBadgeMedallion({
    super.key,
    required this.badge,
    required this.diameter,
    this.unlocked = true,
    this.showLockBadge = true,
  });

  final AchievementBadge badge;
  final double diameter;
  final bool unlocked;
  final bool showLockBadge;

  @override
  Widget build(BuildContext context) {
    final grad = badge.rarity.tierGradient;
    final ring = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: grad.last.withOpacity(0.42),
                  blurRadius: diameter * 0.22,
                  spreadRadius: -diameter * 0.02,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: EdgeInsets.all(diameter * 0.055),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unlocked
                ? [
                    Color.lerp(badge.color, Colors.white, 0.38)!,
                    badge.color.withOpacity(0.62),
                  ]
                : [
                    Colors.grey.shade400,
                    Colors.grey.shade300,
                  ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(unlocked ? 0.22 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Center(
              child: Icon(
                badge.badgeSymbol,
                size: diameter * 0.36,
                color: unlocked ? Colors.white : Colors.grey.shade600,
                shadows: unlocked
                    ? [
                        Shadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );

    // 锁标放在圆环内侧，避免负边距画出 Stack 外导致父级 Column/ListView 底部溢出
    return Stack(
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      children: [
        ring,
        if (!unlocked && showLockBadge)
          Positioned(
            right: diameter * 0.02,
            bottom: diameter * 0.02,
            child: Container(
              padding: EdgeInsets.all(diameter * 0.03),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.lock_rounded,
                size: diameter * 0.14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }
}

/// 稀有度角标（渐变字 + 细边框）
class AchievementRarityChip extends StatelessWidget {
  const AchievementRarityChip({
    super.key,
    required this.rarity,
    this.fontSize = 10,
    this.unlocked = true,
    this.dense = false,
  });

  final BadgeRarity rarity;
  final double fontSize;
  final bool unlocked;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final g = rarity.tierGradient;
    final pad = dense
        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    final label = Text(
      rarity.displayName,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: dense ? 0.2 : 0.4,
        color: Colors.white,
      ),
    );

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(dense ? 10 : 20),
        border: Border.all(
          width: unlocked ? 1.5 : 1,
          color: unlocked ? g.first.withOpacity(0.55) : Colors.grey.shade400,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: g.last.withOpacity(0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: unlocked
          ? ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) =>
                  LinearGradient(colors: g).createShader(bounds),
              child: label,
            )
          : Text(
              rarity.displayName,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
              ),
            ),
    );
  }
}
