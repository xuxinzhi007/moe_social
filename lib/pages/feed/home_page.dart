// Hallmark · layout: sliver-cascade · tone: kawaii-soft · scroll: custom-scroll
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../auth_service.dart';
import '../../models/topic_tag.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../widgets/post_skeleton.dart';
import '../../utils/error_handler.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_error_state.dart';
import '../../utils/post_navigation.dart';
import '../../providers/companion_presence_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/home_stories_bar.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_motion.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/personalized_card.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import 'create_post_page.dart';
import 'home_feed_viewmodel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final HomeFeedViewModel _feed;
  late final CompanionPresenceProvider _presence;

  late TabController _tabController;

  final ScrollController _scrollController = ScrollController();
  Timer? _loadMoreTimer;

  /// Feed 入场动效去重：按「模式 + 话题 + 帖子 id」分桶，下拉刷新不重播。
  final Set<String> _revealedFeedKeys = {};

  static const _tabs = [
    (label: '热门', mode: HomeFeedMode.hot),
    (label: '最新', mode: HomeFeedMode.latest),
    (label: '关注', mode: HomeFeedMode.following),
  ];

  static const double _filterTabExtent = 52;
  static const double _filterTopicExtent = 40;

  @override
  void initState() {
    super.initState();
    _feed = HomeFeedViewModel();
    _feed.addListener(_onFeedChanged);
    _presence = CompanionPresenceProvider.instance;
    _presence.addListener(_onPresenceChanged);
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_scrollListener);
    unawaited(_feed.bootstrap());
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  void _onPresenceChanged() {
    _feed.applyLiveCompanionPresence(
      greeting: _presence.greeting,
      moodThought: _presence.moodThought,
      activityLabel: _presence.activityLabel,
    );
  }

  @override
  void dispose() {
    _presence.removeListener(_onPresenceChanged);
    _feed.removeListener(_onFeedChanged);
    _feed.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _loadMoreTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final newMode = _tabs[_tabController.index].mode;
    _feed.setMode(newMode);
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    if (_feed.isLoading || _feed.isLoadingMore || !_feed.hasMore) return;
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    final threshold = maxScroll > 0 ? maxScroll - 300 : 0;
    final isNearBottom = currentScroll >= threshold ||
        (maxScroll > 0 && currentScroll >= maxScroll - 50);
    if (isNearBottom) _scheduleLoadMore();
  }

  void _scheduleLoadMore() {
    _loadMoreTimer?.cancel();
    _loadMoreTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted &&
          !_feed.isLoading &&
          !_feed.isLoadingMore &&
          _feed.hasMore) {
        unawaited(_loadMorePosts());
      }
    });
  }

  Future<void> _openCreatePost() async {
    final result = await Navigator.pushNamed(context, '/create-post');
    await _handleCreatePostResult(result);
  }

  Future<void> _handleCreatePostResult(dynamic result) async {
    if (!mounted || result == null) return;
    if (result is Post) {
      _feed.insertCreatedPost(result);
    }
    await _fetchPosts(resetContent: false);
  }

  Future<void> _fetchPosts({bool resetContent = true}) async {
    try {
      await _feed.fetchPosts(resetContent: resetContent);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _fetchPosts(resetContent: false),
      _feed.loadCompanionPresence(),
    ]);
  }

  Future<void> _loadMorePosts() async {
    try {
      await _feed.loadMorePosts();
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(dynamic error) {
    if (mounted) {
      if (error is Exception) {
        ErrorHandler.handleException(context, error);
      } else {
        ErrorHandler.showError(context,
            '\u52a0\u8f7d\u9996\u9875\u52a8\u6001\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
      }
    }
  }

  void _toggleLike(String postId) {
    _feed.toggleLikeLocal(postId);
  }

  void _onTopicSelected(TopicTag? tag) {
    _feed.selectTopic(tag, fallbackMode: _tabs[_tabController.index].mode);
  }

  @override
  Widget build(BuildContext context) {
    // Feed 优先：轻顶栏 → Stories → 轻陪伴 → 粘性文字分段 → 帖子。
    // 发帖入口固定在筛选栏右侧，不叠加 FAB 或大海报。
    return AdaptivePageScaffold(
      template: PageTemplate.fullscreen,
      backgroundColor: MoeTheme.of(context).pageBackground,
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: PersonalizedCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: const HomeStoriesBar(),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeFeedFilterHeader(
                height: _feed.availableTags.isEmpty
                    ? _filterTabExtent
                    : _filterTabExtent + _filterTopicExtent,
                background: MoeTheme.of(context).pageBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _filterTabExtent,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          MoeTokens.spaceLg,
                          MoeTokens.spaceSm,
                          MoeTokens.spaceLg,
                          0,
                        ),
                        child: _buildFeedModeSwitcher(context),
                      ),
                    ),
                    if (_feed.availableTags.isNotEmpty)
                      SizedBox(
                        height: _filterTopicExtent,
                        child: _buildTopicFilterRow(context),
                      ),
                  ],
                ),
              ),
            ),
            if (_feed.feedError != null && _feed.displayPosts.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildInlineErrorBanner(
                  message: MoeErrorCopy.resolve(_feed.feedError,
                          scene: MoeErrorScene.feed)
                      .subtitle,
                  onRetry: () => _fetchPosts(resetContent: false),
                ),
              ),
            if (_feed.isLoading && _feed.displayPosts.isEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const PostSkeleton(),
                  childCount: 6,
                ),
              )
            else if (_feed.feedError != null && _feed.displayPosts.isEmpty)
              SliverToBoxAdapter(
                child: _buildFeedErrorState(),
              )
            else if (!_feed.isLoading && _feed.displayPosts.isEmpty)
              SliverToBoxAdapter(child: _buildFeedEmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => MoeStaggerReveal(
                    index: index,
                    itemKey: _feed.feedRevealKey(_feed.displayPosts[index].id),
                    revealedKeys: _revealedFeedKeys,
                    child: _buildPostCard(_feed.displayPosts[index]),
                  ),
                  childCount: _feed.displayPosts.length,
                ),
              ),
            SliverToBoxAdapter(child: _buildBottomIndicator()),
            const SliverToBoxAdapter(child: SizedBox(height: 72)),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    // 精简：去掉未上线的搜索、与「我的/悬浮助手」重复的 AI 设置入口。
    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: MoeTokens.surface1,
      surfaceTintColor: Colors.transparent,
      foregroundColor: MoeTokens.titleText,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: MoeTokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: MoeTokens.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Moe Social',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: MoeTokens.titleText,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded,
              color: MoeTokens.titleText),
          onPressed: () => Navigator.pushNamed(context, '/scan'),
          tooltip: '扫码添加好友',
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: MoeTokens.titleText),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
              tooltip: '通知',
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.activityUnreadCount == 0) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  top: 6,
                  right: 4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MoeTokens.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: MoeTokens.danger,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      provider.activityUnreadCount > 99
                          ? '99+'
                          : '${provider.activityUnreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: MoeTokens.textXs,
                        fontWeight: MoeTokens.fontWeightSubtitle,
                        height: 1.1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTopicFilterRow(BuildContext context) {
    final tags = _feed.availableTags;
    if (tags.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceLg,
        MoeTokens.spaceXs,
        MoeTokens.spaceLg,
        MoeTokens.spaceSm,
      ),
      itemCount: tags.length,
      separatorBuilder: (_, __) => const SizedBox(width: MoeTokens.spaceSm),
      itemBuilder: (context, index) {
        final tag = tags[index];
        return _HomeTopicChip(
          name: tag.name,
          selected: _feed.activeTopic?.id == tag.id,
          onTap: () => _onTopicSelected(tag),
        );
      },
    );
  }

  Widget _buildFeedModeSwitcher(BuildContext context) {
    // topic 模式下不高亮任一 Tab，点 Tab 会清话题回到该模式。
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (final entry in _tabs.asMap().entries)
                _HomeFeedModeTab(
                  label: entry.value.label,
                  selected: _feed.mode == entry.value.mode,
                  onTap: () {
                    if (_tabController.index != entry.key) {
                      _tabController.animateTo(entry.key);
                      return;
                    }
                    if (_feed.activeTopic != null ||
                        _feed.mode != entry.value.mode) {
                      _feed.setMode(entry.value.mode);
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(width: MoeTokens.spaceSm),
        _HomeComposeButton(onTap: _openCreatePost),
      ],
    );
  }

  Widget _buildInlineErrorBanner({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: MoeTokens.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(
            color: MoeTokens.warning.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: MoeTokens.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MoeTokens.titleText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _feed.isLoading || _feed.isRefreshing ? null : onRetry,
              child: const Text('\u91cd\u8bd5'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: MoeErrorState.fromError(
        _feed.feedError,
        scene: MoeErrorScene.feed,
        onRetry: () {
          if (_feed.isLoading) return;
          _fetchPosts(resetContent: true);
        },
      ),
    );
  }

  Widget _buildFeedEmptyState() {
    if (_feed.mode == HomeFeedMode.following) {
      return MoeEmptyState(
        icon: Icons.star_border_rounded,
        title: '关注的人还没有发动态',
        subtitle: '先去社区逛逛话题，或者去好友页认识新朋友，让首页慢慢热闹起来。',
        primaryAction: MoeEmptyStateAction(
          label: '去社区',
          icon: Icons.forum_rounded,
          onPressed: () => Navigator.pushNamed(context, '/community'),
        ),
        secondaryAction: MoeEmptyStateAction(
          label: '找好友',
          icon: Icons.people_rounded,
          onPressed: () => Navigator.pushNamed(context, '/friends'),
        ),
      );
    }

    final topicName = _feed.activeTopic?.name;
    final inTopic = _feed.activeTopic != null;
    return MoeEmptyState(
      icon: Icons.auto_awesome_rounded,
      title: inTopic ? '${topicName ?? ''}下暂时还没有动态' : '这里还是空的',
      subtitle:
          inTopic ? '换个话题看看，或者自己发一条带上这个标签的动态吧。' : '发一条动态记录今天，或者去好友页认识新朋友。',
      primaryAction: MoeEmptyStateAction(
        label: '发布动态',
        icon: Icons.edit_rounded,
        onPressed: _openCreatePost,
      ),
      secondaryAction: MoeEmptyStateAction(
        label: '找好友',
        icon: Icons.people_rounded,
        onPressed: () => Navigator.pushNamed(context, '/friends'),
      ),
    );
  }

  Widget _buildBottomIndicator() {
    if (_feed.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: const MoeSmallLoading(),
            label: '加载更多中...',
          ),
        ),
      );
    } else if (_feed.loadMoreErrorMessage != null &&
        _feed.displayPosts.isNotEmpty &&
        !_feed.isLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: const Icon(
              Icons.error_outline_rounded,
              color: MoeTokens.pastelOrange,
              size: 18,
            ),
            label: '加载更多失败',
            accentColor: MoeTokens.pastelOrange,
            trailing: TextButton(
              onPressed: _feed.isLoadingMore ? null : _loadMorePosts,
              child: const Text('重试'),
            ),
          ),
        ),
      );
    } else if (!_feed.hasMore && _feed.displayPosts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: Icon(
              Icons.check_circle_outline_rounded,
              color: MoeTokens.hintText,
              size: 18,
            ),
            label: '已经到底啦 ~',
          ),
        ),
      );
    } else if (_feed.hasMore && !_feed.isLoading && !_feed.isRefreshing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: (_feed.isLoadingMore || _feed.isRefreshing)
                ? null
                : () {
                    if (!_feed.isLoading &&
                        !_feed.isRefreshing &&
                        !_feed.isLoadingMore &&
                        _feed.hasMore) {
                      _loadMorePosts();
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: MoeTokens.gradientPrimary,
                borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                border: Border.all(color: MoeTokens.surfaceBorder),
                boxShadow: MoeTokens.shadowSm(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '\u70b9\u51fb\u52a0\u8f7d\u66f4\u591a',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomStateCapsule({
    required Widget icon,
    required String label,
    Color? accentColor,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MoeTokens.surface1.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: MoeTokens.titleText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    Future<void> openDetail() async {
      final result = await openPostDetail(context, post);
      if (!mounted || result == null) return;
      _feed.updatePostComments(post.id, result);
    }

    return PostCard(
      key: ValueKey('home_post_${post.id}'),
      post: post,
      onCardTap: () => unawaited(openDetail()),
      onLike: () => _toggleLike(post.id),
      onComment: () => unawaited(openDetail()),
      onAvatarTap: () {
        Navigator.pushNamed(context, '/user-profile', arguments: {
          'userId': post.userId,
          'userName': post.userName,
          'userAvatar': post.userAvatar,
          'heroTag': 'avatar_${post.id}',
        });
      },
      onEdit: post.userId == (AuthService.currentUser ?? '')
          ? () async {
              final updated = await Navigator.push<Post>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePostPage(initialPost: post),
                ),
              );
              if (updated != null && mounted) {
                _feed.mergeUpdatedPost(updated, post);
              }
            }
          : null,
      onDelete: post.userId == (AuthService.currentUser ?? '')
          ? () async {
              try {
                await PostService.deletePost(post.id);
                if (!mounted) return;
                _feed.removePost(post.id);
              } catch (e) {
                if (mounted) {
                  ErrorHandler.showError(context, '删除失败，请稍后重试');
                }
              }
            }
          : null,
    );
  }
}

/// 粘性热门/最新/关注 + 话题行（对标小红书文字分段）。
class _HomeFeedFilterHeader extends SliverPersistentHeaderDelegate {
  _HomeFeedFilterHeader({
    required this.height,
    required this.child,
    required this.background,
  });

  final double height;
  final Widget child;
  final Color background;

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
    final pinned = overlapsContent || shrinkOffset > 0;
    return ColoredBox(
      color: background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: pinned ? MoeTokens.surfaceBorder : Colors.transparent,
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeFeedFilterHeader oldDelegate) {
    return height != oldDelegate.height ||
        background != oldDelegate.background ||
        child != oldDelegate.child;
  }
}

class _HomeFeedModeTab extends StatelessWidget {
  const _HomeFeedModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = moeReduceMotion(context);
    final duration = reduceMotion ? Duration.zero : MoeTokens.motionFast;
    final style = TextStyle(
      fontSize: selected ? MoeTokens.textLg : MoeTokens.textBase,
      fontWeight:
          selected ? MoeTokens.fontWeightTitle : MoeTokens.fontWeightBody,
      color: selected ? MoeTokens.titleText : MoeTokens.hintText,
      height: 1.2,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.only(right: MoeTokens.spaceLg),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeInOut,
                  style: style,
                  child: Text(label),
                ),
                const SizedBox(height: MoeTokens.spaceXs),
                AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeInOut,
                  width: selected ? MoeTokens.spaceLg : 0,
                  height: MoeTokens.spaceXs,
                  decoration: BoxDecoration(
                    color: MoeTokens.primary,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
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

class _HomeComposeButton extends StatelessWidget {
  const _HomeComposeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '发动态',
      excludeSemantics: true,
      child: MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MoeTokens.spaceMd,
            vertical: MoeTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            gradient: MoeTokens.gradientPrimary,
            borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
            boxShadow: MoeTokens.shadowSm(),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, size: 14, color: Colors.white),
              SizedBox(width: MoeTokens.spaceXs),
              Text(
                '发帖',
                style: TextStyle(
                  fontSize: MoeTokens.textSm,
                  fontWeight: MoeTokens.fontWeightSubtitle,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTopicChip extends StatelessWidget {
  const _HomeTopicChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = moeReduceMotion(context);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : MoeTokens.motionFast,
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: MoeTokens.spaceMd,
            vertical: MoeTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? MoeTokens.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: MoeTokens.textSm,
              fontWeight: selected
                  ? MoeTokens.fontWeightSubtitle
                  : MoeTokens.fontWeightCaption,
              color: selected ? MoeTokens.primary : MoeTokens.caption,
            ),
          ),
        ),
      ),
    );
  }
}
