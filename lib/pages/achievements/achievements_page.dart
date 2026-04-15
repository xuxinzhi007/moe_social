import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../models/achievement_badge.dart';
import '../../services/achievement_service.dart';
import '../../widgets/achievement/achievement_badge_medallion.dart';
import '../../widgets/achievement/achievement_badge_visuals.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final AchievementService _achievementService = AchievementService();
  List<AchievementBadge> _allBadges = [];
  List<AchievementBadge> _filteredBadges = [];
  BadgeCategory? _selectedCategory;
  bool _isLoading = true;
  String _sortBy = 'unlocked';

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    // 模拟用户ID，实际应用中应该从AuthService获取
    await _achievementService.initializeUserBadges('user_123');
    _allBadges = _achievementService.getUserBadges('user_123');
    _filterBadges();
    setState(() => _isLoading = false);
  }

  void _filterBadges() {
    _filteredBadges = _allBadges;

    // 按分类筛选
    if (_selectedCategory != null) {
      _filteredBadges = _filteredBadges
          .where((badge) => badge.category == _selectedCategory)
          .toList();
    }

    // 排序
    switch (_sortBy) {
      case 'unlocked':
        _filteredBadges.sort((a, b) {
          if (a.isUnlocked && !b.isUnlocked) return -1;
          if (!a.isUnlocked && b.isUnlocked) return 1;
          return 0;
        });
        break;
      case 'progress':
        _filteredBadges.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case 'rarity':
        _filteredBadges.sort((a, b) => b.rarity.level.compareTo(a.rarity.level));
        break;
    }
  }

  void _showBadgeDetail(AchievementBadge badge) {
    showDialog(
      context: context,
      builder: (context) => BadgeDetailDialog(badge: badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('成就中心', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF121212),
                    const Color(0xFF1E1E1E),
                  ]
                : [
                    const Color(0xFFF5F7FA),
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: Column(
          children: [
            // 成就统计卡片
            _buildStatisticsCard(),
            
            // 筛选和排序
            _buildFilterSection(),
            
            // 成就列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredBadges.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无成就',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : _buildBadgeGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _achievementService.getBadgeStatistics('user_123');
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7F7FD5),
            const Color(0xFF86A8E7),
            const Color(0xFF91EAE4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '成就进度',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                '已解锁',
                stats.unlockedBadges.toString(),
                const Color(0xFFE3F2FD),
              ),
              _buildStatItem(
                '总成就',
                stats.totalBadges.toString(),
                const Color(0xFFE3F2FD),
              ),
              _buildStatItem(
                '完成率',
                '${stats.completionPercentage.toInt()}%',
                const Color(0xFFE3F2FD),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: stats.completionPercentage / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '筛选与排序',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<BadgeCategory?>(
                  value: _selectedCategory,
                  hint: const Text('选择分类'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('全部分类'),
                    ),
                    ...BadgeCategory.values.map((category) => DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(category.categoryIcon, size: 16),
                              const SizedBox(width: 8),
                              Text(category.displayName),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      _filterBadges();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'unlocked',
                      child: Text('按解锁状态'),
                    ),
                    const DropdownMenuItem(
                      value: 'progress',
                      child: Text('按进度'),
                    ),
                    const DropdownMenuItem(
                      value: 'rarity',
                      child: Text('按稀有度'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                        _filterBadges();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double badgeSize;

    if (screenWidth < 480) {
      crossAxisCount = 3;
      badgeSize = (screenWidth - 48) / 3;
    } else if (screenWidth < 768) {
      crossAxisCount = 4;
      badgeSize = (screenWidth - 64) / 4;
    } else {
      crossAxisCount = 5;
      badgeSize = (screenWidth - 80) / 5;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredBadges.length,
      itemBuilder: (context, index) {
        final badge = _filteredBadges[index];
        return BadgeCard(
          badge: badge,
          size: badgeSize,
          onTap: () => _showBadgeDetail(badge),
        );
      },
    );
  }
}

class BadgeCard extends StatefulWidget {
  final AchievementBadge badge;
  final double size;
  final VoidCallback? onTap;

  const BadgeCard({
    super.key,
    required this.badge,
    required this.size,
    this.onTap,
  });

  @override
  State<BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<BadgeCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // 延迟启动动画，创造交错效果
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        _controller.reverse();
      },
      onTapUp: (_) {
        _controller.forward();
      },
      onTapCancel: () {
        _controller.forward();
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: badge.isUnlocked
                      ? badge.rarity.tierGradient.last.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // 背景渐变
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: badge.isUnlocked
                            ? [
                                Colors.white,
                                badge.color.withOpacity(0.1),
                              ]
                            : [
                                Colors.grey.shade50,
                                Colors.grey.shade100,
                              ],
                      ),
                      border: Border.all(
                        color: badge.isUnlocked
                            ? badge.rarity.tierGradient.first.withOpacity(0.4)
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    padding: EdgeInsets.all(widget.size * 0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 徽章图标
                        AchievementBadgeMedallion(
                          badge: badge,
                          diameter: widget.size * 0.6,
                          unlocked: badge.isUnlocked,
                        ),
                        const SizedBox(height: 8),
                        // 徽章名称
                        Text(
                          badge.name,
                          style: TextStyle(
                            fontSize: widget.size * 0.12,
                            fontWeight: FontWeight.w700,
                            color: badge.isUnlocked
                                ? theme.textTheme.titleMedium?.color
                                : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // 稀有度标签
                        AchievementRarityChip(
                          rarity: badge.rarity,
                          fontSize: widget.size * 0.08,
                          unlocked: badge.isUnlocked,
                        ),
                      ],
                    ),
                  ),
                  // 进度条
                  if (!badge.isUnlocked && badge.progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: (widget.size * badge.progress).clamp(0.0, widget.size),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                badge.color,
                                badge.color.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 锁定覆盖层
                  if (!badge.isUnlocked)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  // 新徽章标记
                  if (badge.isUnlocked &&
                      badge.unlockedAt != null &&
                      DateTime.now().difference(badge.unlockedAt!).inDays < 3)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
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
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class BadgeDetailDialog extends StatefulWidget {
  final AchievementBadge badge;

  const BadgeDetailDialog({super.key, required this.badge});

  @override
  State<BadgeDetailDialog> createState() => _BadgeDetailDialogState();
}

class _BadgeDetailDialogState extends State<BadgeDetailDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
    final gradient = badge.rarity.tierGradient;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradient.first.withOpacity(0.1),
                  Colors.white,
                  badge.color.withOpacity(0.05),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 装饰性图标
                Positioned(
                  top: 12,
                  right: 16,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 24,
                    color: gradient.last.withOpacity(0.3),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: 16,
                  child: Icon(
                    Icons.stars_rounded,
                    size: 20,
                    color: gradient.first.withOpacity(0.2),
                  ),
                ),
                // 内容
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 分类标签
                      Row(
                        children: [
                          Icon(
                            badge.category.categoryIcon,
                            size: 18,
                            color: badge.color.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            badge.category.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 徽章图标
                      AchievementBadgeMedallion(
                        badge: badge,
                        diameter: 120,
                        unlocked: badge.isUnlocked,
                      ),
                      if (!badge.isUnlocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '尚未解锁',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      // 徽章名称和稀有度
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              badge.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 12),
                          AchievementRarityChip(
                            rarity: badge.rarity,
                            fontSize: 12,
                            unlocked: badge.isUnlocked,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 徽章描述
                      Text(
                        badge.description,
                        style: TextStyle(
                          fontSize: 15,
                          lineHeight: 1.5,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // 达成条件
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '达成条件',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              badge.condition,
                              style: TextStyle(
                                fontSize: 14,
                                lineHeight: 1.4,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      // 进度信息
                      if (!badge.isUnlocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            children: [
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
                                  minHeight: 10,
                                  value: badge.progress.clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(badge.color),
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
                          ),
                        ),
                      // 解锁信息
                      if (badge.isUnlocked && badge.unlockedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  gradient.first.withOpacity(0.1),
                                  gradient.last.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.celebration_rounded,
                                  color: gradient.last,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '已解锁',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${badge.unlockedAt!.year}年${badge.unlockedAt!.month}月${badge.unlockedAt!.day}日',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // 关闭按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gradient.last,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            shadowColor: gradient.last.withOpacity(0.3),
                            elevation: 8,
                          ),
                          child: const Text(
                            '关闭',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}
