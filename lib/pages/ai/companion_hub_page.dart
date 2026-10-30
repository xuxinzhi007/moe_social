import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/feature_flags.dart';
import '../../providers/companion_presence_provider.dart';
import '../../services/companion_chat_launcher.dart';
import '../../services/companion_model_presence.dart';
import '../../services/companion_service.dart';
import '../../theme/moe_tokens.dart';
import 'companion_hub_viewmodel.dart';
import 'companion_profile_edit_page.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/companion_avatar.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_glass_surface.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_motion.dart';

/// AI 伙伴关系首页（产品叙事：长期陪伴；正式主路径入口）。
///
/// 决策 SSOT：`docs/dev/ai-companion-formal-decisions.md`（单活跃伙伴一期；酒馆退役向）。
class CompanionHubPage extends StatefulWidget {
  const CompanionHubPage({super.key});

  @override
  State<CompanionHubPage> createState() => _CompanionHubPageState();
}

/// 星辉远征入口和「TA 的今天」同时出现。
/// [arenaGamePrototype] 只保留给调用方标明当前开关，不再用来藏日常面板。
@visibleForTesting
bool shouldShowCompanionDailyPanels({required bool arenaGamePrototype}) {
  return arenaGamePrototype || !arenaGamePrototype;
}

class _CompanionHubPageState extends State<CompanionHubPage> {
  late final CompanionHubViewModel _hub;
  late final CompanionPresenceProvider _presence;
  bool _isChatLoading = false;
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _hub = CompanionHubViewModel();
    _hub.addListener(_onHubChanged);
    _presence = CompanionPresenceProvider.instance;
    _presence.addListener(_onPresenceChanged);
    _presence.setViewingCompanion(true);
    unawaited(_hub.loadDashboard());
    unawaited(CompanionModelPresence.instance.refresh());
  }

  void _onHubChanged() {
    if (mounted) setState(() {});
  }

  void _onPresenceChanged() {
    _hub.applyLivePresence(
      greeting: _presence.greeting,
      moodThought: _presence.moodThought,
      activityLabel: _presence.activityLabel,
    );
  }

  @override
  void dispose() {
    _presence.removeListener(_onPresenceChanged);
    _hub.removeListener(_onHubChanged);
    _hub.dispose();
    super.dispose();
  }

  Future<void> _openChat({String? draft}) async {
    if (_isChatLoading) return;
    setState(() => _isChatLoading = true);
    try {
      await CompanionChatLauncher.openChat(context, draft: draft);
      if (mounted) {
        unawaited(_presence.markCompanionChatSeen());
        unawaited(_hub.loadDashboard());
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  Future<void> _openArenaGame() async {
    if (!FeatureFlags.arenaGamePrototype) return;
    await Navigator.of(context).pushNamed('/game/arena');
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<CompanionProfileData>(
      MaterialPageRoute(
        builder: (_) => CompanionProfileEditPage(initial: _hub.profile),
      ),
    );
    if (saved == null || !mounted) return;

    setState(() => _isSavingProfile = true);
    try {
      await _hub.applyUpdatedProfile(saved);
      if (!mounted) return;
      MoeToast.success(context, '伙伴资料已更新');
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glassNav = FeatureFlags.glassNavigation;
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('AI伙伴'),
        centerTitle: true,
        backgroundColor: glassNav ? Colors.transparent : MoeTokens.surface1,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        flexibleSpace: glassNav
            ? MoeGlassSurface(
                tint: MoeTokens.surface1.withValues(alpha: 0.82),
                showBorder: false,
                child: const SizedBox.expand(),
              )
            : null,
        shape: const Border(
          bottom: BorderSide(color: MoeTokens.surfaceBorder),
        ),
        actions: const [
          _IdentityCardAction(),
          SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          if (_hub.loadError != null)
            MoeErrorState.fromError(
              _hub.loadError,
              scene: MoeErrorScene.generic,
              onRetry: _hub.loadDashboard,
            )
          else if (_hub.isLoading)
            const Center(child: MoeLoading())
          else
            RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _hub.loadDashboard(),
                  CompanionModelPresence.instance.refresh(),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Builder(
                    builder: (context) {
                      final presence =
                          context.watch<CompanionPresenceProvider>();
                      final hasAttention = presence.hasAttention;
                      final pulse = CompanionHubViewModel.buildPulseData(
                        profile: _hub.profile,
                        state: _hub.state,
                        dailyItems: _hub.dailyItems,
                        hasAttention: hasAttention,
                        attentionMessage: presence.attentionMessage,
                      );

                      return _HeroCard(
                        profile: _hub.profile,
                        state: _hub.state,
                        pulse: pulse,
                        onChat: _openChat,
                        onCustomize: _isSavingProfile ? null : _editProfile,
                      );
                    },
                  ),
                  if (FeatureFlags.arenaGamePrototype) ...[
                    const SizedBox(height: MoeTokens.spaceLg),
                    CompanionArenaGameEntry(onOpen: _openArenaGame),
                  ],
                ],
              ),
            ),
          if (_isChatLoading || _isSavingProfile)
            Positioned.fill(
              child: ColoredBox(
                color: MoeTokens.pageBackground.withValues(alpha: 0.45),
                child: const Center(child: MoeLoading()),
              ),
            ),
        ],
      ),
    );
  }
}

