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
import '../../providers/main_nav_controller.dart';
import '../../widgets/post_card.dart';
import '../../widgets/home_stories_bar.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/ai/companion_avatar.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../widgets/motion/moe_pressable.dart';
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
    (
      label: '\u70ed\u95e8',
      icon: Icons.whatshot_rounded,
      mode: HomeFeedMode.hot
    ),
    (
      label: '\u6700\u65b0',
      icon: Icons.new_releases_rounded,
      mode: HomeFeedMode.latest
    ),
    (
      label: '\u5173\u6ce8',
      icon: Icons.star_rounded,
      mode: HomeFeedMode.following
    ),
  ];

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
    // Feed 优先：轻顶栏 → Stories「+」→ 轻陪伴 → 粘性分段 → 帖子。
    // 发帖只保留 Stories 左侧「+」，不再叠 FAB / 大海报。
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
              child:
                  HomeStoriesBar(onCreatePostSuccess: _handleCreatePostResult),
            ),
            SliverToBoxAdapter(
              child: _buildCompanionPresenceCard(context),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeFeedFilterHeader(
                height: _feed.availableTags.isEmpty ? 52 : 92,
                background: MoeTheme.of(context).pageBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildFeedModeSwitcher(context),
                    ),
                    if (_feed.availableTags.isNotEmpty)
                      Expanded(child: _buildTopicFilterRow(context)),
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
              gradient: MoeTokens.gradientPrimary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) =>
                MoeTokens.gradientText.createShader(bounds),
            child: const Text(
              'Moe Social',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
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
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: MoeTokens.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 8, minHeight: 8),
                    child: provider.activityUnreadCount > 99
                        ? const Text(
                            '99+',
                            style: TextStyle(color: Colors.white, fontSize: 8),
                          )
                        : null,
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      itemCount: tags.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final tag = tags[index];
        final selected = _feed.activeTopic?.id == tag.id;
        return FilterChip(
          selected: selected,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          avatar: Icon(
            Icons.tag_rounded,
            size: 14,
            color: selected ? Colors.white : tag.color,
          ),
          label: Text('#${tag.name}'),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : MoeTokens.titleText,
          ),
          selectedColor: tag.color,
          backgroundColor: tag.color.withValues(alpha: 0.10),
          side: BorderSide(
            color: selected ? tag.color : tag.color.withValues(alpha: 0.28),
          ),
          onSelected: (_) => _onTopicSelected(tag),
        );
      },
    );
  }

  Widget _buildCompanionPresenceCard(BuildContext context) {
    final snapshot = _feed.companionSnapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final profile = snapshot.profile;
    final state = snapshot.state;
    final name = profile.name.trim().isNotEmpty ? profile.name.trim() : 'AI 伙伴';
    final greeting = state.greeting.trim().isNotEmpty
        ? state.greeting.trim()
        : (state.moodThought.trim().isNotEmpty
            ? state.moodThought.trim()
            : '想你了，去看看 TA 吧');
    final wantsYou =
        context.watch<CompanionPresenceProvider>().hasAttention;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: MoePressable(
        onTap: () => context.read<MainNavController>().requestTab(2),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: wantsYou
                  ? const Color(0xFFE97891).withValues(alpha: 0.35)
                  : MoeTokens.primary.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CompanionAvatar(
                emoji: profile.emoji,
                avatarUrl: profile.avatarUrl,
                size: 40,
                borderRadius: BorderRadius.circular(MoeTokens.radiusIconBg),
                backgroundColor: MoeTokens.surface0,
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: MoeTokens.titleText,
                            ),
                          ),
                        ),
                        if (wantsYou) ...[
                          const SizedBox(width: 6),
                          Text(
                            '想你了',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.pink.shade400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedModeSwitcher(BuildContext context) {
    // topic 模式下不高亮任一 Tab，点 Tab 会清话题回到该模式。
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Row(
        children: _tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _feed.mode == tab.mode;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              onTap: () {
                if (_tabController.index != index) {
                  _tabController.animateTo(index);
                  return;
                }
                // 已在该 Tab 但处于话题筛选时：点一次清话题回到该模式。
                if (_feed.activeTopic != null || _feed.mode != tab.mode) {
                  _feed.setMode(tab.mode);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? MoeTokens.gradientPrimary : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 14,
                      color: isSelected ? Colors.white : MoeTokens.hintText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : MoeTokens.hintText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
      title: inTopic ? '#${topicName ?? ''} 下暂时还没有动态' : '这里还是空的',
      subtitle: inTopic
          ? '换个话题看看，或者自己发一条带上这个标签的动态吧。'
          : '发一条动态记录今天，或者去好友页认识新朋友。',
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

/// 粘性热门/最新/关注 + 话题行（对标小红书顶部分段）。
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
    return Material(
      color: background,
      elevation: overlapsContent || shrinkOffset > 0 ? 0.5 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _HomeFeedFilterHeader oldDelegate) {
    return height != oldDelegate.height ||
        background != oldDelegate.background ||
        child != oldDelegate.child;
  }
}
