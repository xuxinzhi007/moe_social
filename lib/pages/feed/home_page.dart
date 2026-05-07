import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../auth_service.dart';
import '../../models/topic_tag.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/post_service.dart';
import '../../services/like_state_manager.dart';
import '../../widgets/post_skeleton.dart';
import '../../utils/error_handler.dart';
import '../../utils/post_navigation.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/personalized_card.dart';
import '../../widgets/quick_actions_grid.dart';
import '../../widgets/home_stories_bar.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/fade_in_up.dart';
import 'create_post_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<Post> _allPosts = [];
  List<Post> _displayPosts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 10;
  String? _feedErrorMessage;
  String? _loadMoreErrorMessage;
  DateTime? _lastUpdatedAt;
  bool _isPrimaryRequestInFlight = false;
  bool _shouldReloadAfterCurrent = false;
  bool _queuedResetContent = false;
  bool _isLoadMoreRequestInFlight = false;

  _HomeFeedMode _mode = _HomeFeedMode.hot;
  TopicTag? _activeTopic;

  late TabController _tabController;

  // Available topic tags collected from loaded posts + official tags
  List<TopicTag> _availableTags = [];

  final ScrollController _scrollController = ScrollController();
  Timer? _loadMoreTimer;
  final LikeStateManager _likeManager = LikeStateManager();

  static const _tabs = [
    (label: '热门', icon: Icons.whatshot_rounded, mode: _HomeFeedMode.hot),
    (label: '最新', icon: Icons.new_releases_rounded, mode: _HomeFeedMode.latest),
    (label: '关注', icon: Icons.star_rounded, mode: _HomeFeedMode.following),
  ];

  String get _sectionTitle {
    if (_activeTopic != null) return '#${_activeTopic!.name}';
    switch (_mode) {
      case _HomeFeedMode.hot:
        return '热门动态';
      case _HomeFeedMode.latest:
        return '最新动态';
      case _HomeFeedMode.following:
        return '关注动态';
      case _HomeFeedMode.topic:
        return '分区动态';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_scrollListener);
    _availableTags = TopicTag.officialTags.take(12).toList();
    _fetchPosts();
  }

  @override
  void dispose() {
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
    if (_mode == newMode && _activeTopic == null) return;
    setState(() {
      _mode = newMode;
      _activeTopic = null; // Clear topic filter on tab change
    });
    _fetchPosts(resetContent: true);
    // Rebuild topic tags after resetting
    _refreshAvailableTags();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore) return;
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
      if (mounted && !_isLoading && !_isLoadingMore && _hasMore) {
        _loadMorePosts();
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
      _insertCreatedPost(result);
    }
    // 统一再拉取一次，确保热门/关注等服务端排序与本地一致。
    await _fetchPosts(resetContent: false);
  }

  void _insertCreatedPost(Post post) {
    if (_activeTopic != null) {
      final matchesTopic = post.topicTags.any((t) => t.id == _activeTopic!.id);
      if (!matchesTopic) return;
    }
    if (_mode == _HomeFeedMode.following) return;
    final exists = _allPosts.any((p) => p.id == post.id);
    if (exists) return;
    setState(() {
      _allPosts = [post, ..._allPosts];
      _displayPosts = List<Post>.from(_allPosts);
      _lastUpdatedAt = DateTime.now();
    });
    _refreshAvailableTags();
  }

  Future<void> _fetchPosts({bool resetContent = true}) async {
    if (_isPrimaryRequestInFlight) {
      _shouldReloadAfterCurrent = true;
      _queuedResetContent = _queuedResetContent || resetContent;
      return;
    }
    _isPrimaryRequestInFlight = true;
    final hasExistingPosts = _displayPosts.isNotEmpty;
    if (mounted) {
      setState(() {
        _feedErrorMessage = null;
        _loadMoreErrorMessage = null;
        _hasMore = true;
        _currentPage = 1;
        if (resetContent || !hasExistingPosts) {
          _isLoading = true;
          _isRefreshing = false;
          _allPosts = [];
          _displayPosts = [];
        } else {
          _isRefreshing = true;
          _isLoading = false;
        }
      });
    }
    try {
      final result = await _fetchPostsForMode(page: 1);
      if (!mounted) return;
      setState(() {
        _allPosts = result.posts;
        _displayPosts = List<Post>.from(result.posts);
        _currentPage = 1;
        _hasMore = _mode.supportsPagination
            ? result.posts.length < result.total
            : false;
        _feedErrorMessage = null;
        _lastUpdatedAt = DateTime.now();
      });
      _refreshAvailableTags();
    } catch (e) {
      final message = _friendlyErrorMessage(e);
      if (mounted) {
        setState(() {
          _feedErrorMessage = message;
          _hasMore = false;
        });
      }
      _handleError(e);
    } finally {
      final shouldReload = _shouldReloadAfterCurrent;
      final queuedReset = _queuedResetContent;
      _isPrimaryRequestInFlight = false;
      _shouldReloadAfterCurrent = false;
      _queuedResetContent = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
      if (shouldReload) {
        unawaited(_fetchPosts(resetContent: queuedReset));
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        _isLoadMoreRequestInFlight ||
        !_hasMore) {
      return;
    }
    _isLoadMoreRequestInFlight = true;
    setState(() {
      _isLoadingMore = true;
      _loadMoreErrorMessage = null;
    });
    try {
      final nextPage = _currentPage + 1;
      final result = await _fetchPostsForMode(page: nextPage);
      if (!mounted) return;
      if (result.posts.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }
      setState(() {
        _allPosts.addAll(result.posts);
        _displayPosts = List<Post>.from(_allPosts);
        _currentPage = nextPage;
        _hasMore = _mode.supportsPagination
            ? _allPosts.length < result.total
            : false;
        _loadMoreErrorMessage = null;
        _lastUpdatedAt = DateTime.now();
      });
      _refreshAvailableTags();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadMoreErrorMessage = _friendlyErrorMessage(e);
        });
      }
      _handleError(e);
    } finally {
      _isLoadMoreRequestInFlight = false;
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _refreshAvailableTags() {
    final byId = <String, TopicTag>{};
    for (final tag in TopicTag.officialTags) {
      byId[tag.id] = tag;
    }
    for (final p in _allPosts) {
      for (final tag in p.topicTags) {
        byId[tag.id] = tag;
      }
    }
    final tags = byId.values.toList();
    tags.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    final nextTags = tags.take(15).toList();
    if (_isSameTagSequence(_availableTags, nextTags)) return;
    if (mounted) setState(() => _availableTags = nextTags);
  }

  bool _isSameTagSequence(List<TopicTag> a, List<TopicTag> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _handleError(dynamic error) {
    if (mounted) {
      if (error is Exception) {
        ErrorHandler.handleException(context, error);
      } else {
        ErrorHandler.showError(context, '发生未知错误');
      }
    }
  }

  void _toggleLike(String postId) {
    final isLiked = _likeManager.getStatusNotifier(postId).value;
    final likeCount = _likeManager.getCountNotifier(postId).value;
    _updateLikeSnapshot(postId: postId, isLiked: isLiked, likeCount: likeCount);
  }

  // 仅同步内存快照，不触发整页 rebuild（LikeButton 已由 ValueListenable 局部刷新）
  void _updateLikeSnapshot({
    required String postId,
    required bool isLiked,
    required int likeCount,
  }) {
    final allIndex = _allPosts.indexWhere((p) => p.id == postId);
    if (allIndex != -1) {
      _allPosts[allIndex] = _allPosts[allIndex].copyWith(
        isLiked: isLiked,
        likes: likeCount,
      );
    }
    final displayIndex = _displayPosts.indexWhere((p) => p.id == postId);
    if (displayIndex != -1) {
      _displayPosts[displayIndex] = _displayPosts[displayIndex].copyWith(
        isLiked: isLiked,
        likes: likeCount,
      );
    }
  }

  String _apiFeedMode() {
    switch (_mode) {
      case _HomeFeedMode.hot:
        return 'hot';
      case _HomeFeedMode.latest:
        return 'latest';
      case _HomeFeedMode.following:
        return 'following';
      case _HomeFeedMode.topic:
        return 'latest';
    }
  }

  String? _apiTopicTagId() {
    if (_activeTopic != null) return _activeTopic!.id;
    return null;
  }

  Future<_PostPageResult> _fetchPostsForMode({required int page}) async {
    final result = await PostService.getPosts(
      page: page,
      pageSize: _pageSize,
      feedMode: _apiFeedMode(),
      topicTagId: _apiTopicTagId(),
    );
    final posts = result['posts'] as List<Post>;
    final totalRaw = result['total'];
    final total =
        totalRaw is int ? totalRaw : (totalRaw is num ? totalRaw.toInt() : 0);
    return _PostPageResult(posts: posts, total: total);
  }

  void _onTopicSelected(TopicTag? tag) {
    if (tag?.id == _activeTopic?.id) {
      // Deselect
      setState(() {
        _activeTopic = null;
        _mode = _tabs[_tabController.index].mode;
      });
    } else {
      setState(() {
        _activeTopic = tag;
        if (tag != null) _mode = _HomeFeedMode.topic;
      });
    }
    _fetchPosts(resetContent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _fetchPosts(resetContent: false),
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // SliverAppBar with TabBar in bottom — Flutter-idiomatic, no SliverPersistentHeader needed
            _buildSliverAppBar(context),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: HomeStoriesBar(onCreatePostSuccess: _handleCreatePostResult),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: QuickActionsGrid(onCreatePostSuccess: _handleCreatePostResult),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // Topic tags row — plain SliverToBoxAdapter, no dynamic-extent issues
            if (_showTopicBar)
              SliverToBoxAdapter(child: _buildTopicTagsRow(context)),
            SliverToBoxAdapter(child: _buildFeedSectionTitle(context)),
            if (_feedErrorMessage != null && _displayPosts.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildInlineErrorBanner(
                  message: _feedErrorMessage!,
                  onRetry: () => _fetchPosts(resetContent: false),
                ),
              ),
            if (_isLoading && _displayPosts.isEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const PostSkeleton(),
                  childCount: 6,
                ),
              )
            else if (_feedErrorMessage != null && _displayPosts.isEmpty)
              SliverToBoxAdapter(
                child: _buildFeedErrorState(_feedErrorMessage!),
              )
            else if (!_isLoading && _displayPosts.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = _displayPosts[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 60),
                      child: _buildPostCard(post),
                    );
                  },
                  childCount: _displayPosts.length,
                ),
              ),
            SliverToBoxAdapter(child: _buildBottomIndicator()),
            const SliverToBoxAdapter(child: SizedBox(height: 72)),
          ],
        ),
      ),
    );
  }

  bool get _showTopicBar =>
      _mode != _HomeFeedMode.following && _availableTags.isNotEmpty;

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final baseExpandedHeight =
        screenHeight < 620 ? 286.0 : screenHeight < 760 ? 298.0 : 312.0;
    final narrowWidthExtra = screenWidth < 340
        ? 26.0
        : screenWidth < 360
            ? 18.0
            : 0.0;
    final expandedHeight = baseExpandedHeight +
        ((textScale - 1.0) * 20).clamp(0.0, 24.0) +
        narrowWidthExtra;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      foregroundColor: scheme.onSurface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: scheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Moe Social',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            MoeToast.info(context, '搜索功能即将上线');
          },
          tooltip: '搜索',
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          onPressed: () => Navigator.pushNamed(context, '/scan'),
          tooltip: '扫码添加好友',
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.unreadCount == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 8, minHeight: 8),
                    child: provider.unreadCount > 99
                        ? const Text(
                            '99+',
                            style:
                                TextStyle(color: Colors.white, fontSize: 8),
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
      // TabBar placed here — pinned with the AppBar, avoids SliverPersistentHeader semantics bug
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: scheme.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        tabs: _tabs
            .map(
              (t) => Tab(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 15),
                    const SizedBox(width: 5),
                    Text(t.label),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Padding(
          // top: appbar toolbar (~56) + status bar (~24) ≈ 80, use 86 for safety
          // bottom: TabBar pinned at bottom of flexible space (~40px) + gap
          padding: const EdgeInsets.fromLTRB(16, 86, 16, 44),
          child: const PersonalizedCard(),
        ),
      ),
    );
  }

  Widget _buildTopicTagsRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
              color: scheme.outline.withValues(alpha: 0.1), width: 0.5),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _availableTags.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAll = _activeTopic == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildTopicFilterChip(
                label: '全部',
                selected: isAll,
                selectedColor: scheme.primary,
                backgroundColor: isAll
                    ? scheme.primary.withValues(alpha: 0.15)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderColor: isAll
                    ? scheme.primary.withValues(alpha: 0.4)
                    : scheme.outline.withValues(alpha: 0.2),
                textColor: isAll ? scheme.primary : scheme.onSurfaceVariant,
                onTap: () => _onTopicSelected(null),
              ),
            );
          }
          final tag = _availableTags[index - 1];
          final isSelected = _activeTopic?.id == tag.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildTopicFilterChip(
              label: '#${tag.name}',
              selected: isSelected,
              selectedColor: tag.color,
              backgroundColor: isSelected
                  ? tag.color.withValues(alpha: 0.18)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderColor: isSelected
                  ? tag.color.withValues(alpha: 0.45)
                  : scheme.outline.withValues(alpha: 0.2),
              textColor: isSelected ? tag.color : scheme.onSurfaceVariant,
              onTap: () => _onTopicSelected(tag),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopicFilterChip({
    required String label,
    required bool selected,
    required Color selectedColor,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: selectedColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedSectionTitle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _sectionTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isLoading || _isRefreshing
                    ? null
                    : () => _fetchPosts(resetContent: false),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_isRefreshing ? '刷新中' : '刷新'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMetaChip(
                icon: _isRefreshing
                    ? Icons.sync_rounded
                    : Icons.schedule_rounded,
                text: _lastUpdatedText(),
              ),
              if (_activeTopic != null)
                _buildMetaChip(
                  icon: Icons.filter_alt_rounded,
                  text: '#${_activeTopic!.name}',
                  accentColor: _activeTopic!.color,
                  onTap: () => _onTopicSelected(null),
                  trailing: const Icon(Icons.close_rounded, size: 14),
                ),
            ],
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final color = accentColor ?? scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (accentColor ?? scheme.surfaceContainerHighest)
              .withValues(alpha: accentColor == null ? 0.55 : 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.28),
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

  String _friendlyErrorMessage(dynamic error) {
    final text = error.toString().trim();
    if (text.isEmpty) return '网络开小差了，请稍后重试';
    if (text.length > 80) return '数据加载失败，请稍后重试';
    return text;
  }

  String _lastUpdatedText() {
    if (_isRefreshing) return '正在刷新内容...';
    final updatedAt = _lastUpdatedAt;
    if (updatedAt == null) return '尚未加载最新动态';
    final hour = updatedAt.hour.toString().padLeft(2, '0');
    final minute = updatedAt.minute.toString().padLeft(2, '0');
    return '最后更新 $hour:$minute';
  }

  Widget _buildInlineErrorBanner({
    required String message,
    required VoidCallback onRetry,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB347).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFFB347).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: Color(0xFFFFB347),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isLoading || _isRefreshing ? null : onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedErrorState(String message) {
    return _buildUnifiedStatePanel(
      icon: Icons.cloud_off_rounded,
      title: '动态加载失败',
      subtitle: message,
      accentColor: const Color(0xFFFFB347),
      action: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _fetchPosts(resetContent: true),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('重新加载'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7F7FD5),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildUnifiedStatePanel(
      icon: Icons.auto_awesome_rounded,
      title: '还没有动态呢 ~',
      subtitle: '发布第一条动态，开启萌系社交之旅吧！',
      accentColor: const Color(0xFF7F7FD5),
      action: ElevatedButton.icon(
        onPressed: _openCreatePost,
        icon: const Icon(Icons.add_rounded),
        label: const Text('发布动态'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7F7FD5),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedStatePanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Widget action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F7FD5).withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            action,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIndicator() {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: const MoeSmallLoading(),
            label: '正在加载更多...',
          ),
        ),
      );
    } else if (_loadMoreErrorMessage != null &&
        _displayPosts.isNotEmpty &&
        !_isLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFFFB347),
              size: 18,
            ),
            label: '加载更多失败',
            accentColor: const Color(0xFFFFB347),
            trailing: TextButton(
              onPressed: _isLoadingMore ? null : _loadMorePosts,
              child: const Text('重试'),
            ),
          ),
        ),
      );
    } else if (!_hasMore && _displayPosts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.grey[500],
              size: 18,
            ),
            label: '已经到底啦 ~',
          ),
        ),
      );
    } else if (_hasMore && !_isLoading && !_isRefreshing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: (_isLoadingMore || _isRefreshing)
                ? null
                : () {
                    if (!_isLoading &&
                        !_isRefreshing &&
                        !_isLoadingMore &&
                        _hasMore) {
                      _loadMorePosts();
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: (_isLoadingMore || _isRefreshing)
                    ? Colors.grey.withValues(alpha: 0.1)
                    : const Color(0xFF7F7FD5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (_isLoadingMore || _isRefreshing)
                      ? Colors.grey.withValues(alpha: 0.2)
                      : const Color(0xFF7F7FD5).withValues(alpha: 0.26),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward_rounded,
                      color: Color(0xFF7F7FD5), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '点击加载更多',
                    style: TextStyle(
                      color: Color(0xFF7F7FD5),
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
    Color accentColor = const Color(0xFF7F7FD5),
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface,
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
    return PostCard(
      key: ValueKey('home_post_${post.id}'),
      post: post,
      onLike: () => _toggleLike(post.id),
      onComment: () async {
        final result = await openPostDetail(context, post);
        if (!mounted || result == null) return;
        setState(() {
          final allIndex = _allPosts.indexWhere((p) => p.id == post.id);
          if (allIndex != -1) {
            final updated = _allPosts[allIndex].copyWith(comments: result);
            _allPosts[allIndex] = updated;
            final displayIndex =
                _displayPosts.indexWhere((p) => p.id == post.id);
            if (displayIndex != -1) _displayPosts[displayIndex] = updated;
          }
        });
      },
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
                setState(() {
                  final merged = updated.copyWith(
                    likes: post.likes,
                    comments: post.comments,
                    isLiked: post.isLiked,
                    userName: updated.userName.isNotEmpty ? updated.userName : post.userName,
                    userAvatar: updated.userAvatar.isNotEmpty ? updated.userAvatar : post.userAvatar,
                  );
                  final ai = _allPosts.indexWhere((p) => p.id == updated.id);
                  if (ai != -1) _allPosts[ai] = merged;
                  final di = _displayPosts.indexWhere((p) => p.id == updated.id);
                  if (di != -1) _displayPosts[di] = merged;
                });
              }
            }
          : null,
      onDelete: post.userId == (AuthService.currentUser ?? '')
          ? () async {
              try {
                await ApiService.deletePost(post.id);
                if (!mounted) return;
                setState(() {
                  _allPosts.removeWhere((p) => p.id == post.id);
                  _displayPosts.removeWhere((p) => p.id == post.id);
                });
                _likeManager.evictPost(post.id);
              } catch (e) {
                if (mounted) ErrorHandler.showError(context, '删除失败：$e');
              }
            }
          : null,
    );
  }

}

// ---------------------------------------------------------------------------
// Enums & helpers
// ---------------------------------------------------------------------------

enum _HomeFeedMode { hot, latest, following, topic }

extension on _HomeFeedMode {
  bool get supportsPagination => true;
}

class _PostPageResult {
  final List<Post> posts;
  final int total;
  const _PostPageResult({required this.posts, required this.total});
}



