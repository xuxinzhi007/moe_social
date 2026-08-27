import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth_service.dart';
import '../../providers/main_nav_controller.dart';
import '../../services/companion_service.dart';
import '../../widgets/ai_bot_badge.dart';
import '../../widgets/moe_pinned_header_delegate.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_toast.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import 'community_discussions_tab.dart';
import 'interest_groups_page.dart';

/// 兴趣社区：圈子 + 讨论广场；与首页分工 — 首页偏关注/算法流，此处偏群组与同好内容发现。
///
/// 布局：NestedScrollView — 标题/AI 卡片随列表上滑，圈子|讨论 Tab 吸顶，符合移动端整页滑动。
class CommunityHomePage extends StatefulWidget {
  const CommunityHomePage({super.key});

  @override
  State<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends State<CommunityHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<InterestGroupsPageState> _groupsKey =
      GlobalKey<InterestGroupsPageState>();
  CompanionSnapshotData? _companionSnapshot;
  CompanionCommunityIdentityData? _communityIdentity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    unawaited(_loadCompanionPresence());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanionPresence() async {
    try {
      final snapshot = await CompanionService().getSnapshot();
      CompanionCommunityIdentityData? identity;
      if (snapshot.profile.agentId.trim().isNotEmpty) {
        try {
          identity = await CompanionService().getCommunityIdentity();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _companionSnapshot = snapshot;
        _communityIdentity = identity;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _companionSnapshot = null;
        _communityIdentity = null;
      });
    }
  }

  String get _subtitle {
    switch (_tabController.index) {
      case 0:
        return '发现同好圈子，加入一起讨论';
      case 1:
      default:
        return '按话题逛广场，发现新内容';
    }
  }

  void _onPrimaryActionPressed() {
    if (!AuthService.isLoggedIn) {
      MoeToast.error(context, '请先登录');
      return;
    }
    if (_tabController.index == 0) {
      _groupsKey.currentState?.showCreateGroup();
    } else {
      Navigator.pushNamed(context, '/create-post');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moe = MoeTheme.of(context);
    final onCirclesTab = _tabController.index == 0;
    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: moe.pageBackground,
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Row(
                    children: [
                      if (canGoBack)
                        IconButton(
                          tooltip: '返回',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const SizedBox(width: 4),
                      Expanded(
                        child: MoeReveal(
                          duration: MoeTokens.motionFadeDuration,
                          child: _buildHeader(scheme),
                        ),
                      ),
                      IconButton(
                        tooltip: onCirclesTab ? '新建群组' : '发帖',
                        onPressed: _onPrimaryActionPressed,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.12),
                          foregroundColor: scheme.primary,
                          // 主操作按钮走 iconBtn 档位尺寸
                          minimumSize: Size.square(MoeTokens.iconBtnMd),
                          iconSize: 24,
                        ),
                        icon: Icon(
                          onCirclesTab
                              ? Icons.add_rounded
                              : Icons.edit_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: MoePinnedHeaderDelegate(
                  height: 56,
                  background: moe.pageBackground,
                  child: MoeReveal(
                    duration: MoeTokens.motionFadeDuration,
                    delay: MoeTokens.motionStaggerStep,
                    child: _buildSegmented(scheme),
                  ),
                ),
              ),
              if (_companionSnapshot != null)
                SliverToBoxAdapter(
                  child: MoeReveal(
                    duration: MoeTokens.motionFadeDuration,
                    delay: const Duration(milliseconds: 120),
                    child: _buildCompanionPanel(),
                  ),
                ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              InterestGroupsPage(key: _groupsKey),
              const CommunityDiscussionsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '兴趣社区',
            style: TextStyle(
              fontSize: MoeTokens.textXl,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _subtitle,
              key: ValueKey<String>(_subtitle),
              style: TextStyle(
                fontSize: MoeTokens.textSm,
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmented(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
            color: scheme.primary.withValues(alpha: 0.12),
          ),
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: MoeTokens.textBase,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: MoeTokens.textBase,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: '圈子'),
            Tab(text: '讨论'),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionPanel() {
    final snapshot = _companionSnapshot!;
    final profile = snapshot.profile;
    final state = snapshot.state;
    final identity = _communityIdentity;
    final agentKey = identity != null && identity.authorBotAgentKey.isNotEmpty
        ? identity.authorBotAgentKey
        : identity?.agentId;
    final name = profile.name.trim().isNotEmpty ? profile.name.trim() : 'AI 伙伴';
    final emoji = profile.emoji.trim().isNotEmpty ? profile.emoji.trim() : '🐾';
    final status = state.greeting.trim().isNotEmpty
        ? state.greeting.trim()
        : '当前已接入社区身份，可直接参与互动。';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusCard),
          border: Border.all(color: MoeTokens.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MoeTokens.surface0,
                borderRadius: BorderRadius.circular(MoeTokens.radiusIconBg),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MoeTokens.titleText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AiBotBadge(compact: true, agentKey: agentKey),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      // 无精确对应 token，取最近语义色 inkMuted（次级灰）
                      color: MoeTokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'AI 主页',
              visualDensity: VisualDensity.compact,
              onPressed: () => context.read<MainNavController>().requestTab(2),
              icon: Icon(Icons.auto_awesome_rounded,
                  size: 20, color: MoeTokens.primary),
            ),
            IconButton(
              tooltip: '聊天',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pushNamed(context, '/ai-chat'),
              icon: Icon(Icons.chat_bubble_rounded,
                  size: 20, color: MoeTokens.primary),
            ),
          ],
        ),
      ),
    );
  }
}
