import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/checkin_provider.dart';
import '../../providers/user_level_provider.dart';
import '../../services/achievement_hooks.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_motion.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_reveal.dart';

/// 签到主页 - 更强调成长反馈与主操作的任务型界面
class CheckInPage extends StatefulWidget {
  final String userId;

  const CheckInPage({
    super.key,
    required this.userId,
  });

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInTaskViewData {
  final String title;
  final String subtitle;
  final String reward;
  final String badge;
  final IconData icon;
  final Color accent;
  final bool completed;

  const _CheckInTaskViewData({
    required this.title,
    required this.subtitle,
    required this.reward,
    required this.badge,
    required this.icon,
    required this.accent,
    required this.completed,
  });
}

class _CheckInPageState extends State<CheckInPage>
    with TickerProviderStateMixin {
  late final AnimationController _rippleController;
  late final AnimationController _bounceController;
  late final Animation<double> _rippleAnimation;
  late final Animation<double> _bounceAnimation;
  int _selectedInsightIndex = 0;

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
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOutBack),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIdleAnimations();
  }

  void _syncIdleAnimations() {
    final reduceMotion = moeReduceMotion(context);
    if (reduceMotion) {
      if (_rippleController.isAnimating) {
        _rippleController.stop();
      }
      if (_rippleController.value != 0) {
        _rippleController.value = 0;
      }
      if (_bounceController.isAnimating) {
        _bounceController.stop();
      }
      if (_bounceController.value != 0) {
        _bounceController.value = 0;
      }
    }
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
      backgroundColor: MoeTokens.pageBackground,
      body: Consumer2<CheckInProvider, UserLevelProvider>(
        builder: (context, checkInProvider, levelProvider, child) {
          final initialLoading = (checkInProvider.isLoading &&
                  checkInProvider.checkInStatus == null) ||
              (levelProvider.isLoading && levelProvider.userLevel == null);
          final isCompact = MediaQuery.sizeOf(context).width < 420;

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, checkInProvider, levelProvider),
              if (initialLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: MoeLoading()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeroCard(
                        checkInProvider,
                        levelProvider,
                        isCompact: isCompact,
                      ),
                      const SizedBox(height: 18),
                      if (isCompact)
                        _buildInsightSwitcher(checkInProvider, levelProvider)
                      else ...[
                        _buildTaskList(
                          checkInProvider,
                          levelProvider,
                        ),
                        const SizedBox(height: 18),
                        _buildDailyQuestBoard(checkInProvider, levelProvider),
                        const SizedBox(height: 18),
                        _buildRewardPreview(checkInProvider),
                        const SizedBox(height: 18),
                        _buildStreakMilestones(checkInProvider),
                        const SizedBox(height: 18),
                        _buildStatsCard(checkInProvider, levelProvider),
                      ],
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    final tasks = _buildTasks(checkInProvider, levelProvider);
    return SliverAppBar(
      expandedHeight: 276,
      pinned: true,
      elevation: 0,
      backgroundColor: MoeTokens.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white),
          onPressed: () => _showHistoryPage(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: MoeTokens.heroGradient,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 28,
                right: -12,
                child: _buildGlowOrb(
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              Positioned(
                left: -34,
                bottom: -28,
                child: _buildGlowOrb(
                  size: 140,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '每日签到',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _buildTopSubtitle(checkInProvider, levelProvider),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTopStatPill(
                              icon: Icons.local_fire_department_rounded,
                              label: '连续签到',
                              value: '${checkInProvider.consecutiveDays} 天',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTopStatPill(
                              icon: Icons.bolt_rounded,
                              label: '今日奖励',
                              value: '+${checkInProvider.todayReward} EXP',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: tasks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) =>
                              _buildHeroTaskTag(tasks[index]),
                        ),
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
  }

  Widget _buildHeroCard(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider, {
    bool isCompact = false,
  }) {
    final hasChecked = checkInProvider.hasCheckedToday;
    final canCheckIn = checkInProvider.canCheckIn;
    final isChecking = checkInProvider.isCheckingIn;
    final ctaEnabled = canCheckIn && !hasChecked && !isChecking;
    final levelGradient = levelProvider.userLevel != null
        ? levelProvider.getLevelGradient(levelProvider.currentLevel)
        : const [MoeTokens.primary, MoeTokens.secondary];

    return MoeReveal(
      delay: const Duration(milliseconds: 80),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isCompact ? 24 : 28),
          boxShadow: [
            BoxShadow(
              color: MoeTokens.primary.withValues(alpha: 0.08),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _statusColor(ctaEnabled, hasChecked).withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(ctaEnabled, hasChecked, isChecking),
                          style: TextStyle(
                            color: _statusColor(ctaEnabled, hasChecked),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 10 : 14),
                      Text(
                        _headlineText(hasChecked, isChecking),
                        style: TextStyle(
                          fontSize: isCompact ? 21 : 24,
                          fontWeight: FontWeight.w800,
                          color: MoeTokens.titleText,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: isCompact ? 8 : 10),
                      Text(
                        _descriptionText(checkInProvider, levelProvider),
                        style: TextStyle(
                          fontSize: isCompact ? 13 : 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                        maxLines: isCompact ? 3 : null,
                        overflow: isCompact
                            ? TextOverflow.ellipsis
                            : TextOverflow.visible,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isCompact ? 14 : 18),
                _buildCheckInButton(
                  checkInProvider: checkInProvider,
                  levelProvider: levelProvider,
                  hasChecked: hasChecked,
                  canCheckIn: canCheckIn,
                  isChecking: isChecking,
                  size: isCompact ? 96 : 120,
                ),
              ],
            ),
            SizedBox(height: isCompact ? 14 : 18),
            Container(
              padding: EdgeInsets.all(isCompact ? 12 : 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    levelGradient.first.withValues(alpha: 0.12),
                    levelGradient.last.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMiniStat(
                        icon: Icons.auto_awesome_rounded,
                        label: '当前等级',
                        value: 'Lv.${levelProvider.currentLevel}',
                        color: levelGradient.first,
                      ),
                      const SizedBox(width: 10),
                      _buildMiniStat(
                        icon: Icons.trending_up_rounded,
                        label: '明日奖励',
                        value: '+${checkInProvider.nextDayReward} EXP',
                        color: levelGradient.last,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: levelProvider.progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        levelGradient.first,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        levelProvider.levelTitle,
                        style: TextStyle(
                          color: levelGradient.first,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        levelProvider.isMaxLevel
                            ? '已达到最高等级'
                            : '距离下一等级还差 ${levelProvider.expToNext} 经验',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInButton({
    required CheckInProvider checkInProvider,
    required UserLevelProvider levelProvider,
    required bool hasChecked,
    required bool canCheckIn,
    required bool isChecking,
    double size = 120,
  }) {
    final enabled = canCheckIn && !hasChecked && !isChecking;
    final reduceMotion = moeReduceMotion(context);
    final gradient = enabled
        ? const [MoeTokens.primary, MoeTokens.secondary]
        : hasChecked
            ? const [Color(0xFF56C271), Color(0xFF37A36B)]
            : [Colors.grey.shade300, Colors.grey.shade400];

    final buttonCore = AnimatedBuilder(
      animation: Listenable.merge([_rippleController, _bounceController]),
      builder: (context, child) {
        final scale = reduceMotion ? 1.0 : _bounceAnimation.value;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (enabled && !reduceMotion)
                  Container(
                    width: size + (_rippleAnimation.value * 28),
                    height: size + (_rippleAnimation.value * 28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MoeTokens.primary.withValues(
                          alpha: 0.42 * (1 - _rippleAnimation.value),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: enabled
                            ? MoeTokens.primary.withValues(alpha: 0.34)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: enabled ? 24 : 14,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasChecked
                            ? Icons.check_rounded
                            : isChecking
                                ? Icons.hourglass_top_rounded
                                : Icons.bolt_rounded,
                        color: Colors.white,
                        size: size < 110 ? 28 : 34,
                      ),
                      SizedBox(height: size < 110 ? 4 : 6),
                      Text(
                        hasChecked
                            ? '已签到'
                            : isChecking
                                ? '签到中'
                                : '立即签到',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size < 110 ? 12 : 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return MoePressable(
      onTap: enabled
          ? () => _performCheckIn(checkInProvider, levelProvider)
          : null,
      pressedScale: MoeTokens.motionPressScaleStrong,
      borderRadius: BorderRadius.circular(999),
      child: buttonCore,
    );
  }

  Widget _buildRewardPreview(
    CheckInProvider checkInProvider, {
    bool compact = false,
  }) {
    final streakTier = math.max(1, checkInProvider.consecutiveDays);
    final streakReward = 10 + (streakTier * 2);

    return MoeReveal(
      delay: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '奖励预览',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '今天和明天的成长收益一眼看清，连续签到还会有额外加成。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRewardPanel(
                    title: '今日签到',
                    value: '+${checkInProvider.todayReward} EXP',
                    subtitle:
                        checkInProvider.hasCheckedToday ? '今日已领取' : '完成后立即到账',
                    icon: Icons.today_rounded,
                    colors: const [MoeTokens.primary, MoeTokens.secondary],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRewardPanel(
                    title: '明日预告',
                    value: '+${checkInProvider.nextDayReward} EXP',
                    subtitle: '保持节奏更容易升级',
                    icon: Icons.wb_sunny_outlined,
                    colors: const [Color(0xFFFFB347), Color(0xFFFFD56A)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFE09020),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '连续签到加成',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MoeTokens.titleText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '当前连续 ${checkInProvider.consecutiveDays} 天，下次可额外获得约 +$streakReward EXP 的成长收益。',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
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

  Widget _buildDailyQuestBoard(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    final hasChecked = checkInProvider.hasCheckedToday;
    final canCheckIn = checkInProvider.canCheckIn;
    final streakTarget = math.max(3, checkInProvider.consecutiveDays + 1);
    final daysLeft =
        math.max(0, streakTarget - checkInProvider.consecutiveDays);
    final sideQuestReward = 12 + (streakTarget * 2);

    return MoeReveal(
      delay: const Duration(milliseconds: 120),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日任务面板',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '把签到、连签奖励和成长进度收在一起，像清任务一样把今天的收益拿满。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuestRow(
              title: '主线任务: 每日签到',
              subtitle: hasChecked
                  ? '今日奖励已到账，可以继续冲击更高等级。'
                  : canCheckIn
                      ? '完成后立即获得经验，并维持连签节奏。'
                      : '当前暂不可领取，稍后回来再试试看。',
              reward: '+${checkInProvider.todayReward} EXP',
              icon: hasChecked ? Icons.verified_rounded : Icons.bolt_rounded,
              stateLabel: hasChecked
                  ? '已完成'
                  : canCheckIn
                      ? '可领取'
                      : '未开启',
              accent: hasChecked ? const Color(0xFF2E9B62) : MoeTokens.primary,
              completed: hasChecked,
            ),
            const SizedBox(height: 12),
            _buildQuestRow(
              title: '明日预告: 连续回归',
              subtitle:
                  '明天回来可继续领取 +${checkInProvider.nextDayReward} EXP，保持成长不断档。',
              reward: '+${checkInProvider.nextDayReward} EXP',
              icon: Icons.calendar_month_rounded,
              stateLabel: '明日解锁',
              accent: const Color(0xFFFFB347),
            ),
            const SizedBox(height: 12),
            _buildQuestRow(
              title: '支线奖励: 连签里程碑',
              subtitle: daysLeft == 0
                  ? '当前已经踩在线上奖励点，下一次签到会继续滚动奖励。'
                  : '距离 $streakTarget 天里程碑还差 $daysLeft 天，预计可拿额外 +$sideQuestReward EXP。',
              reward: '+$sideQuestReward EXP',
              icon: Icons.flag_rounded,
              stateLabel: daysLeft == 0 ? '进行中' : '差 $daysLeft 天',
              accent: levelProvider.getLevelColor(levelProvider.currentLevel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(
      CheckInProvider checkInProvider, UserLevelProvider levelProvider,
      {bool isCompact = false, bool embedded = false}) {
    final tasks = _buildTasks(checkInProvider, levelProvider);
    final completedCount = tasks.where((task) => task.completed).length;
    final progress = tasks.isEmpty ? 0.0 : completedCount / tasks.length;
    final previewTasks = isCompact ? tasks.take(2).toList() : tasks;

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F3F8),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      MoeTokens.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MoeTokens.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$completedCount / ${tasks.length} 瀹屾垚',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MoeTokens.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...previewTasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTaskItem(task),
              )),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showTaskDrawer(context, tasks),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: MoeTokens.primary,
              ),
              icon: const Icon(Icons.toc_rounded, size: 18),
              label: Text(
                '查看全部 ${tasks.length} 个任务',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    }

    return MoeReveal(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
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
                    '任务列表',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: MoeTokens.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$completedCount / ${tasks.length} 完成',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MoeTokens.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '先把今天能做的成长任务清掉，经验和连签收益都会更直观。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F3F8),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  MoeTokens.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...previewTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTaskItem(task),
                )),
            if (isCompact)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showTaskDrawer(context, tasks),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: MoeTokens.primary,
                  ),
                  icon: const Icon(Icons.toc_rounded, size: 18),
                  label: Text(
                    '查看全部 ${tasks.length} 个任务',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroTaskTag(_CheckInTaskViewData task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            task.icon,
            size: 14,
            color: Colors.white.withValues(alpha: 0.96),
          ),
          const SizedBox(width: 6),
          Text(
            task.title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.96),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              task.badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.96),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightSwitcher(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    final tabs = const [
      ('任务板', Icons.dashboard_customize_rounded),
      ('奖励', Icons.card_giftcard_rounded),
      ('连签', Icons.timeline_rounded),
      ('成长', Icons.insights_rounded),
    ];

    return MoeReveal(
      delay: const Duration(milliseconds: 180),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '更多面板',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '把次级信息收进切换面板里，先看重点，再按需展开。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(tabs.length, (index) {
                final selected = _selectedInsightIndex == index;
                final item = tabs[index];
                return MoePressable(
                  onTap: () {
                    setState(() {
                      _selectedInsightIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? MoeTokens.primary.withValues(alpha: 0.12)
                          : const Color(0xFFF5F7FB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? MoeTokens.primary.withValues(alpha: 0.24)
                            : const Color(0xFFE8ECF4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.$2,
                          size: 16,
                          color: selected
                              ? MoeTokens.primary
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.$1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? MoeTokens.primary
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            _buildSelectedInsight(checkInProvider, levelProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedInsight(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    switch (_selectedInsightIndex) {
      case 0:
        return _buildTaskList(
          checkInProvider,
          levelProvider,
          isCompact: true,
          embedded: true,
        );
      case 1:
        return _buildRewardPreview(checkInProvider, compact: true);
      case 2:
        return _buildStreakMilestones(checkInProvider, compact: true);
      default:
        return _buildStatsCard(checkInProvider, levelProvider, compact: true);
    }
  }

  Future<void> _showTaskDrawer(
    BuildContext context,
    List<_CheckInTaskViewData> tasks,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DBE6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '今日任务列表',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MoeTokens.titleText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: tasks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildTaskItem(tasks[index]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_CheckInTaskViewData> _buildTasks(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    final streak = checkInProvider.consecutiveDays;
    final streakMilestone = streak < 3
        ? 3
        : streak < 5
            ? 5
            : streak < 7
                ? 7
                : streak + 3;
    final streakRemaining = math.max(0, streakMilestone - streak);
    final nextLevelExp =
        levelProvider.isMaxLevel ? 0 : math.max(0, levelProvider.expToNext);

    return [
      _CheckInTaskViewData(
        title: '每日签到',
        subtitle: checkInProvider.hasCheckedToday
            ? '今日签到已经完成，奖励已到账。'
            : checkInProvider.canCheckIn
                ? '领取今日签到奖励并保持连签。'
                : '当前暂不可签到，稍后可以再回来看看。',
        reward: '+${checkInProvider.todayReward} EXP',
        badge: checkInProvider.hasCheckedToday
            ? '已完成'
            : checkInProvider.canCheckIn
                ? '可领取'
                : '未开启',
        icon: checkInProvider.hasCheckedToday
            ? Icons.check_circle_rounded
            : Icons.bolt_rounded,
        accent: checkInProvider.hasCheckedToday
            ? const Color(0xFF2E9B62)
            : MoeTokens.primary,
        completed: checkInProvider.hasCheckedToday,
      ),
      _CheckInTaskViewData(
        title: '连续签到里程碑',
        subtitle: streakRemaining == 0
            ? '你已经站上当前里程碑，继续保持就会滚动解锁下一档奖励。'
            : '还差 $streakRemaining 天即可触发第 $streakMilestone 天连签奖励。',
        reward: '+${12 + streakMilestone * 2} EXP',
        badge: streakRemaining == 0 ? '进行中' : '差 $streakRemaining 天',
        icon: Icons.local_fire_department_rounded,
        accent: const Color(0xFFFF8A5B),
        completed: false,
      ),
      _CheckInTaskViewData(
        title: '等级成长',
        subtitle: levelProvider.isMaxLevel
            ? '当前已经达到最高等级，今天继续保持活跃就好。'
            : '距离下一等级还差 $nextLevelExp EXP，完成日常任务会更快升级。',
        reward: levelProvider.isMaxLevel
            ? '已满级'
            : '目标 Lv.${levelProvider.currentLevel + 1}',
        badge: levelProvider.isMaxLevel
            ? '已达上限'
            : '${(levelProvider.progressPercentage).toStringAsFixed(0)}%',
        icon: Icons.auto_awesome_rounded,
        accent: levelProvider.getLevelColor(levelProvider.currentLevel),
        completed: levelProvider.isMaxLevel,
      ),
      const _CheckInTaskViewData(
        title: '更多活跃任务',
        subtitle: '后续可以在这里接入发动态、逛社区、进入 AI 等日常任务。',
        reward: '即将开放',
        badge: '预告',
        icon: Icons.explore_rounded,
        accent: Color(0xFF9095A0),
        completed: false,
      ),
    ];
  }

  Widget _buildTaskItem(_CheckInTaskViewData task) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: task.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: task.accent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: task.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(task.icon, size: 22, color: task.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: MoeTokens.titleText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        task.badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: task.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  task.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      task.reward,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: task.accent,
                      ),
                    ),
                    if (task.completed) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFF2E9B62),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestRow({
    required String title,
    required String subtitle,
    required String reward,
    required IconData icon,
    required String stateLabel,
    required Color accent,
    bool completed = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: MoeTokens.titleText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        stateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      reward,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    if (completed) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF2E9B62),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakMilestones(
    CheckInProvider checkInProvider, {
    bool compact = false,
  }) {
    final milestones = [1, 3, 5, 7];
    final streak = checkInProvider.consecutiveDays;

    return MoeReveal(
      delay: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '连签里程碑',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '连续签到越久，成长收益越稳。把今天当作连签任务链里的一格。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: List.generate(milestones.length, (index) {
                final day = milestones[index];
                final reached = streak >= day;
                final isCurrent =
                    !reached && (index == 0 || streak >= milestones[index - 1]);

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: reached
                                    ? const LinearGradient(
                                        colors: [
                                          MoeTokens.primary,
                                          MoeTokens.secondary,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: reached
                                    ? null
                                    : isCurrent
                                        ? const Color(0xFFFFF3DD)
                                        : const Color(0xFFF4F5F9),
                                border: Border.all(
                                  color: reached
                                      ? Colors.transparent
                                      : isCurrent
                                          ? const Color(0xFFFFB347)
                                          : const Color(0xFFE6E8F0),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                reached
                                    ? Icons.check_rounded
                                    : isCurrent
                                        ? Icons.flag_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                color: reached
                                    ? Colors.white
                                    : isCurrent
                                        ? const Color(0xFFE09020)
                                        : const Color(0xFFB7BDCF),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '第 $day 天',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: MoeTokens.titleText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reached
                                  ? '已达成'
                                  : isCurrent
                                      ? '当前目标'
                                      : '待解锁',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: reached
                                    ? MoeTokens.primary
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index != milestones.length - 1)
                        Container(
                          width: 18,
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 36),
                          color: streak >= milestones[index + 1]
                              ? MoeTokens.primary.withValues(alpha: 0.7)
                              : const Color(0xFFE4E7F0),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider, {
    bool compact = false,
  }) {
    return MoeReveal(
      delay: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '成长面板',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    title: '当前等级',
                    value: 'Lv.${levelProvider.currentLevel}',
                    icon: Icons.auto_awesome_rounded,
                    color: MoeTokens.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatItem(
                    title: '连续签到',
                    value: '${checkInProvider.consecutiveDays} 天',
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatItem(
                    title: '总经验',
                    value: '${levelProvider.totalExperience}',
                    icon: Icons.bolt_rounded,
                    color: MoeTokens.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardPanel({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.first.withValues(alpha: 0.12),
            colors.last.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.first.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.first),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.first,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowOrb({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  String _buildTopSubtitle(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    if (checkInProvider.hasCheckedToday) {
      return '今天的成长奖励已经到账，继续保持节奏，向 ${levelProvider.levelTitle} 更进一步。';
    }
    if (checkInProvider.canCheckIn) {
      return '轻点一下就能领取今日经验，连续签到还能把成长曲线抬得更漂亮。';
    }
    return '当前暂时不能签到，稍后回来看看，我们会把今天的进度稳稳接住。';
  }

  String _headlineText(bool hasChecked, bool isChecking) {
    if (isChecking) return '正在把今日奖励送到你手里';
    if (hasChecked) return '今日签到已完成';
    return '把今天的成长先拿下';
  }

  String _descriptionText(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    if (checkInProvider.hasCheckedToday) {
      return '已累计连续签到 ${checkInProvider.consecutiveDays} 天。接下来只要保持节奏，就能更快冲向 Lv.${levelProvider.currentLevel + 1}。';
    }
    if (checkInProvider.canCheckIn) {
      return '本次签到可获得 ${checkInProvider.todayReward} 点经验。明天回来还能继续领 ${checkInProvider.nextDayReward} 点成长奖励。';
    }
    return '签到状态暂不可用，可以先看看连续奖励和成长进度，稍后再回来操作。';
  }

  String _statusLabel(bool ctaEnabled, bool hasChecked, bool isChecking) {
    if (isChecking) return '处理中';
    if (hasChecked) return '今日已完成';
    if (ctaEnabled) return '现在可签到';
    return '暂不可用';
  }

  Color _statusColor(bool ctaEnabled, bool hasChecked) {
    if (hasChecked) return const Color(0xFF2E9B62);
    if (ctaEnabled) return MoeTokens.primary;
    return const Color(0xFF9095A0);
  }

  Future<void> _performCheckIn(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) async {
    if (!checkInProvider.canCheckIn || checkInProvider.isCheckingIn) return;

    if (!moeReduceMotion(context)) {
      unawaited(_bounceController.forward().then((_) {
        if (mounted) {
          _bounceController.reverse();
        }
      }));
      _rippleController.repeat();
    }

    final success = await checkInProvider.performCheckIn(widget.userId);

    _rippleController.stop();
    _rippleController.reset();

    if (success) {
      levelProvider.loadUserLevel(widget.userId);
      AchievementHooks.scheduleServerUnlocks(
        widget.userId,
        checkInProvider.lastUnlocks,
      );

      if (checkInProvider.successMessage != null) {
        _showSuccessSnackBar(checkInProvider.successMessage!);
      }
    } else {
      if (checkInProvider.errorMessage != null) {
        _showErrorSnackBar(checkInProvider.errorMessage!);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    MoeToast.success(context, message);
  }

  void _showErrorSnackBar(String message) {
    MoeToast.error(context, message);
  }

  void _showHistoryPage(BuildContext context) {
    MoeToast.show(
      context,
      '签到历史功能开发中...',
      icon: Icons.info_outline_rounded,
    );
  }
}
