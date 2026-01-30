import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_level_provider.dart';
import '../providers/checkin_provider.dart';
import '../widgets/fade_in_up.dart';

/// 用户等级页面 - 遵循 Moe Social Design Language 梦幻风格
class UserLevelPage extends StatefulWidget {
  final String userId;

  const UserLevelPage({
    super.key,
    required this.userId,
  });

  @override
  State<UserLevelPage> createState() => _UserLevelPageState();
}

class _UserLevelPageState extends State<UserLevelPage>
    with TickerProviderStateMixin {
  late AnimationController _levelUpController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }

  void _setupAnimations() {
    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _levelUpController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _levelUpController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final levelProvider = context.read<UserLevelProvider>();
      levelProvider.loadUserLevel(widget.userId);
    });
  }

  @override
  void dispose() {
    _levelUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<UserLevelProvider>(
        builder: (context, levelProvider, child) {
          // 监听升级状态
          if (levelProvider.isLevelingUp) {
            _levelUpController.forward().then((_) {
              levelProvider.completeLevelUp();
              _levelUpController.reset();
            });
          }

          if (levelProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F7FD5)),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, levelProvider),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildCurrentLevelCard(levelProvider),
                    const SizedBox(height: 20),
                    _buildLevelProgressCard(levelProvider),
                    const SizedBox(height: 20),
                    _buildLevelListCard(levelProvider),
                    const SizedBox(height: 20),
                    _buildPrivilegesCard(levelProvider),
                    const SizedBox(height: 20),
                    _buildExpSourcesCard(),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建应用栏
  Widget _buildAppBar(BuildContext context, UserLevelProvider levelProvider) {
    return SliverAppBar(
      expandedHeight: 220,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: levelProvider.userLevel != null
                ? levelProvider.getLevelGradient(levelProvider.currentLevel)
                : [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)],
          ),
        ),
        child: FlexibleSpaceBar(
          title: const Text(
            '我的等级',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          background: Container(
            padding: const EdgeInsets.only(top: 90),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value * 3.14159,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Lv.${levelProvider.currentLevel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// 构建当前等级卡片
  Widget _buildCurrentLevelCard(UserLevelProvider levelProvider) {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: levelProvider.getLevelGradient(levelProvider.currentLevel),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: levelProvider.getLevelColor(levelProvider.currentLevel).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        levelProvider.levelTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lv.${levelProvider.currentLevel}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: levelProvider.getLevelColor(levelProvider.currentLevel),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.psychology_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '总经验: ${levelProvider.totalExperience}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    levelProvider.isMaxLevel ? Icons.emoji_events_rounded : Icons.trending_up_rounded,
                    color: levelProvider.getLevelColor(levelProvider.currentLevel),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      levelProvider.isMaxLevel
                          ? '恭喜！您已达到最高等级'
                          : '距离下一级还需 ${levelProvider.expToNext} 经验',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: levelProvider.getLevelColor(levelProvider.currentLevel),
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

  /// 构建等级进度卡片
  Widget _buildLevelProgressCard(UserLevelProvider levelProvider) {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '等级进度',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Text(
                  '${levelProvider.progressPercentage.toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: levelProvider.getLevelColor(levelProvider.currentLevel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.8 * levelProvider.progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: levelProvider.getLevelGradient(levelProvider.currentLevel),
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: levelProvider.getLevelColor(levelProvider.currentLevel).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${levelProvider.currentExperience}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${levelProvider.userLevel?.nextLevelExp ?? 100}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建等级列表卡片
  Widget _buildLevelListCard(UserLevelProvider levelProvider) {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '等级系统',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
            ...List.generate(5, (index) {
              final level = index + 1;
              final isUnlocked = level <= levelProvider.currentLevel;
              final isCurrent = level == levelProvider.currentLevel;
              return _buildLevelItem(levelProvider, level, isUnlocked, isCurrent);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelItem(UserLevelProvider levelProvider, int level, bool isUnlocked, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? levelProvider.getLevelColor(level).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: levelProvider.getLevelColor(level).withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? LinearGradient(colors: levelProvider.getLevelGradient(level))
                  : null,
              color: isUnlocked ? null : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isUnlocked ? Icons.star_rounded : Icons.lock_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      levelProvider.getLevelTitle(level),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? const Color(0xFF2D3748) : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: levelProvider.getLevelColor(level),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '当前',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  'Lv.$level',
                  style: TextStyle(
                    fontSize: 14,
                    color: isUnlocked
                        ? levelProvider.getLevelColor(level)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            Icon(
              Icons.check_circle_rounded,
              color: levelProvider.getLevelColor(level),
              size: 20,
            ),
        ],
      ),
    );
  }

  /// 构建特权卡片
  Widget _buildPrivilegesCard(UserLevelProvider levelProvider) {
    final privileges = levelProvider.getLevelPrivileges(levelProvider.currentLevel);

    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: levelProvider.getLevelColor(levelProvider.currentLevel),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '当前特权',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...privileges.asMap().entries.map((entry) {
              final index = entry.key;
              final privilege = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: levelProvider.getLevelColor(levelProvider.currentLevel),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        privilege,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// 构建经验来源卡片
  Widget _buildExpSourcesCard() {
    final expSources = [
      {'title': '每日签到', 'exp': '10-100经验', 'icon': Icons.calendar_today, 'color': const Color(0xFF7F7FD5)},
      {'title': '发布帖子', 'exp': '5-20经验', 'icon': Icons.edit, 'color': const Color(0xFF86A8E7)},
      {'title': '点赞互动', 'exp': '1-5经验', 'icon': Icons.favorite, 'color': const Color(0xFFFF6B6B)},
      {'title': '评论互动', 'exp': '2-10经验', 'icon': Icons.comment, 'color': const Color(0xFF91EAE4)},
      {'title': 'VIP奖励', 'exp': '额外50%', 'icon': Icons.star, 'color': const Color(0xFFFFD700)},
    ];

    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '经验来源',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 16),
            ...expSources.map((source) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (source['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        source['icon'] as IconData,
                        color: source['color'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          Text(
                            source['exp'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}