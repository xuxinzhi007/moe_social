import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                        tooltip: onCirclesTab ? '搜索圈子' : '搜索动态',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pushNamed(
                            context,
                            onCirclesTab
                                ? '/community-group-search'
                                : '/community-search',
                          );
                        },
                        icon: Icon(
                          Icons.search_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        tooltip: onCirclesTab ? '新建群组' : '发帖',
                        onPressed: _onPrimaryActionPressed,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.12),
                          foregroundColor: scheme.primary,
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
                delegate: _PinnedSegmentBarDelegate(
                  height: 56,
                  backgroundColor: moe.pageBackground,
                  child: MoeReveal(
                    duration: MoeTokens.motionFadeDuration,
                    delay: MoeTokens.motionStaggerStep,
                    child: _buildSegmented(scheme),
                  ),
                ),
              ),
              // ── 社交主壳收口（2026-11-04）：陪伴卡已移出社区首屏 ──
              // 增强层回自己的 Tab；社区首问还给「找同好」。
              // 详见 docs/product/convergence-social-shell-2026-11-04.md
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

}

class _PinnedSegmentBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedSegmentBarDelegate({
    required this.child,
    required this.height,
    required this.backgroundColor,
  });

  final Widget child;
  final double height;
  final Color backgroundColor;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 0.5 : 0,
      shadowColor: Colors.black26,
      child: SizedBox(height: height, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedSegmentBarDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
