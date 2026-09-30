import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkin_record.dart';
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
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
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
      unawaited(_loadStoredHistory(checkInProvider));
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
              _buildAppBar(context),
              if (initialLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: MoeLoading()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    MoeTokens.spaceLg,
                    MoeTokens.spaceSm,
                    MoeTokens.spaceLg,
                    MoeTokens.space2xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeroCard(
                        checkInProvider,
                        levelProvider,
                        isCompact: isCompact,
                      ),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: MoeTokens.pageBackground,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: MoeTokens.titleText),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '每日签到',
        style: TextStyle(
          color: MoeTokens.titleText,
          fontSize: 18,
          fontWeight: MoeTokens.fontWeightTitle,
        ),
      ),
      actions: [
        IconButton(
          tooltip: '今日明细',
          icon: const Icon(Icons.checklist_rounded, color: MoeTokens.inkMuted),
          onPressed: () => _showDetailsSheet(context),
        ),
      ],
    );
  }

  Future<void> _loadStoredHistory(CheckInProvider provider) async {
    const pageSize = 100;
    await provider.loadCheckInHistory(
      widget.userId,
      refresh: true,
      pageSize: pageSize,
    );
    var guard = 0;
    while (mounted && provider.hasMoreHistory && guard < 12) {
      guard++;
      await provider.loadCheckInHistory(widget.userId, pageSize: pageSize);
    }
  }

  CheckInRecord? _recordOn(DateTime day, CheckInProvider provider) {
    for (final record in provider.checkInHistory) {
      final parsed = record.checkInDateTime;
      if (parsed == null) continue;
      if (parsed.year == day.year &&
          parsed.month == day.month &&
          parsed.day == day.day) {
        return record;
      }
    }
    return null;
  }

  bool _dayIsStamped(DateTime day, DateTime today, CheckInProvider provider) {
    if (day.isAfter(today)) return false;
    if (_recordOn(day, provider) != null) return true;
    if (provider.checkInHistory.isNotEmpty) return false;
    final gap = today.difference(day).inDays;
    if (provider.hasCheckedToday) return gap < provider.consecutiveDays;
    return gap >= 1 && gap <= provider.consecutiveDays;
  }

  void _onStampTap({
    required DateTime day,
    required bool isToday,
    required bool isFuture,
    required bool stamped,
    required CheckInProvider checkInProvider,
    required UserLevelProvider levelProvider,
  }) {
    if (isFuture) {
      MoeToast.info(context, '这一天还没到');
      return;
    }
    if (isToday &&
        checkInProvider.canCheckIn &&
        !checkInProvider.hasCheckedToday &&
        !checkInProvider.isCheckingIn) {
      _performCheckIn(checkInProvider, levelProvider);
      return;
    }
    if (stamped) {
      final record = _recordOn(day, checkInProvider);
      final exp = record?.expReward;
      MoeToast.info(
        context,
        exp == null ? '这一天已经盖过章了' : '这一天已签到，+$exp EXP',
      );
      return;
    }
    MoeToast.info(context, '这天没有签到');
  }

  bool _canShiftMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final earliest = DateTime(now.year, now.month - 11);
    return !next.isAfter(current) && !next.isBefore(earliest);
  }

  void _shiftMonth(int delta) {
    if (!_canShiftMonth(delta)) return;
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  Widget _buildMonthCalendar({
    required List<String> labels,
    required DateTime today,
    required CheckInProvider checkInProvider,
    required UserLevelProvider levelProvider,
    required bool isChecking,
    required bool reduceMotion,
  }) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cellCount = lead + daysInMonth;
    final rows = (cellCount / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _canShiftMonth(-1) ? () => _shiftMonth(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: MoeTokens.titleText,
            ),
            Expanded(
              child: Text(
                '${first.year}年${first.month}月',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: MoeTokens.titleText,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _canShiftMonth(1) ? () => _shiftMonth(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
              color: MoeTokens.titleText,
            ),
          ],
        ),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MoeTokens.inkMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: MoeTokens.spaceSm),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: MoeTokens.spaceXs),
            child: Row(
              children: List.generate(7, (column) {
                final index = row * 7 + column;
                if (index < lead || index >= lead + daysInMonth) {
                  return const Expanded(child: SizedBox(height: 36));
                }
                final day = DateTime(first.year, first.month, index - lead + 1);
                final isToday = day == today;
                final isFuture = day.isAfter(today);
                final stamped = _dayIsStamped(day, today, checkInProvider);
                return Expanded(
                  child: AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) => Transform.scale(
                      scale:
                          isToday && !reduceMotion ? _bounceAnimation.value : 1,
                      child: child,
                    ),
                    child: _WeekStamp(
                      day: day.day,
                      isToday: isToday,
                      isFuture: isFuture,
                      stamped: stamped,
                      pulsing: isToday && isChecking && !reduceMotion,
                      pulse: _rippleAnimation,
                      onTap: () => _onStampTap(
                        day: day,
                        isToday: isToday,
                        isFuture: isFuture,
                        stamped: stamped,
                        checkInProvider: checkInProvider,
                        levelProvider: levelProvider,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final levelGradient = levelProvider.userLevel != null
        ? levelProvider.getLevelGradient(levelProvider.currentLevel)
        : const [MoeTokens.primary, MoeTokens.secondary];
    final reduceMotion = moeReduceMotion(context);

    return MoeReveal(
      delay: const Duration(milliseconds: 80),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          MoeTokens.spaceLg,
          MoeTokens.spaceLg,
          MoeTokens.spaceLg,
          MoeTokens.spaceMd,
        ),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MoeTokens.spaceSm,
                    vertical: MoeTokens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(ctaEnabled, hasChecked)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
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
                const Spacer(),
                Text(
                  '连续 ${checkInProvider.consecutiveDays} 天',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MoeTokens.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MoeTokens.spaceMd),
            Text(
              _headlineText(hasChecked, isChecking),
              style: TextStyle(
                fontSize: isCompact ? 18 : 20,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
                height: 1.2,
              ),
            ),
            const SizedBox(height: MoeTokens.spaceXs),
            Text(
              hasChecked ? '明天再来，印章会接着往后盖。' : '点今天这一格，把印章盖进日历。',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: MoeTokens.inkMuted,
              ),
            ),
            const SizedBox(height: MoeTokens.spaceMd),
            _buildMonthCalendar(
              labels: labels,
              today: today,
              checkInProvider: checkInProvider,
              levelProvider: levelProvider,
              isChecking: isChecking,
              reduceMotion: reduceMotion,
            ),
            const SizedBox(height: MoeTokens.spaceLg),
            MoePressable(
              onTap: ctaEnabled
                  ? () => _performCheckIn(checkInProvider, levelProvider)
                  : null,
              pressedScale: MoeTokens.motionPressScale,
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              child: AnimatedContainer(
                duration: reduceMotion ? Duration.zero : MoeTokens.motionMedium,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: ctaEnabled ? MoeTokens.gradientPrimary : null,
                  color: ctaEnabled
                      ? null
                      : hasChecked
                          ? MoeTokens.pastelTeal.withValues(alpha: 0.16)
                          : MoeTokens.softChipBg,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: Text(
                  hasChecked
                      ? '今日已盖章  +${checkInProvider.todayReward} EXP'
                      : isChecking
                          ? '正在盖章…'
                          : '盖下今日印章  +${checkInProvider.todayReward} EXP',
                  style: TextStyle(
                    color: ctaEnabled
                        ? Colors.white
                        : hasChecked
                            ? MoeTokens.pastelTeal
                            : MoeTokens.inkMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: MoeTokens.spaceMd),
            Row(
              children: [
                Text(
                  'Lv.${levelProvider.currentLevel} ${levelProvider.levelTitle}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: levelGradient.first,
                  ),
                ),
                const Spacer(),
                Text(
                  levelProvider.isMaxLevel
                      ? '已满级'
                      : '还差 ${levelProvider.expToNext}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MoeTokens.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MoeTokens.spaceSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              child: LinearProgressIndicator(
                value: levelProvider.progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: MoeTokens.softChipBg,
                valueColor: AlwaysStoppedAnimation<Color>(levelGradient.first),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardPreview(CheckInProvider checkInProvider) {
    final streakTier = math.max(1, checkInProvider.consecutiveDays);
    final streakReward = 10 + (streakTier * 2);

    return MoeReveal(
      delay: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.all(MoeTokens.spaceLg),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '这一周的收获',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '连续 ${checkInProvider.consecutiveDays} 天，下次大约再加 $streakReward EXP。',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: MoeTokens.inkMuted,
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
        padding: const EdgeInsets.all(MoeTokens.spaceLg),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '今天还可以做',
                    style: TextStyle(
                      fontSize: 15,
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
            const SizedBox(height: MoeTokens.spaceMd),
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
        title: '等级成长',
        subtitle: levelProvider.isMaxLevel
            ? '当前已经达到最高等级，今天继续保持活跃就好。'
            : '距离下一等级还差 $nextLevelExp EXP，成长结果以后端记录为准。',
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

  Widget _buildStatsCard(
    CheckInProvider checkInProvider,
    UserLevelProvider levelProvider,
  ) {
    return MoeReveal(
      delay: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.all(MoeTokens.spaceLg),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '成长',
              style: TextStyle(
                fontSize: 15,
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

  Widget _buildRewardPanel({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceMd),
      decoration: BoxDecoration(
        color: colors.first.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.first, size: 18),
          const SizedBox(height: MoeTokens.spaceSm),
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

  String _headlineText(bool hasChecked, bool isChecking) {
    if (isChecking) return '正在把今日奖励送到你手里';
    if (hasChecked) return '今日签到已完成';
    return '把今天的成长先拿下';
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

  void _showDetailsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
            ),
            margin: const EdgeInsets.fromLTRB(
              MoeTokens.spaceMd,
              0,
              MoeTokens.spaceMd,
              MoeTokens.spaceMd,
            ),
            padding: const EdgeInsets.fromLTRB(
              MoeTokens.spaceLg,
              MoeTokens.spaceMd,
              MoeTokens.spaceLg,
              MoeTokens.spaceLg,
            ),
            decoration: BoxDecoration(
              color: MoeTokens.pageBackground,
              borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
            ),
            child: Consumer2<CheckInProvider, UserLevelProvider>(
              builder: (context, checkInProvider, levelProvider, _) {
                return ListView(
                  shrinkWrap: true,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin:
                            const EdgeInsets.only(bottom: MoeTokens.spaceMd),
                        decoration: BoxDecoration(
                          color: MoeTokens.lineSoft,
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusFull),
                        ),
                      ),
                    ),
                    const Text(
                      '今日明细',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    const SizedBox(height: MoeTokens.spaceMd),
                    _buildTaskList(checkInProvider, levelProvider),
                    const SizedBox(height: MoeTokens.spaceMd),
                    _buildRewardPreview(checkInProvider),
                    const SizedBox(height: MoeTokens.spaceMd),
                    _buildStatsCard(checkInProvider, levelProvider),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _WeekStamp extends StatelessWidget {
  const _WeekStamp({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.stamped,
    required this.pulsing,
    required this.pulse,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isFuture;
  final bool stamped;
  final bool pulsing;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = moeReduceMotion(context);
    final ink = isFuture
        ? MoeTokens.hintText
        : stamped
            ? MoeTokens.primary
            : MoeTokens.titleText;
    return MoePressable(
      onTap: onTap,
      pressedScale: MoeTokens.motionPressScale,
      borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final scale =
                  pulsing && !reduceMotion ? 1 + pulse.value * 0.12 : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stamped
                    ? MoeTokens.primary.withValues(alpha: 0.14)
                    : isToday
                        ? MoeTokens.softLavenderBg
                        : MoeTokens.softChipBg,
                border: Border.all(
                  color: isToday ? MoeTokens.primary : Colors.transparent,
                  width: isToday ? 1.4 : 0,
                ),
              ),
              child: stamped
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: MoeTokens.primary,
                    )
                  : Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
