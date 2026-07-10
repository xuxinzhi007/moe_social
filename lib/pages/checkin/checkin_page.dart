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

class _CheckInPageState extends State<CheckInPage>
    with TickerProviderStateMixin {
  late final AnimationController _rippleController;
  late final AnimationController _bounceController;
  late final Animation<double> _rippleAnimation;
  late final Animation<double> _bounceAnimation;

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
                      _buildHeroCard(checkInProvider, levelProvider),
                      const SizedBox(height: 18),
                      _buildRewardPreview(checkInProvider),
                      const SizedBox(height: 18),
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

  Widget _buildAppBar(
    BuildContext context,
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    return SliverAppBar(
      expandedHeight: 196,
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
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
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
    UserLevelProvider levelProvider,
  ) {
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
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
                          color: _statusColor(ctaEnabled, hasChecked).withValues(
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
                      const SizedBox(height: 14),
                      Text(
                        _headlineText(hasChecked, isChecking),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: MoeTokens.titleText,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _descriptionText(checkInProvider, levelProvider),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                _buildCheckInButton(
                  checkInProvider: checkInProvider,
                  levelProvider: levelProvider,
                  hasChecked: hasChecked,
                  canCheckIn: canCheckIn,
                  isChecking: isChecking,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
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
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (enabled && !reduceMotion)
                  Container(
                    width: 120 + (_rippleAnimation.value * 28),
                    height: 120 + (_rippleAnimation.value * 28),
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
                  width: 120,
                  height: 120,
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
                        size: 34,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasChecked
                            ? '已签到'
                            : isChecking
                                ? '签到中'
                                : '立即签到',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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

  Widget _buildRewardPreview(CheckInProvider checkInProvider) {
    final streakTier = math.max(1, checkInProvider.consecutiveDays);
    final streakReward = 10 + (streakTier * 2);

    return MoeReveal(
      delay: const Duration(milliseconds: 160),
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
                    subtitle: checkInProvider.hasCheckedToday ? '今日已领取' : '完成后立即到账',
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

  Widget _buildStatsCard(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
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
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
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
