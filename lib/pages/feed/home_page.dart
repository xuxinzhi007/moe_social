import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../auth_service.dart';
import '../../models/topic_tag.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/post_service.dart';
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
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 10;

  _HomeFeedMode _mode = _HomeFeedMode.hot;
  TopicTag? _activeTopic;

  late TabController _tabController;

  // Available topic tags collected from loaded posts + official tags
  List<TopicTag> _availableTags = [];

  final ScrollController _scrollController = ScrollController();
  Timer? _loadMoreTimer;

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
    _fetchPosts();
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

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
      _allPosts = [];
      _displayPosts = [];
    });
    try {
      final result = await _fetchPostsForMode(page: 1);
      setState(() {
        _allPosts = result.posts;
        _displayPosts = List<Post>.from(result.posts);
        _currentPage = 1;
        _hasMore = _mode.supportsPagination
            ? result.posts.length < result.total
            : false;
      });
      _refreshAvailableTags();
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final result = await _fetchPostsForMode(page: nextPage);
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
      });
      _refreshAvailableTags();
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
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
    if (mounted) setState(() => _availableTags = tags.take(15).toList());
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

  Future<void> _toggleLike(String postId) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) ErrorHandler.showError(context, '请先登录');
      return;
    }
    try {
      final updatedPost = await PostService.toggleLike(postId, userId);
      final postIndex = _allPosts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) _allPosts[postIndex] = updatedPost;
    } catch (e) {
      _handleError(e);
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
    _fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchPosts,
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // SliverAppBar with TabBar in bottom — Flutter-idiomatic, no SliverPersistentHeader needed
            _buildSliverAppBar(context),
            const SliverToBoxAdapter(child: HomeStoriesBar()),
            const SliverToBoxAdapter(child: QuickActionsGrid()),
            // Topic tags row — plain SliverToBoxAdapter, no dynamic-extent issues
            if (_showTopicBar)
              SliverToBoxAdapter(child: _buildTopicTagsRow(context)),
            SliverToBoxAdapter(child: _buildFeedSectionTitle(context)),
            if (_isLoading && _displayPosts.isEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const PostSkeleton(),
                  childCount: 6,
                ),
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
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  bool get _showTopicBar =>
      _mode != _HomeFeedMode.following && _availableTags.isNotEmpty;

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight =
        screenHeight < 600 ? 255.0 : screenHeight < 700 ? 268.0 : 282.0;

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
              color: scheme.primary.withOpacity(0.12),
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
          // bottom: TabBar pinned at bottom of flexible space (~40px) + 8px gap
          padding: const EdgeInsets.fromLTRB(16, 86, 16, 48),
          child: const PersonalizedCard(),
        ),
      ),
    );
  }

  Widget _buildTopicTagsRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
              color: scheme.outline.withOpacity(0.1), width: 0.5),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _availableTags.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAll = _activeTopic == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onTopicSelected(null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAll
                        ? scheme.primary.withOpacity(0.15)
                        : scheme.surfaceContainerHighest
                            .withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isAll
                          ? scheme.primary.withOpacity(0.4)
                          : scheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    '全部',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isAll
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }
          final tag = _availableTags[index - 1];
          final isSelected = _activeTopic?.id == tag.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onTopicSelected(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? tag.color.withOpacity(0.18)
                      : scheme.surfaceContainerHighest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? tag.color.withOpacity(0.45)
                        : scheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '#${tag.name}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? tag.color
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedSectionTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _sectionTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_activeTopic != null)
            GestureDetector(
              onTap: () => _onTopicSelected(null),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _activeTopic!.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _activeTopic!.color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded,
                        size: 13, color: _activeTopic!.color),
                    const SizedBox(width: 3),
                    Text(
                      '清除筛选',
                      style: TextStyle(
                        fontSize: 11,
                        color: _activeTopic!.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7F7FD5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 64,
              color: Color(0xFF7F7FD5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有动态呢 ~',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '发布第一条动态，开启萌系社交之旅吧！',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/create-post'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('发布动态'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F7FD5),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIndicator() {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const MoeSmallLoading(),
              const SizedBox(height: 12),
              Text(
                '加载中...',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    } else if (!_hasMore && _displayPosts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline,
                    color: Colors.grey[400], size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                '已经到底啦 ~',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    } else if (_hasMore && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () {
            if (!_isLoading && !_isLoadingMore && _hasMore) _loadMorePosts();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF7F7FD5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
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
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPostCard(Post post) {
    return PostCard(
      key: ValueKey('home_post_${post.id}'),
      post: post,
      onLike: () => _toggleLike(post.id),
      onComment: () async {
        final result = await openPostDetail<int>(context, post);
        if (result != null) {
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
        }
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
              } catch (e) {
                if (mounted) ErrorHandler.showError(context, '删除失败：$e');
              }
            }
          : null,
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.pushNamed(context, '/create-post');
        if (result == true && mounted) _fetchPosts();
      },
      backgroundColor: const Color(0xFF7F7FD5),
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.edit_rounded, size: 20),
      label: const Text(
        '写动态',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
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