class CompanionArenaGameEntry extends StatelessWidget {
  const CompanionArenaGameEntry({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: '进入星辉远征',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MoeTokens.spaceLg,
            vertical: MoeTokens.spaceMd,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            boxShadow: MoeTokens.shadowMd(),
          ),
          child: const Row(
            children: [
              _ArenaSparkleIcon(),
              SizedBox(width: MoeTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '星辉远征',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: MoeTokens.titleText,
                              fontSize: MoeTokens.textMd,
                              fontWeight: MoeTokens.fontWeightTitle,
                            ),
                          ),
                        ),
                        SizedBox(width: MoeTokens.spaceSm),
                        _ArenaGameBadge(),
                      ],
                    ),
                    SizedBox(height: MoeTokens.spaceXs),
                    Text(
                      '卡牌小队冒险，进入后切换横屏',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MoeTokens.hintText,
                        fontSize: MoeTokens.textSm,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: MoeTokens.spaceSm),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: MoeTokens.hintText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 薰衣草星簇，对齐星辉远征入口原设计色调。
class _ArenaSparkleIcon extends StatelessWidget {
  const _ArenaSparkleIcon();

  static const Color _sparkle = MoeTokens.primary;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 8,
            child: Icon(Icons.auto_awesome, size: 20, color: _sparkle),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Icon(Icons.auto_awesome, size: 12, color: _sparkle),
          ),
          Positioned(
            right: 6,
            bottom: 2,
            child: Icon(Icons.auto_awesome, size: 9, color: _sparkle),
          ),
        ],
      ),
    );
  }
}

class _ArenaGameBadge extends StatelessWidget {
  const _ArenaGameBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceSm,
        vertical: MoeTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: MoeTokens.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      ),
      child: const Text(
        '试玩',
        style: TextStyle(
          color: MoeTokens.primary,
          fontSize: MoeTokens.textXs,
          fontWeight: MoeTokens.fontWeightSubtitle,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.profile,
    required this.state,
    required this.pulse,
    required this.onChat,
    this.onCustomize,
  });

  final CompanionProfileData profile;
  final CompanionStateData state;
  final CompanionPulseData pulse;
  final VoidCallback onChat;
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final name = profile.name.trim().isNotEmpty ? profile.name.trim() : 'AI 伙伴';
    final hasPersona = profile.persona.trim().isNotEmpty;
    final persona = hasPersona ? profile.persona.trim() : '会长期陪着你、慢慢懂你的虚拟伙伴。';

    final isAttention = pulse.kind == 'attention';
    final reduceMotion = moeReduceMotion(context);
    return AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MoeTokens.primary.withValues(alpha: 0.10),
            MoeTokens.pastelPink.withValues(alpha: 0.10),
            MoeTokens.pastelOrange.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAttention
              ? MoeTokens.pastelPink.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: isAttention
                ? MoeTokens.pastelPink.withValues(alpha: 0.20)
                : MoeTokens.primary.withValues(alpha: 0.10),
            blurRadius: isAttention ? 30 : 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoePressable(
                onTap: onCustomize,
                borderRadius: BorderRadius.circular(20),
                child: Semantics(
                  button: true,
                  label: '编辑伙伴',
                  child: CompanionAvatar(
                    emoji: profile.emoji,
                    avatarUrl: profile.avatarUrl,
                    size: 58,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AiBrandTokens.titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      persona,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: MoeTokens.inkMuted,
                      ),
                    ),
                    if (state.memoryNotice.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        state.memoryNotice.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: MoeTokens.pastelOrange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(99),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                child: const CompanionModelStatusChip(),
              ),
            ],
          ),
          if (!hasPersona && onCustomize != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onCustomize,
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('完善人设或从角色卡导入'),
              style: TextButton.styleFrom(
                foregroundColor: AiBrandTokens.primary,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
          const SizedBox(height: 12),
          MoePressable(
            onTap: onChat,
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            child: Semantics(
              button: true,
              label: isAttention ? '回复 TA' : '开始聊天',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                decoration: BoxDecoration(
                  color: MoeTokens.surface1,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                  border: Border.all(
                    color: MoeTokens.primary.withValues(alpha: 0.16),
                  ),
                  boxShadow: MoeTokens.shadowSm(),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: MoeTokens.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAttention ? '回复 TA' : '开始聊天',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: MoeTokens.titleText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAttention ? 'TA 有话想跟你说' : '接着刚才的话，继续聊',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MoeTokens.hintText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: MoeTokens.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: MoeTokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCardAction extends StatelessWidget {
  const _IdentityCardAction();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MoePressable(
        onTap: () => Navigator.pushNamed(context, '/character-card-plaza'),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        child: Semantics(
          button: true,
          label: '身份卡',
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: MoeTokens.surface1,
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              border: Border.all(
                color: MoeTokens.primary.withValues(alpha: 0.16),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.style_rounded, color: MoeTokens.primary, size: 16),
                SizedBox(width: 4),
                Text(
                  '身份卡',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.titleText,
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
