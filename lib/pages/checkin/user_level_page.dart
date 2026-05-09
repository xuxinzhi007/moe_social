import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_level_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_loading.dart';
import 'checkin_page.dart';

/// 用户等级页：顶部概览（含跳转签到）+ 下方多列宫格模块。
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
      context.read<CheckInProvider>().loadCheckInStatus(widget.userId);
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
          if (levelProvider.isLevelingUp) {
            _levelUpController.forward().then((_) {
              levelProvider.completeLevelUp();
              _levelUpController.reset();
            });
          }

          if (levelProvider.isLoading) {
            return const Center(child: MoeLoading());
          }

          final hPad = MediaQuery.sizeOf(context).width > 600 ? 22.0 : 16.0;
          final bottomInset = MediaQuery.paddingOf(context).bottom;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(context, levelProvider),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20 + bottomInset),
                sliver: SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gapY = SizedBox(height: 14);
                      final w = constraints.maxWidth;
                      final modules = <Widget>[
                        _buildLevelRoadmap(levelProvider),
                        _buildDailyTasksCard(),
                        _buildAchievementsCard(levelProvider),
                        _buildSocialRankingCard(levelProvider),
                        _buildPrivilegesCard(levelProvider),
                        _buildExpSourcesCard(),
                      ];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildOverviewHero(levelProvider),
                          gapY,
                          _buildModuleWrapGrid(maxWidth: w, children: modules),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 顶部导航：与资料页一致的紫青渐变 +「我的等级」
  Widget _buildAppBar(BuildContext context, UserLevelProvider levelProvider) {
    final g = levelProvider.userLevel != null
        ? levelProvider.getLevelGradient(levelProvider.currentLevel)
        : const [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)];

    return SliverAppBar(
      expandedHeight: 128,
      floating: false,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: g.first,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.fadeTitle, StretchMode.blurBackground],
        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14),
        title: Text(
          '我的等级',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: MediaQuery.textScalerOf(context).scale(17).clamp(15.0, 22.0),
            shadows: const [
              Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 1)),
            ],
          ),
        ),
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: g,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 16, 28),
                child: Opacity(
                  opacity: 0.32,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _absoluteMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    final t = path.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    final base = ApiService.baseUrl.replaceAll(RegExp(r'/$'), '');
    final p = t.startsWith('/') ? t : '/$t';
    return '$base$p';
  }

  Widget _levelBadgeFallback() {
    return ColoredBox(
      color: const Color(0xFFF0F4FF),
      child: const Icon(
        Icons.military_tech_rounded,
        size: 44,
        color: Color(0xFF7F7FD5),
      ),
    );
  }

  Widget _buildBadgeAvatar(UserLevelProvider p, String? imageUrl) {
    final colors = p.getLevelGradient(p.currentLevel);
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        clipBehavior: Clip.antiAlias,
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                headers: ApiService.tunnelBypassHeadersForUrl(imageUrl),
                errorBuilder: (_, __, ___) => _levelBadgeFallback(),
              )
            : _levelBadgeFallback(),
      ),
    );
  }

  /// 多列宫格排布下方模块（签到已合并进概览，此处不再重复大卡片）
  Widget _buildModuleWrapGrid({
    required double maxWidth,
    required List<Widget> children,
  }) {
    const gap = 12.0;
    final columns = maxWidth < 400 ? 1 : (maxWidth >= 840 ? 3 : 2);
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    final tileW = (maxWidth - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final c in children) SizedBox(width: tileW, child: c),
      ],
    );
  }

  /// 合并原「当前等级 + 进度条」：展示称号、徽章图、本阶/总经验与自适应宽度进度条
  Widget _buildOverviewHero(UserLevelProvider p) {
    final checkIn = context.watch<CheckInProvider>();
    final ul = p.userLevel;
    final badgeUrl = _absoluteMediaUrl(ul?.badgeUrl);
    final colors = p.getLevelGradient(p.currentLevel);

    return FadeInUp(
      delay: Duration.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              colors.first.withValues(alpha: 0.14),
              colors.last.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colors.first.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.2),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _levelUpController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value * pi,
                        child: child,
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'level_badge_${widget.userId}',
                    child: _buildBadgeAvatar(p, badgeUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ul?.levelTitle ?? p.levelTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: colors),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.first.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              'Lv.${p.currentLevel}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.bolt_rounded,
                            size: 18,
                            color: colors.first,
                          ),
                          Expanded(
                            child: Text(
                              p.isMaxLevel
                                  ? '已满级'
                                  : '距下一级还差 ${p.expToNext} EXP',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                                height: 1.3,
                              ),
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
            LayoutBuilder(
              builder: (context, c) {
                final barW = c.maxWidth;
                final fillW = (barW * p.progress).clamp(0.0, barW);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 12,
                          width: barW,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8ECF4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          height: 12,
                          width: fillW,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: colors.first.withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (p.progress > 0 && p.progress < 1)
                          Positioned(
                            left: (fillW - 8).clamp(0.0, barW - 16),
                            top: -2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.first, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.first.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '本阶 ${p.currentExperience} / ${ul?.nextLevelExp ?? 100} EXP',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${p.progressPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colors.first,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '累计总经验 ${p.totalExperience}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: colors.first.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => CheckInPage(userId: widget.userId),
                    ),
                  );
                  if (!context.mounted) return;
                  await context.read<UserLevelProvider>().loadUserLevel(widget.userId);
                  await context.read<CheckInProvider>().loadCheckInStatus(widget.userId);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.first.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.first.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        color: colors.first,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '每日签到',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              checkIn.hasCheckedToday
                                  ? '今日已签到 · 连续 ${checkIn.consecutiveDays} 天'
                                  : '去签到页领取经验 · 已连续 ${checkIn.consecutiveDays} 天',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 横向等级之路，避免纵向长列表占满一屏
  Widget _buildLevelRoadmap(UserLevelProvider p) {
    return FadeInUp(
      delay: const Duration(milliseconds: 80),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8ECF4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F7FD5).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  color: p.getLevelColor(p.currentLevel),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  '等级之路',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final level = index + 1;
                  final unlocked = level <= p.currentLevel;
                  final current = level == p.currentLevel;
                  final cg = p.getLevelGradient(level);
                  return Container(
                    width: 88,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: unlocked
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                cg.first.withValues(alpha: current ? 0.95 : 0.55),
                                cg.last.withValues(alpha: current ? 0.85 : 0.45),
                              ],
                            )
                          : null,
                      color: unlocked ? null : const Color(0xFFF0F2F7),
                      border: current
                          ? Border.all(color: Colors.white, width: 2)
                          : Border.all(
                              color: unlocked
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : const Color(0xFFE0E4EE),
                            ),
                      boxShadow: current
                          ? [
                              BoxShadow(
                                color: cg.first.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          unlocked ? Icons.star_rounded : Icons.lock_rounded,
                          color: unlocked ? Colors.white : Colors.grey.shade500,
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lv.$level',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: unlocked ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.getLevelTitle(level),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            color: unlocked
                                ? Colors.white.withValues(alpha: 0.92)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
          mainAxisSize: MainAxisSize.min,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: privileges
                  .map(
                    (privilege) => Chip(
                      avatar: CircleAvatar(
                        backgroundColor:
                            levelProvider.getLevelColor(levelProvider.currentLevel),
                        radius: 12,
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                      label: Text(privilege),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2D3748),
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: levelProvider
                          .getLevelColor(levelProvider.currentLevel)
                          .withValues(alpha: 0.08),
                      side: BorderSide(
                        color: levelProvider
                            .getLevelColor(levelProvider.currentLevel)
                            .withValues(alpha: 0.22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建每日任务卡片
  Widget _buildDailyTasksCard() {
    final dailyTasks = [
      {'title': '发布帖子', 'exp': '10经验', 'completed': false, 'icon': Icons.edit},
      {'title': '评论互动', 'exp': '5经验', 'completed': false, 'icon': Icons.comment},
      {'title': '点赞内容', 'exp': '3经验', 'completed': false, 'icon': Icons.favorite},
      {'title': '分享内容', 'exp': '8经验', 'completed': false, 'icon': Icons.share},
    ];

    return FadeInUp(
      delay: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.task_alt_rounded, color: Colors.indigo.shade400, size: 22),
                const SizedBox(width: 8),
                const Text(
                  '每日任务',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...dailyTasks.map((task) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: task['completed'] as bool
                            ? const Color(0xFF4CAF50).withOpacity(0.1)
                            : const Color(0xFF86A8E7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        task['completed'] as bool ? Icons.check : task['icon'] as IconData,
                        color: task['completed'] as bool
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF86A8E7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: task['completed'] as bool
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF2D3748),
                            ),
                          ),
                          Text(
                            task['exp'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (task['completed'] as bool)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                        size: 20,
                      ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF7F7FD5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '完成每日任务可获得额外经验奖励',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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

  /// 构建成就系统卡片
  Widget _buildAchievementsCard(UserLevelProvider levelProvider) {
    final achievements = [
      {'title': '初出茅庐', 'description': '等级达到2级', 'completed': levelProvider.currentLevel >= 2, 'icon': Icons.emoji_events},
      {'title': '社区活跃', 'description': '连续签到7天', 'completed': false, 'icon': Icons.local_fire_department},
      {'title': '内容创作', 'description': '发布10个帖子', 'completed': false, 'icon': Icons.edit_document},
      {'title': '社交达人', 'description': '获得50个赞', 'completed': false, 'icon': Icons.people},
    ];

    return FadeInUp(
      delay: const Duration(milliseconds: 350),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Colors.amber.shade700, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      '成就系统',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1E2E),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${achievements.where((a) => a['completed'] as bool).length}/${achievements.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...achievements.map((achievement) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: achievement['completed'] as bool
                            ? const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              )
                            : null,
                        color: achievement['completed'] as bool
                            ? null
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: achievement['completed'] as bool
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        achievement['icon'] as IconData,
                        color: achievement['completed'] as bool ? Colors.white : Colors.grey.shade500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            achievement['title'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: achievement['completed'] as bool
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFF2D3748),
                            ),
                          ),
                          Text(
                            achievement['description'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (achievement['completed'] as bool)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                        size: 20,
                      ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: Color(0xFFFFD700),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '完成成就可获得额外经验和特殊奖励',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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

  /// 构建社交排名卡片
  Widget _buildSocialRankingCard(UserLevelProvider levelProvider) {
    final ranking = [
      {
        'rank': 1,
        'name': '小明',
        'level': 5,
        'avatarIcon': Icons.workspace_premium_rounded,
        'avatarGradient': const [Color(0xFFFFD54F), Color(0xFFFFA726)],
        'avatarColor': const Color(0xFFFFB300),
      },
      {
        'rank': 2,
        'name': '小红',
        'level': 4,
        'avatarIcon': Icons.diamond_rounded,
        'avatarGradient': const [Color(0xFF90CAF9), Color(0xFF42A5F5)],
        'avatarColor': const Color(0xFF42A5F5),
      },
      {
        'rank': 3,
        'name': '你',
        'level': levelProvider.currentLevel,
        'avatarIcon': Icons.local_fire_department_rounded,
        'avatarGradient': const [Color(0xFFFF8A65), Color(0xFFFF5722)],
        'avatarColor': const Color(0xFFFF7043),
        'isCurrentUser': true,
      },
      {
        'rank': 4,
        'name': '小李',
        'level': 3,
        'avatarIcon': Icons.star_rounded,
        'avatarGradient': const [Color(0xFFB39DDB), Color(0xFF9575CD)],
        'avatarColor': const Color(0xFF9575CD),
      },
      {
        'rank': 5,
        'name': '小张',
        'level': 3,
        'avatarIcon': Icons.auto_awesome_rounded,
        'avatarGradient': const [Color(0xFF80CBC4), Color(0xFF4DB6AC)],
        'avatarColor': const Color(0xFF4DB6AC),
      },
    ];

    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.leaderboard_rounded, color: Colors.deepPurple.shade400, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      '社区排名',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1E2E),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F7FD5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Top 5',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7F7FD5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...ranking.map((item) {
              final isCurrentUser = item['isCurrentUser'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? levelProvider.getLevelColor(levelProvider.currentLevel).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrentUser
                        ? Border.all(color: levelProvider.getLevelColor(levelProvider.currentLevel).withOpacity(0.3))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: item['rank'] as int <= 3
                              ? LinearGradient(
                                  colors: [
                                    item['rank'] as int == 1 ? const Color(0xFFFFD700) : (item['rank'] as int == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32)),
                                    item['rank'] as int == 1 ? const Color(0xFFFFA500) : (item['rank'] as int == 2 ? const Color(0xFFA9A9A9) : const Color(0xFFB87333)),
                                  ],
                                )
                              : null,
                          color: item['rank'] as int <= 3 ? null : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${item['rank']}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: item['rank'] as int <= 3 ? Colors.white : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildRankingAvatar(item),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isCurrentUser
                                    ? levelProvider.getLevelColor(levelProvider.currentLevel)
                                    : const Color(0xFF2D3748),
                              ),
                            ),
                            Text(
                              'Lv.${item['level']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: levelProvider.getLevelColor(levelProvider.currentLevel),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '我',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_alt_outlined,
                    color: Color(0xFF7F7FD5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '提升等级有助于社区影响力；当前为示例榜单，真实排名敬请期待。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey.shade600,
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

  Widget _buildRankingAvatar(Map<String, Object?> item) {
    final avatarIcon = item['avatarIcon'] as IconData;
    final avatarGradient = item['avatarGradient'] as List<Color>;
    final avatarColor = item['avatarColor'] as Color;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: avatarGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: avatarColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        avatarIcon,
        color: Colors.white,
        size: 20,
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
          color: Colors.white.withOpacity(0.95),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.source_rounded, color: Colors.teal.shade400, size: 22),
                const SizedBox(width: 8),
                const Text(
                  '经验来源',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: expSources.map((source) {
                    final col = source['color'] as Color;
                    return SizedBox(
                      width: w,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: col.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              source['icon'] as IconData,
                              color: col,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    source['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                  Text(
                                    source['exp'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}