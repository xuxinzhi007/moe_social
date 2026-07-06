import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../models/achievement_badge.dart';
import '../../services/achievement_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/achievement_badge_display.dart';
import '../../widgets/fade_in_up.dart';

class AchievementsPage extends StatefulWidget {
  final String? userId;

  const AchievementsPage({super.key, this.userId});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final AchievementService _achievementService = AchievementService();
  List<AchievementBadge> _allBadges = <AchievementBadge>[];
  List<AchievementBadge> _filteredBadges = <AchievementBadge>[];
  BadgeCategory? _selectedCategory;
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final uid = widget.userId ?? AuthService.currentUser;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
        _allBadges = <AchievementBadge>[];
        _filteredBadges = <AchievementBadge>[];
        _isLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _currentUserId = uid;
      });
    }

    await _achievementService.initializeUserBadges(uid);
    _allBadges = _achievementService.getUserBadges(uid);
    _filterBadges();

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _filterBadges() {
    var result = [..._allBadges];
    if (_selectedCategory != null) {
      result = result.where((badge) => badge.category == _selectedCategory).toList();
    }

    result.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) {
        return a.isUnlocked ? -1 : 1;
      }
      if (!a.isUnlocked && !b.isUnlocked) {
        return b.progress.compareTo(a.progress);
      }
      return b.rarity.level.compareTo(a.rarity.level);
    });

    _filteredBadges = result;
  }

  void _showBadgeDetail(AchievementBadge badge) {
    showDialog<void>(
      context: context,
      builder: (_) => BadgeDetailDialog(badge: badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text(
          '成就中心',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: MoeTokens.pageBackground,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MoeTokens.primary),
            )
          : _currentUserId == null
              ? const Center(
                  child: Text(
                    '请先登录后查看成就进度',
                    style: TextStyle(color: Colors.black54, fontSize: 15),
                  ),
                )
              : RefreshIndicator(
                  color: MoeTokens.primary,
                  onRefresh: _loadAchievements,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      FadeInUp(child: _buildStatisticsCard()),
                      const SizedBox(height: 12),
                      FadeInUp(
                        delay: const Duration(milliseconds: 80),
                        child: _buildNearUnlockSection(),
                      ),
                      const SizedBox(height: 12),
                      FadeInUp(
                        delay: const Duration(milliseconds: 160),
                        child: _buildCategorySection(),
                      ),
                      const SizedBox(height: 14),
                      FadeInUp(
                        delay: const Duration(milliseconds: 240),
                        child: _buildBadgeGrid(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _achievementService.getBadgeStatistics(_currentUserId!);
    final percent = stats.completionPercentage;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MoeTokens.primary, MoeTokens.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: MoeTokens.primary.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的成就进度',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _statTile('已解锁', '${stats.unlockedBadges}')),
              const SizedBox(width: 10),
              Expanded(child: _statTile('总成就', '${stats.totalBadges}')),
              const SizedBox(width: 10),
              Expanded(child: _statTile('完成率', '${percent.toStringAsFixed(0)}%')),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.28),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearUnlockSection() {
    final nearUnlock = _allBadges
        .where((badge) => !badge.isUnlocked && badge.progress > 0)
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    if (nearUnlock.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = nearUnlock.take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MoeTokens.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '即将解锁',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '优先完成进度最高的 3 个',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.42),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: _buildNearUnlockItem(items[i])),
                if (i != items.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearUnlockItem(AchievementBadge badge) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showBadgeDetail(badge),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: Column(
          children: [
            BadgeCard(
              badge: badge,
              size: 62,
              compact: true,
              onTap: () => _showBadgeDetail(badge),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${badge.currentCount}/${badge.requiredCount}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MoeTokens.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分类',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '当前展示 ${_filteredBadges.length} 个成就',
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('全部', null),
                ...BadgeCategory.values.map((category) {
                  return _buildCategoryChip(category.displayName, category);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, BadgeCategory? category) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? MoeTokens.primary : Colors.black87,
          ),
        ),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = category;
            _filterBadges();
          });
        },
        selectedColor: MoeTokens.primary.withValues(alpha: 0.14),
        backgroundColor: const Color(0xFFF7F8FC),
        side: BorderSide(
          color: selected
              ? MoeTokens.primary.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.06),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildBadgeGrid() {
    if (_filteredBadges.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            '这个分类暂时没有成就',
            style: TextStyle(color: Colors.black45),
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final count = width < 420 ? 2 : width < 720 ? 3 : 4;
    final spacing = width < 420 ? 10.0 : 12.0;
    final badgeSize = (width - 32 - (count - 1) * spacing) / count;

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredBadges.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        childAspectRatio: width < 420 ? 0.82 : width < 720 ? 0.8 : 0.78,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemBuilder: (_, index) {
        final badge = _filteredBadges[index];
        return BadgeCard(
          badge: badge,
          size: badgeSize.clamp(72.0, 110.0),
          dense: true,
          onTap: () => _showBadgeDetail(badge),
        );
      },
    );
  }
}
