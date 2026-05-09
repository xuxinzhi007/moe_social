import 'package:flutter/material.dart';
import '../models/achievement_badge.dart';
import 'achievement/achievement_badge_medallion.dart';
import 'achievement/achievement_badge_visuals.dart';

class AchievementRarityChip extends StatelessWidget {
  final BadgeRarity rarity;
  final double fontSize;
  final bool unlocked;

  const AchievementRarityChip({
    super.key,
    required this.rarity,
    required this.fontSize,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 1.2,
        vertical: fontSize * 0.3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rarity.tierGradient,
        ),
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Text(
        rarity.displayName,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


/// 单个徽章展示组件
class BadgeCard extends StatelessWidget {
  final AchievementBadge badge;
  final double size;
  final bool showProgress;
  final VoidCallback? onTap;

  /// 横向滑动条：固定 **正方形**，只展示奖章（不竖条挤压），点击查看详情。
  final bool compact;

  /// 个人中心等 **有高度上限** 的横向列表：收紧内边距与字号，避免 RenderFlex 溢出。
  final bool dense;

  const BadgeCard({
    super.key,
    required this.badge,
    this.size = 80.0,
    this.showProgress = true,
    this.onTap,
    this.compact = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    if (dense) {
      return _buildDense(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final medalD = (size * 0.74).clamp(28.0, size * 0.78);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: badge.isUnlocked
                        ? badge.rarity.tierGradient.last.withOpacity(0.2)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: badge.isUnlocked
                          ? [Colors.white, badge.color.withOpacity(0.08)]
                          : [Colors.grey.shade50, Colors.grey.shade200],
                    ),
                    border: Border.all(
                      color: badge.isUnlocked
                          ? badge.rarity.tierGradient.first.withOpacity(0.4)
                          : Colors.grey.shade300,
                    ),
                  ),
                  padding: EdgeInsets.all(size * 0.06),
                  child: Center(
                    child: AchievementBadgeMedallion(
                      badge: badge,
                      diameter: medalD,
                      unlocked: badge.isUnlocked,
                    ),
                  ),
                ),
              ),
            ),
            if (badge.isUnlocked &&
                badge.unlockedAt != null &&
                DateTime.now().difference(badge.unlockedAt!).inDays < 3)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDense(BuildContext context) {
    final theme = Theme.of(context);
    final medalSize = size * 0.5;
    final nameFont = (size * 0.11).clamp(9.0, 11.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: badge.isUnlocked
                  ? badge.rarity.tierGradient.last.withOpacity(0.18)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: badge.isUnlocked
                        ? [Colors.white, badge.color.withOpacity(0.05)]
                        : [Colors.grey.shade50, Colors.grey.shade100],
                  ),
                  border: Border.all(
                    color: badge.isUnlocked
                        ? badge.rarity.tierGradient.first.withOpacity(0.35)
                        : Colors.grey.shade300,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(5, 6, 5, 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AchievementBadgeMedallion(
                      badge: badge,
                      diameter: medalSize,
                      unlocked: badge.isUnlocked,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge.name,
                      style: TextStyle(
                        fontSize: nameFont,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: badge.isUnlocked
                            ? theme.textTheme.titleMedium?.color
                            : Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    AchievementRarityChip(
                      rarity: badge.rarity,
                      fontSize: 8,
                      unlocked: badge.isUnlocked,
                    ),
                  ],
                ),
              ),
              if (showProgress && !badge.isUnlocked && badge.progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    color: Colors.grey.shade200,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: badge.progress.clamp(0.0, 1.0),
                      child: Container(
                        color: badge.color,
                      ),
                    ),
                  ),
                ),
              if (!badge.isUnlocked)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              if (badge.isUnlocked &&
                  badge.unlockedAt != null &&
                  DateTime.now().difference(badge.unlockedAt!).inDays < 3)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final theme = Theme.of(context);
    final medalRatio = size < 80 ? 0.56 : 0.62;
    final medalSize = size * medalRatio;
    final verticalPad = size < 80
        ? const EdgeInsets.fromLTRB(6, 8, 6, 6)
        : const EdgeInsets.fromLTRB(8, 10, 8, 8);
    final nameMaxLines = size < 80 ? 1 : 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: badge.isUnlocked
                  ? badge.rarity.tierGradient.last.withOpacity(0.22)
                  : Colors.black.withOpacity(0.05),
              blurRadius: badge.isUnlocked ? 14 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: badge.isUnlocked
                        ? [
                            Colors.white,
                            badge.color.withOpacity(0.06),
                          ]
                        : [
                            Colors.grey.shade50,
                            Colors.grey.shade100,
                          ],
                  ),
                  border: Border.all(
                    color: badge.isUnlocked
                        ? badge.rarity.tierGradient.first.withOpacity(0.35)
                        : Colors.grey.shade300,
                    width: badge.isUnlocked ? 1.5 : 1,
                  ),
                ),
                padding: verticalPad,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AchievementBadgeMedallion(
                      badge: badge,
                      diameter: medalSize,
                      unlocked: badge.isUnlocked,
                    ),
                    SizedBox(height: size * 0.03),
                    Text(
                      badge.name,
                      style: TextStyle(
                        fontSize: (size * 0.125).clamp(11.0, 13.0),
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: badge.isUnlocked
                            ? theme.textTheme.titleMedium?.color
                            : Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: nameMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    AchievementRarityChip(
                      rarity: badge.rarity,
                      fontSize: (size * 0.085).clamp(9.0, 10.0),
                      unlocked: badge.isUnlocked,
                    ),
                  ],
                ),
              ),

              if (showProgress && !badge.isUnlocked && badge.progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: badge.progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              badge.color,
                              badge.color.withOpacity(0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              if (!badge.isUnlocked)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              if (badge.isUnlocked &&
                  badge.unlockedAt != null &&
                  DateTime.now().difference(badge.unlockedAt!).inDays < 3)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 徽章详情弹窗
class BadgeDetailDialog extends StatelessWidget {
  final AchievementBadge badge;

  const BadgeDetailDialog({
    super.key,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final g = badge.rarity.tierGradient;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              g.first.withOpacity(0.14),
              Colors.white,
              badge.color.withOpacity(0.06),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 12,
              right: 16,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: g.last.withOpacity(0.35),
              ),
            ),
            Positioned(
              bottom: 80,
              left: 14,
              child: Icon(
                Icons.stars_rounded,
                size: 18,
                color: g.first.withOpacity(0.25),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        badge.category.categoryIcon,
                        size: 18,
                        color: badge.color.withOpacity(0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badge.category.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AchievementBadgeMedallion(
                    badge: badge,
                    diameter: 112,
                    unlocked: badge.isUnlocked,
                    showLockBadge: false,
                  ),
                  if (!badge.isUnlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            '尚未解锁',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          badge.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AchievementRarityChip(
                        rarity: badge.rarity,
                        fontSize: 11,
                        unlocked: badge.isUnlocked,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    badge.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '达成条件',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          badge.condition,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (!badge.isUnlocked) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '进度',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${(badge.progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: badge.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: badge.progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(badge.color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(badge.progress * badge.requiredCount).toInt()} / ${badge.requiredCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (badge.isUnlocked && badge.unlockedAt != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            badge.rarity.tierGradient.first.withOpacity(0.12),
                            badge.rarity.tierGradient.last.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.celebration_rounded,
                            color: badge.rarity.tierGradient.last,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '已解锁',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${badge.unlockedAt!.year}年${badge.unlockedAt!.month}月${badge.unlockedAt!.day}日',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: g),
                        boxShadow: [
                          BoxShadow(
                            color: g.last.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                '关闭',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 徽章网格展示组件
class BadgeGrid extends StatelessWidget {
  final List<AchievementBadge> badges;
  final double badgeSize;
  final int crossAxisCount;
  final bool showProgress;

  const BadgeGrid({
    super.key,
    required this.badges,
    this.badgeSize = 80.0,
    this.crossAxisCount = 4,
    this.showProgress = true,
  });

  void _showBadgeDetail(BuildContext context, AchievementBadge badge) {
    showDialog(
      context: context,
      builder: (context) => BadgeDetailDialog(badge: badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return BadgeCard(
          badge: badge,
          size: badgeSize,
          showProgress: showProgress,
          onTap: () => _showBadgeDetail(context, badge),
        );
      },
    );
  }
}

/// 迷你徽章组件（用于用户头像旁等小空间）
class MiniBadge extends StatelessWidget {
  final AchievementBadge badge;
  final double size;

  const MiniBadge({
    super.key,
    required this.badge,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final g = badge.rarity.tierGradient;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: g),
        boxShadow: [
          BoxShadow(
            color: g.last.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.1),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(
          badge.badgeSymbol,
          size: size * 0.48,
          color: badge.color,
        ),
      ),
    );
  }
}
