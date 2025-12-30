import 'package:flutter/material.dart';
import '../models/achievement_badge.dart';

/// 单个徽章展示组件
class BadgeCard extends StatelessWidget {
  final AchievementBadge badge;
  final double size;
  final bool showProgress;
  final VoidCallback? onTap;

  const BadgeCard({
    super.key,
    required this.badge,
    this.size = 80.0,
    this.showProgress = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: badge.isUnlocked
                  ? badge.rarity.color.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: badge.isUnlocked ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 背景卡片
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badge.isUnlocked ? Colors.white : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: badge.isUnlocked
                      ? badge.rarity.color.withOpacity(0.5)
                      : Colors.grey[300]!,
                  width: badge.isUnlocked ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 徽章图标
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 稀有度背景
                      Container(
                        width: size * 0.6,
                        height: size * 0.6,
                        decoration: BoxDecoration(
                          color: badge.isUnlocked
                              ? badge.rarity.color.withOpacity(0.1)
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                      ),
                      // 表情符号
                      Text(
                        badge.emoji,
                        style: TextStyle(
                          fontSize: size * 0.3,
                          color: badge.isUnlocked ? null : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 徽章名称
                  Text(
                    badge.name,
                    style: TextStyle(
                      fontSize: size * 0.12,
                      fontWeight: FontWeight.bold,
                      color: badge.isUnlocked ? Colors.grey[800] : Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 稀有度标识
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: badge.isUnlocked
                          ? badge.rarity.color.withOpacity(0.1)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge.rarity.displayName,
                      style: TextStyle(
                        fontSize: size * 0.08,
                        fontWeight: FontWeight.w600,
                        color: badge.isUnlocked
                            ? badge.rarity.color
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 进度条（如果显示且未解锁）
            if (showProgress && !badge.isUnlocked && badge.progress > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: badge.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: badge.color,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 锁定遮罩
            if (!badge.isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      color: Colors.grey,
                      size: 16,
                    ),
                  ),
                ),
              ),

            // 新徽章标识
            if (badge.isUnlocked &&
                badge.unlockedAt != null &&
                DateTime.now().difference(badge.unlockedAt!).inDays < 3)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              badge.rarity.color.withOpacity(0.1),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 徽章图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: badge.rarity.color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: badge.rarity.color,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  badge.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 徽章名称和稀有度
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  badge.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badge.rarity.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge.rarity.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 描述
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // 达成条件
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    '达成条件',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.condition,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // 进度信息（如果未解锁）
            if (!badge.isUnlocked) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '进度',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${(badge.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: badge.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: badge.progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(badge.progress * badge.requiredCount).toInt()} / ${badge.requiredCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],

            // 解锁时间（如果已解锁）
            if (badge.isUnlocked && badge.unlockedAt != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badge.rarity.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: badge.rarity.color,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '已解锁',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${badge.unlockedAt!.year}年${badge.unlockedAt!.month}月${badge.unlockedAt!.day}日',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 关闭按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: badge.rarity.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '关闭',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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

  const BadgeGrid({
    super.key,
    required this.badges,
    this.badgeSize = 80.0,
    this.crossAxisCount = 4,
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
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return BadgeCard(
          badge: badge,
          size: badgeSize,
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badge.rarity.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: badge.rarity.color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          badge.emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}