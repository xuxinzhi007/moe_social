import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/checkin_provider.dart';
import '../../providers/user_level_provider.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_toast.dart';
import '../../services/achievement_hooks.dart';

/// 签到主页面 - 遵循 Moe Social Design Language 梦幻风格
class CheckInPage extends StatefulWidget {
  final String userId;

  const CheckInPage({
    super.key,
    required this.userId,
  });

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _bounceController;
  late Animation<double> _rippleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }

  void _setupAnimations() {
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checkInProvider = context.read<CheckInProvider>();
      final levelProvider = context.read<UserLevelProvider>();

      checkInProvider.loadCheckInStatus(widget.userId);
      levelProvider.loadUserLevel(widget.userId);
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // 背景色
      body: Consumer2<CheckInProvider, UserLevelProvider>(
        builder: (context, checkInProvider, levelProvider, child) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildLevelCard(levelProvider),
                    const SizedBox(height: 20),
                    _buildCheckInCard(checkInProvider, levelProvider),
                    const SizedBox(height: 20),
                    _buildRewardPreview(checkInProvider),
                    const SizedBox(height: 20),
                    _buildStatsCard(checkInProvider, levelProvider),
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
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 70,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              '每日签到',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white),
          onPressed: () => _showHistoryPage(context),
        ),
      ],
    );
  }

  /// 构建等级信息卡片
  Widget _buildLevelCard(UserLevelProvider levelProvider) {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: levelProvider.userLevel != null
                ? levelProvider.getLevelGradient(levelProvider.currentLevel)
                : [const Color(0xFF91EAE4), const Color(0xFF7F7FD5)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${levelProvider.levelTitle} Lv.${levelProvider.currentLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${levelProvider.currentExperience}/${levelProvider.userLevel?.nextLevelExp ?? 100}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: levelProvider.progress,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    levelProvider.isMaxLevel
                        ? '已达到最高等级！'
                        : '距下级差 ${levelProvider.expToNext} 经验',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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

  /// 构建签到卡片
  Widget _buildCheckInCard(CheckInProvider checkInProvider, UserLevelProvider levelProvider) {
    final hasChecked = checkInProvider.hasCheckedToday;
    final canCheckIn = checkInProvider.canCheckIn;

    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '每日签到',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasChecked
                        ? '今日已签到'
                        : canCheckIn
                            ? '点击右侧按钮签到'
                            : '无法签到',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasChecked
                          ? Colors.green.shade600
                          : canCheckIn
                              ? const Color(0xFF7F7FD5)
                              : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    checkInProvider.checkInStatus?.consecutiveDaysText ?? '开始你的签到之旅',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bounceAnimation.value,
                  child: GestureDetector(
                    onTap: hasChecked ? null : () => _performCheckIn(checkInProvider, levelProvider),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: hasChecked
                              ? [Colors.grey.shade300, Colors.grey.shade400]
                              : canCheckIn
                                  ? [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)]
                                  : [Colors.grey.shade300, Colors.grey.shade400],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (hasChecked || !canCheckIn)
                                ? Colors.grey.withOpacity(0.3)
                                : const Color(0xFF7F7FD5).withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _rippleAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              if (canCheckIn && !hasChecked && !checkInProvider.isCheckingIn)
                                Container(
                                  width: 80 + (_rippleAnimation.value * 24),
                                  height: 80 + (_rippleAnimation.value * 24),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF7F7FD5).withOpacity(
                                        0.5 * (1 - _rippleAnimation.value),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              Icon(
                                hasChecked
                                    ? Icons.check_circle_rounded
                                    : checkInProvider.isCheckingIn
                                        ? Icons.hourglass_empty_rounded
                                        : Icons.calendar_today_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建奖励预览
  Widget _buildRewardPreview(CheckInProvider checkInProvider) {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
              '签到奖励',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRewardItem(
                    '今日奖励',
                    '${checkInProvider.todayReward} 经验',
                    Icons.today,
                    const Color(0xFF7F7FD5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRewardItem(
                    '明日奖励',
                    '${checkInProvider.nextDayReward} 经验',
                    Icons.schedule_rounded,
                    const Color(0xFF86A8E7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatsCard(CheckInProvider checkInProvider, UserLevelProvider levelProvider) {
    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
              '我的成就',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '当前等级',
                    'Lv.${levelProvider.currentLevel}',
                    Icons.star_rounded,
                    const Color(0xFFFFD700),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '连续签到',
                    '${checkInProvider.consecutiveDays}天',
                    Icons.local_fire_department_rounded,
                    const Color(0xFFFF6B6B),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总经验',
                    '${levelProvider.totalExperience}',
                    Icons.psychology_rounded,
                    const Color(0xFF91EAE4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 执行签到
  Future<void> _performCheckIn(CheckInProvider checkInProvider, UserLevelProvider levelProvider) async {
    if (!checkInProvider.canCheckIn || checkInProvider.isCheckingIn) return;

    // 播放按钮动画
    _bounceController.forward().then((_) {
      _bounceController.reverse();
    });

    // 播放涟漪动画
    _rippleController.repeat();

    final success = await checkInProvider.performCheckIn(widget.userId);

    _rippleController.stop();
    _rippleController.reset();

    if (success) {
      // 刷新用户等级信息
      levelProvider.loadUserLevel(widget.userId);
      unawaited(AchievementHooks.recordDailyEngagement(widget.userId));

      // 显示成功消息
      if (checkInProvider.successMessage != null) {
        _showSuccessSnackBar(checkInProvider.successMessage!);
      }
    } else {
      // 显示错误消息
      if (checkInProvider.errorMessage != null) {
        _showErrorSnackBar(checkInProvider.errorMessage!);
      }
    }
  }

  /// 显示成功消息
  void _showSuccessSnackBar(String message) {
    MoeToast.success(context, message);
  }

  /// 显示错误消息
  void _showErrorSnackBar(String message) {
    MoeToast.error(context, message);
  }

  /// 显示历史页面
  void _showHistoryPage(BuildContext context) {
    MoeToast.show(context, '签到历史功能开发中...',
        icon: Icons.info_outline_rounded);
  }
}