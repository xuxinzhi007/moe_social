import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../models/community_group.dart';
import '../../services/onboarding_preferences.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_reveal.dart';
import 'interest_onboarding_viewmodel.dart';

/// 新用户兴趣 onboarding（规则版）：选兴趣 → 推荐圈子一键加入 → 进入首页。
class InterestOnboardingPage extends StatefulWidget {
  const InterestOnboardingPage({super.key});

  @override
  State<InterestOnboardingPage> createState() => _InterestOnboardingPageState();
}

class _InterestOnboardingPageState extends State<InterestOnboardingPage> {
  late final InterestOnboardingViewModel _vm;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _vm = InterestOnboardingViewModel();
    _guardAlreadyCompleted();
  }

  Future<void> _guardAlreadyCompleted() async {
    final uid = AuthService.currentUser;
    if (uid == null || uid.isEmpty) return;
    final done = await OnboardingPreferences.isCompleted(uid);
    if (!mounted || !done) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final uid = AuthService.currentUser;
    if (uid != null && uid.isNotEmpty) {
      await OnboardingPreferences.markCompleted(uid, _vm.selectedNames);
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  Future<void> _goRecommendations() async {
    setState(() => _step = 1);
    await _vm.loadRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: MoeTokens.pageBackground,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: MoeTokens.motionMedium,
                        child: _step == 0
                            ? _buildInterestStep()
                            : _buildRecommendStep(),
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          if (_step == 1)
            IconButton(
              tooltip: '重选兴趣',
              onPressed: () => setState(() => _step = 0),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: MoeTokens.hintText),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Center(
              child: Text(
                _step == 0 ? '选择你的兴趣' : '为你找到的圈子',
                style: const TextStyle(
                  color: MoeTokens.titleText,
                  fontSize: MoeTokens.textLg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _finish,
            child: const Text(
              '先随便逛逛',
              style: TextStyle(
                color: MoeTokens.hintText,
                fontSize: MoeTokens.textSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestStep() {
    return SingleChildScrollView(
      key: const ValueKey('interests'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MoeReveal(
            child: Text(
              '选 1~5 个感兴趣的方向，\n帮你找到同好圈子',
              style: TextStyle(
                color: MoeTokens.titleText,
                fontSize: MoeTokens.text2xl,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: MoeTokens.space2xl),
          Wrap(
            spacing: MoeTokens.spaceMd,
            runSpacing: MoeTokens.spaceMd,
            children: [
              for (var i = 0;
                  i < InterestOnboardingViewModel.interests.length;
                  i++)
                MoeReveal(
                  delay: Duration(
                    milliseconds: 40 * i.clamp(0, 10),
                  ),
                  child: _InterestChip(
                    interest: InterestOnboardingViewModel.interests[i],
                    selected: _vm.isSelected(
                      InterestOnboardingViewModel.interests[i].id,
                    ),
                    onTap: () => _vm.toggleInterest(
                      InterestOnboardingViewModel.interests[i].id,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendStep() {
    if (_vm.loading && _vm.groups.isEmpty) {
      return const Center(key: ValueKey('loading'), child: MoeLoading());
    }
    if (_vm.error != null && _vm.groups.isEmpty) {
      return Center(
        key: const ValueKey('error'),
        child: MoeErrorState.fromError(
          _vm.error,
          scene: MoeErrorScene.community,
          onRetry: _vm.loadRecommendations,
        ),
      );
    }
    if (_vm.groups.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: MoeEmptyState(
          icon: Icons.travel_explore_rounded,
          title: '暂时没有匹配的圈子',
          subtitle: '先去社区逛逛，或在首页写下第一条心情',
          primaryAction: MoeEmptyStateAction(
            label: '进入首页',
            icon: Icons.home_rounded,
            onPressed: _finish,
          ),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('groups'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      itemCount: _vm.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final group = _vm.groups[index];
        return MoeReveal(
          delay: Duration(milliseconds: 40 * index.clamp(0, 10)),
          child: _GroupRecommendRow(
            group: group,
            joining: _vm.isJoining(group.id),
            onToggleJoin: () async {
              final error = await _vm.toggleJoin(group);
              if (error != null && context.mounted) {
                MoeToast.error(context, error);
              }
            },
            onOpen: () => Navigator.pushNamed(
              context,
              '/community/group',
              arguments: {'groupId': group.id, 'group': group},
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final isInterestStep = _step == 0;
    final enabled = isInterestStep ? _vm.selectedIds.isNotEmpty : true;
    final label = isInterestStep
        ? (_vm.selectedIds.isEmpty
            ? '看看推荐'
            : '看看推荐（已选 ${_vm.selectedIds.length} 个）')
        : '完成，进入首页';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: MoePressable(
        onTap: !enabled
            ? null
            : () {
                if (isInterestStep) {
                  unawaited(_goRecommendations());
                } else {
                  unawaited(_finish());
                }
              },
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: AnimatedOpacity(
          duration: MoeTokens.motionFast,
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: MoeTokens.primaryGradient,
              borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: MoeTokens.primary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: MoeTokens.textMd,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  final OnboardingInterest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      child: AnimatedContainer(
        duration: MoeTokens.motionFast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? MoeTokens.primaryGradient : null,
          color: selected ? null : MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(
            color: selected ? Colors.transparent : MoeTokens.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              interest.icon,
              size: 18,
              color: selected ? Colors.white : MoeTokens.primary,
            ),
            const SizedBox(width: 6),
            Text(
              interest.name,
              style: TextStyle(
                color: selected ? Colors.white : MoeTokens.titleText,
                fontSize: MoeTokens.textBase,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupRecommendRow extends StatelessWidget {
  const _GroupRecommendRow({
    required this.group,
    required this.joining,
    required this.onToggleJoin,
    required this.onOpen,
  });

  final CommunityGroup group;
  final bool joining;
  final VoidCallback onToggleJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final caption = group.description.trim().isEmpty
        ? '${group.memberCount} 人'
        : group.description.trim();
    return Material(
      color: MoeTokens.surface1,
      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            border: Border.all(color: MoeTokens.surfaceBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MoeTokens.titleText,
                        fontSize: MoeTokens.textBase,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$caption · ${group.memberCount} 人',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MoeTokens.hintText,
                        fontSize: MoeTokens.textSm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              MoePressable(
                onTap: joining ? null : onToggleJoin,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: AnimatedContainer(
                  duration: MoeTokens.motionFast,
                  width: 76,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: group.isJoined ? null : MoeTokens.primaryGradient,
                    color: group.isJoined ? MoeTokens.softChipBg : null,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    border: group.isJoined
                        ? Border.all(color: MoeTokens.surfaceBorder)
                        : null,
                  ),
                  child: Center(
                    child: joining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            group.isJoined ? '已加入' : '加入',
                            style: TextStyle(
                              color: group.isJoined
                                  ? MoeTokens.hintText
                                  : Colors.white,
                              fontSize: MoeTokens.textSm,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
