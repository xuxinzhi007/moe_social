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
import '../../providers/notification_provider.dart';
import '../../providers/main_nav_controller.dart';
import '../../widgets/post_card.dart';
import '../../widgets/home_stories_bar.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/personalized_card.dart';
import '../../widgets/ai_bot_badge.dart';
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

  String get _sectionTitle => _feed.sectionTitle();

  @override
  void initState() {
    super.initState();
    _feed = HomeFeedViewModel();
    _feed.addListener(_onFeedChanged);
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_scrollListener);
    unawaited(_feed.bootstrap());
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
    return AdaptivePageScaffold(
      template: PageTemplate.fullscreen,
      backgroundColor: MoeTheme.of(context).pageBackground,
      body: RefreshIndicator(
        onRefresh: () => _fetchPosts(resetContent: false),
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // SliverAppBar with TabBar in bottom 闂?Flutter-idiomatic, no SliverPersistentHeader needed
            _buildSliverAppBar(context),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
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
            // Topic tags row 闂?plain SliverToBoxAdapter, no dynamic-extent issues
            SliverToBoxAdapter(child: _buildFeedSectionTitle(context)),
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
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final expandedHeight = screenWidth < 360 ? 66.0 : 70.0;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
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
          icon: const Icon(Icons.search_rounded, color: MoeTokens.titleText),
          onPressed: () {
            MoeToast.info(
                context, '\u641c\u7d22\u529f\u80fd\u5373\u5c06\u4e0a\u7ebf');
          },
          tooltip: '\u641c\u7d22',
        ),
        IconButton(
          tooltip: 'AI \u52a9\u624b\u8bbe\u7f6e',
          onPressed: () =>
              Navigator.pushNamed(context, '/virtual-avatar-settings'),
          icon: const Icon(
            Icons.smart_toy_rounded,
            color: MoeTokens.titleText,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded,
              color: MoeTokens.titleText),
          onPressed: () => Navigator.pushNamed(context, '/scan'),
          tooltip: '\u626b\u7801\u6dfb\u52a0\u597d\u53cb',
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: MoeTokens.titleText),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
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

  Widget _buildFeedSectionTitle(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: MoeTokens.gradientPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sectionTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildFeedModeSwitcher(context)),
                const SizedBox(width: 8),
                _buildRefreshButton(),
              ],
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: MoeTokens.gradientPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sectionTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildFeedModeSwitcher(context),
                const SizedBox(width: 8),
                _buildRefreshButton(),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMetaChip(
                icon:
                    _feed.isRefreshing ? Icons.sync_rounded : Icons.schedule_rounded,
                text: _lastUpdatedText(),
              ),
              if (_feed.activeTopic != null)
                _buildMetaChip(
                  icon: Icons.filter_alt_rounded,
                  text: '#${_feed.activeTopic!.name}',
                  accentColor: _feed.activeTopic!.color,
                  onTap: () => _onTopicSelected(null),
                  trailing: const Icon(Icons.close_rounded, size: 14),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanionPresenceCard(BuildContext context) {
    final snapshot = _feed.companionSnapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final profile = snapshot.profile;
    final state = snapshot.state;
    final identity = _feed.communityIdentity;
    final agentKey = identity != null && identity.authorBotAgentKey.isNotEmpty
        ? identity.authorBotAgentKey
        : identity?.agentId;
    final name = profile.name.trim().isNotEmpty ? profile.name.trim() : 'AI 伙伴';
    final avatar =
        profile.emoji.trim().isNotEmpty ? profile.emoji.trim() : '🐾';
    final greeting =
        state.greeting.trim().isNotEmpty ? state.greeting.trim() : '今天也在社区里活动。';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MoeTokens.primary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MoeTokens.surface0,
                    borderRadius:
                        BorderRadius.circular(MoeTokens.radiusIconBg),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    avatar,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: MoeTokens.titleText,
                              ),
                            ),
                          ),
                          AiBotBadge(
                            compact: true,
                            agentKey: agentKey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildCompanionChip(
                    icon: Icons.chat_bubble_rounded,
                    label: '聊天',
                    onTap: () => Navigator.pushNamed(context, '/ai-chat'),
                  ),
                  const SizedBox(width: 8),
                  _buildCompanionChip(
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI 主页',
                    onTap: () => context.read<MainNavController>().requestTab(2),
                  ),
                  if (identity?.isValid == true) ...[
                    const SizedBox(width: 8),
                    _buildCompanionChip(
                      icon: Icons.edit_note_rounded,
                      label: '发动态',
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/create-post',
                        arguments: {'communityIdentity': identity},
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildCompanionChip(
                    icon: Icons.groups_rounded,
                    label: '社区',
                    onTap: () => Navigator.pushNamed(context, '/community'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return MoePressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: MoeTokens.surface0,
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: MoeTokens.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MoeTokens.titleText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    Color? accentColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final color = accentColor ?? MoeTokens.hintText;
    return InkWell(
      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accentColor != null
              ? accentColor.withValues(alpha: 0.14)
              : MoeTokens.surface1.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(
            color: accentColor != null
                ? color.withValues(alpha: 0.28)
                : MoeTokens.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              IconTheme(
                data: IconThemeData(color: color, size: 14),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedModeSwitcher(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _feed.mode == tab.mode;
          return Padding(
            padding: EdgeInsets.only(right: index == _tabs.length - 1 ? 0 : 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              onTap: () {
                if (_tabController.index == index) return;
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isSelected ? MoeTokens.gradientPrimary : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 13,
                      color: isSelected ? Colors.white : MoeTokens.hintText,
                    ),
                    const SizedBox(width: 5),
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

  Widget _buildRefreshButton() {
    return TextButton.icon(
      onPressed: _feed.isLoading || _feed.isRefreshing
          ? null
          : () => _fetchPosts(resetContent: false),
      style: TextButton.styleFrom(
        foregroundColor: MoeTokens.primary,
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: Text(_feed.isRefreshing ? '\u5237\u65b0\u4e2d' : '\u5237\u65b0'),
    );
  }

  String _lastUpdatedText() {
    if (_feed.isRefreshing) return '\u6b63\u5728\u5237\u65b0\u5185\u5bb9...';
    final updatedAt = _feed.lastUpdatedAt;
    if (updatedAt == null) {
      return '\u5c1a\u672a\u52a0\u8f7d\u6700\u65b0\u52a8\u6001';
    }
    final hour = updatedAt.hour.toString().padLeft(2, '0');
    final minute = updatedAt.minute.toString().padLeft(2, '0');
    return '\u6700\u540e\u66f4\u65b0 $hour:$minute';
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
