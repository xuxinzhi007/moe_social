import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../models/achievement_badge.dart';
import '../../services/achievement_service.dart';
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
  String _sortBy = 'recommended';
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
      result = result.where((b) => b.category == _selectedCategory).toList();
    }

    switch (_sortBy) {
      case 'recommended':
        result.sort((a, b) {
          final aScore = a.isUnlocked ? -1.0 : a.progress;
          final bScore = b.isUnlocked ? -1.0 : b.progress;
          return bScore.compareTo(aScore);
        });
        break;
      case 'unlocked':
        result.sort((a, b) {
          if (a.isUnlocked && !b.isUnlocked) return -1;
          if (!a.isUnlocked && b.isUnlocked) return 1;
          return b.progress.compareTo(a.progress);
        });
        break;
      case 'rarity':
        result.sort((a, b) => b.rarity.level.compareTo(a.rarity.level));
        break;
    }
    _filteredBadges = result;
  }

  void _showBadgeDetail(AchievementBadge badge) {
    showDialog(
      context: context,
      builder: (_) => BadgeDetailDialog(badge: badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('成就中心', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7F7FD5)),
            )
          : _currentUserId == null
              ? const Center(
                  child: Text(
                    '请先登录后查看成就进度',
                    style: TextStyle(color: Colors.black54, fontSize: 15),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF7F7FD5),
                  onRefresh: _loadAchievements,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      FadeInUp(
                        child: _buildStatisticsCard(),
                      ),
                      const SizedBox(height: 14),
                      FadeInUp(
                        delay: const Duration(milliseconds: 80),
                        child: _buildNearUnlockSection(),
                      ),
                      const SizedBox(height: 14),
                      FadeInUp(
                        delay: const Duration(milliseconds: 160),
                        child: _buildFilterSection(),
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
    final hint = percent < 10
        ? '先完成「首次登录」「首条动态」最容易起步'
        : '继续冲刺，离下一个成就不远了';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.2),
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
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('已解锁', '${stats.unlockedBadges}'),
              _stat('总成就', '${stats.totalBadges}'),
              _stat('完成率', '${percent.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.35),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildNearUnlockSection() {
    final nearUnlock = _allBadges
        .where((b) => !b.isUnlocked && b.progress > 0)
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    if (nearUnlock.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '即将解锁',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 102,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: nearUnlock.length > 5 ? 5 : nearUnlock.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final badge = nearUnlock[index];
                return Column(
                  children: [
                    BadgeCard(
                      badge: badge,
                      size: 70,
                      compact: true,
                      onTap: () => _showBadgeDetail(badge),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${badge.currentCount}/${badge.requiredCount}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分类', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('全部', null),
                ...BadgeCategory.values.map((c) => _buildCategoryChip(c.displayName, c)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _sortBy,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'recommended', child: Text('按推荐进度')),
              DropdownMenuItem(value: 'unlocked', child: Text('按解锁状态')),
              DropdownMenuItem(value: 'rarity', child: Text('按稀有度')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _sortBy = value;
                _filterBadges();
              });
            },
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
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = category;
            _filterBadges();
          });
        },
        selectedColor: const Color(0xFF7F7FD5).withValues(alpha: 0.2),
        backgroundColor: const Color(0xFFF5F7FA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildBadgeGrid() {
    if (_filteredBadges.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('这个分类暂时没有成就', style: TextStyle(color: Colors.black45)),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final count = width < 430 ? 3 : 4;
    final spacing = 12.0;
    final horizontalPadding = 0.0;
    final badgeSize = (width - 32 - horizontalPadding - (count - 1) * spacing) / count;

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredBadges.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        childAspectRatio: 0.78,
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
