import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../services/api_service.dart';
import '../models/topic_tag.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/post_service.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/fade_in_up.dart';
import '../utils/error_handler.dart';
import '../providers/notification_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/home_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Post> _allPosts = [];
  List<Post> _displayPosts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalPosts = 0;
  static const int _pageSize = 10;

  _HomeFeedMode _mode = _HomeFeedMode.hot;
  TopicTag? _activeTopic;
  Set<String>? _followingUserIds;
  bool _loadingFollowing = false;

  // 添加滚动控制器和加载触发标志
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingTriggered = false;

  String get _sectionTitle {
    switch (_mode) {
      case _HomeFeedMode.hot:
        return '热门动态';
      case _HomeFeedMode.latest:
        return '最新动态';
      case _HomeFeedMode.following:
        return '关注动态';
      case _HomeFeedMode.topic:
        return _activeTopic != null ? '#${_activeTopic!.name}' : '分区动态';
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchPosts();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动监听器
  void _scrollListener() {
    // 检查是否有滚动位置信息
    if (!_scrollController.hasClients) return;

    // 如果正在加载或没有更多数据，直接返回
    if (_isLoading || _isLoadingMore || !_hasMore || _isLoadingTriggered) {
      return;
    }

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // 当滚动到距底部300像素时触发加载，或者已经滚动到底部
    final threshold = maxScroll > 0 ? maxScroll - 300 : 0;
    final isNearBottom = currentScroll >= threshold ||
        (maxScroll > 0 && currentScroll >= maxScroll - 50);

    if (isNearBottom) {
      debugPrint('🔄 触发加载更多');
      debugPrint('   当前滚动位置: $currentScroll');
      debugPrint('   最大滚动位置: $maxScroll');
      debugPrint('   阈值: $threshold');
      debugPrint('   _hasMore: $_hasMore');
      debugPrint('   _isLoading: $_isLoading');
      debugPrint('   _isLoadingMore: $_isLoadingMore');
      debugPrint('   _isLoadingTriggered: $_isLoadingTriggered');
      debugPrint('   当前页码: $_currentPage');
      debugPrint('   已加载帖子数: ${_allPosts.length}');

      // 立即设置标志，防止重复触发
      _isLoadingTriggered = true;

      // 异步调用，但不等待完成就返回，避免阻塞滚动
      _loadMorePosts();
    }
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
      final posts = result.posts;
      final total = result.total;

      // Use server as source of truth for like status.

      debugPrint('📥 从后端获取的数据：');
      debugPrint('   总帖子数：$total');
      debugPrint('   第一页帖子数：${posts.length}');
      debugPrint('   帖子ID列表：${posts.map((post) => post.id).toList()}');

      setState(() {
        _allPosts = posts;
        _displayPosts = _computeDisplayPosts(posts);
        _totalPosts = total;
        _currentPage = 1; // 确保页码正确
        // 修复_hasMore判断逻辑：如果已加载数据小于总数，则还有更多
        _hasMore = _mode.supportsPagination ? posts.length < total : false;
      });

      debugPrint('📝 设置后的状态：');
      debugPrint('   _posts长度：${_allPosts.length}');
      debugPrint('   _totalPosts：$_totalPosts');
      debugPrint('   _currentPage：$_currentPage');
      debugPrint('   _hasMore：$_hasMore');
      debugPrint('   判断逻辑：${_allPosts.length} < ${_totalPosts} = ${_hasMore}');
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    // 如果正在刷新、正在加载更多或没有更多数据，则不执行
    if (_isLoading || _isLoadingMore || !_hasMore) {
      debugPrint(
          '⚠️ 阻止重复加载：_isLoading=$_isLoading, _isLoadingMore=$_isLoadingMore, _hasMore=$_hasMore');
      return;
    }

    // 立即设置加载状态，防止并发调用
    setState(() {
      _isLoadingMore = true;
    });

    debugPrint('📥 开始加载更多帖子');
    debugPrint('   当前页码：$_currentPage');
    debugPrint('   已加载帖子数：${_allPosts.length}');
    debugPrint('   总帖子数：$_totalPosts');
    debugPrint('   下一页码：${_currentPage + 1}');
    debugPrint('   _hasMore：$_hasMore');

    try {
      final nextPage = _currentPage + 1;
      debugPrint('📡 请求第 $nextPage 页数据...');

      final result = await _fetchPostsForMode(page: nextPage);
      final morePosts = result.posts;
      final total = result.total;

      // Use server as source of truth for like status.

      debugPrint('📥 加载更多帖子成功：');
      debugPrint('   请求页码：$nextPage');
      debugPrint('   返回的帖子数：${morePosts.length}');
      debugPrint('   帖子ID列表：${morePosts.map((post) => post.id).toList()}');
      debugPrint('   总帖子数：$total');

      // 如果返回的数据为空，说明没有更多数据了
      if (morePosts.isEmpty) {
        debugPrint('⚠️ 返回的数据为空，说明没有更多数据了');
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _allPosts.addAll(morePosts);
        _displayPosts = _computeDisplayPosts(_allPosts);
        _currentPage = nextPage;
        _totalPosts = total;
        // 修复_hasMore判断逻辑：如果已加载数据小于总数，则还有更多
        _hasMore = _mode.supportsPagination ? _allPosts.length < total : false;
      });

      debugPrint('📝 设置后的状态：');
      debugPrint('   _posts长度：${_allPosts.length}');
      debugPrint('   _currentPage：$_currentPage');
      debugPrint('   _totalPosts：$_totalPosts');
      debugPrint('   _hasMore：$_hasMore');
      debugPrint('   判断逻辑：${_allPosts.length} < ${_totalPosts} = ${_hasMore}');
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
        // 请求失败时，停止尝试加载更多，避免无限请求
        setState(() {
          _hasMore = false;
        });
      }
      debugPrint('❌ 加载更多帖子失败：$e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
      // 重置触发标志，允许下次触发
      _isLoadingTriggered = false;
    }
  }

  Future<void> _toggleLike(String postId) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) {
        ErrorHandler.showError(context, '请先登录');
      }
      return;
    }

    try {
      // PostService 内部通过 LikeStateManager 处理乐观更新和状态同步
      // UI 会通过 PostCard 中的 ValueListenableBuilder 自动刷新
      final updatedPost = await PostService.toggleLike(postId, userId);
      
      // 默默更新本地数据源，保持数据一致性，但不触发重排或重绘
      final postIndex = _allPosts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        _allPosts[postIndex] = updatedPost;
        // 如果需要，也可以更新 _displayPosts 中对应的项，防止后续操作引用旧对象
        // 但不需要 setState，避免列表重排导致跳动
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    }
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
            _buildSliverAppBar(context),
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeHeaderDelegate(
                minExtent: _showComposerBar ? 140 : 64,
                maxExtent: _showComposerBar ? 140 : 64,
                child: _buildPinnedHeader(context),
              ),
            ),
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
                    final visible = _displayPosts;
                    final item = _feedItemAt(index, visible);
                    if (item is _HomeFeedCard) {
                      return item.build(context);
                    }
                    final post = item as Post;
                    final postIndex =
                        visible.indexWhere((p) => p.id == post.id);
                    return FadeInUp(
                      delay: Duration(milliseconds: postIndex < 5 ? 30 * postIndex : 0),
                      child: _buildPostCard(post, postIndex),
                    );
                  },
                  childCount: _feedItemCount(_displayPosts),
                ),
              ),
            SliverToBoxAdapter(child: _buildBottomIndicator()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
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
          if (_mode == _HomeFeedMode.topic && _activeTopic != null)
            TextButton(
              onPressed: () => _pickTopic(context),
              child: const Text('换一个'),
            ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 260,
      elevation: 0,
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Moe Social',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, child) {
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
                        ? const Text('99+',
                            style: TextStyle(color: Colors.white, fontSize: 8))
                        : null,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: const FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: HomeBanner(),
      ),
    );
  }

  Widget _buildPinnedHeader(BuildContext context) {
    final bg = Colors.white;
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          _buildModeChips(context),
          const SizedBox(height: 8),
          if (_showComposerBar) _buildComposerBar(context),
        ],
      ),
    );
  }

  Widget _buildModeChips(BuildContext context) {
    final mode = _mode;
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            icon: Icons.category_rounded,
            label: _activeTopic != null ? _activeTopic!.name : '分区',
            selected: mode == _HomeFeedMode.topic,
            color: Colors.pinkAccent,
            onTap: () => _pickTopic(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeChip(
            icon: Icons.whatshot_rounded,
            label: '热门',
            selected: mode == _HomeFeedMode.hot,
            color: Colors.orange,
            onTap: () => _setMode(_HomeFeedMode.hot),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeChip(
            icon: Icons.new_releases_rounded,
            label: '最新',
            selected: mode == _HomeFeedMode.latest,
            color: Colors.blueAccent,
            onTap: () => _setMode(_HomeFeedMode.latest),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeChip(
            icon: Icons.star_rounded,
            label: '关注',
            selected: mode == _HomeFeedMode.following,
            color: Colors.purpleAccent,
            onTap: () => _setMode(_HomeFeedMode.following),
          ),
        ),
      ],
    );
  }

  Widget _buildComposerBar(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/create-post');
        if (result == true) {
          _fetchPosts();
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 52,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7F7FD5).withOpacity(0.6),
                      const Color(0xFF86A8E7).withOpacity(0.6),
                    ],
                  ),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '正在想什么？发一条萌萌动态…',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F7FD5).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Color(0xFF7F7FD5)),
                    SizedBox(width: 2),
                    Text(
                      '发布',
                      style: TextStyle(
                        color: Color(0xFF7F7FD5),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setMode(_HomeFeedMode next) async {
    if (_mode == next &&
        (next != _HomeFeedMode.topic || _activeTopic != null)) {
      return;
    }
    setState(() {
      _mode = next;
      if (next != _HomeFeedMode.topic) {
        _activeTopic = null;
      }
    });

    if (next == _HomeFeedMode.following) {
      await _ensureFollowingIds();
    }

    await _fetchPosts();
  }

  Future<void> _pickTopic(BuildContext context) async {
    final picked = await showModalBottomSheet<TopicTag>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final tags = _collectCandidateTags();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('选择分区/话题',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: tags
                      .map((tag) => ActionChip(
                            label: Text('#${tag.name}'),
                            side:
                                BorderSide(color: tag.color.withOpacity(0.35)),
                            backgroundColor: tag.color.withOpacity(0.12),
                            labelStyle: TextStyle(
                              color: tag.color,
                              fontWeight: FontWeight.w700,
                            ),
                            onPressed: () => Navigator.pop(context, tag),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _mode = _HomeFeedMode.topic;
      _activeTopic = picked;
    });
    await _fetchPosts();
  }

  bool get _showComposerBar {
    final width = MediaQuery.of(context).size.width;
    return width >= 360;
  }

  List<TopicTag> _collectCandidateTags() {
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
    return tags.take(20).toList();
  }

  List<Post> _computeDisplayPosts(List<Post> input) {
    Iterable<Post> posts = input;

    if (_mode == _HomeFeedMode.topic && _activeTopic != null) {
      final tagId = _activeTopic!.id;
      posts = posts.where((p) => p.topicTags.any((t) => t.id == tagId));
    }

    if (_mode == _HomeFeedMode.following) {
      final ids = _followingUserIds;
      if (ids != null && ids.isNotEmpty) {
        posts = posts.where((p) => ids.contains(p.userId));
      } else {
        posts = const Iterable<Post>.empty();
      }
    }

    final list = posts.toList();
    if (_mode == _HomeFeedMode.latest ||
        _mode == _HomeFeedMode.topic ||
        _mode == _HomeFeedMode.following) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    // hot
    list.sort((a, b) {
      final aScore = a.likes * 2 + a.comments;
      final bScore = b.likes * 2 + b.comments;
      final byScore = bScore.compareTo(aScore);
      if (byScore != 0) return byScore;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<_PostPageResult> _fetchPostsForMode({required int page}) async {
    if (_mode == _HomeFeedMode.following) {
      await _ensureFollowingIds();
      if (_followingUserIds == null || _followingUserIds!.isEmpty) {
        return const _PostPageResult(posts: [], total: 0);
      }
    }

    // For filtered modes, fetch a bigger page size to reduce empty results.
    final pageSize =
        (_mode == _HomeFeedMode.following || _mode == _HomeFeedMode.topic)
            ? 50
            : _pageSize;
    final result = await PostService.getPosts(page: page, pageSize: pageSize);
    var posts = result['posts'] as List<Post>;
    var total = result['total'] as int;

    if (_mode == _HomeFeedMode.following) {
      final ids = _followingUserIds;
      if (ids != null && ids.isNotEmpty) {
        posts = posts.where((p) => ids.contains(p.userId)).toList();
        total = posts.length;
      }
    }

    if (_mode == _HomeFeedMode.topic && _activeTopic != null) {
      final tagId = _activeTopic!.id;
      posts =
          posts.where((p) => p.topicTags.any((t) => t.id == tagId)).toList();
      total = posts.length;
    }

    return _PostPageResult(posts: posts, total: total);
  }

  Future<void> _ensureFollowingIds() async {
    if (_followingUserIds != null) return;
    if (_loadingFollowing) return;
    final userId = AuthService.currentUser;
    if (userId == null || userId.isEmpty) {
      _followingUserIds = <String>{};
      return;
    }
    _loadingFollowing = true;
    try {
      final result =
          await ApiService.getFollowings(userId, page: 1, pageSize: 1000);
      final users = (result['followings'] as List<dynamic>).cast<User>();
      final ids = users.map((u) => u.id).toSet();
      ids.add(userId);
      _followingUserIds = ids;
    } catch (_) {
      _followingUserIds = <String>{};
    } finally {
      _loadingFollowing = false;
    }
  }

  int _feedItemCount(List<Post> posts) {
    // insert cards at fixed positions: 0, and after 6, 14, 24...
    final inserts = _cardInsertIndexes(posts.length);
    return posts.length + inserts.length;
  }

  Object _feedItemAt(int index, List<Post> posts) {
    final inserts = _cardInsertIndexes(posts.length);
    if (inserts.contains(index)) {
      return _HomeFeedCard.forIndex(index);
    }
    // map index to post index by subtracting number of insertions before it
    final before = inserts.where((i) => i < index).length;
    final postIndex = index - before;
    return posts[postIndex];
  }

  Set<int> _cardInsertIndexes(int postCount) {
    final s = <int>{};
    // Insert a lightweight tip card after a few posts.
    if (postCount >= 4) {
      s.add(4);
    }
    if (postCount >= 10) {
      // account for earlier insertion at index 4
      s.add(10 + (postCount >= 4 ? 1 : 0));
    }
    return s;
  }

  // 构建空状态
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
          const Text(
            '还没有动态呢 ~',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发布第一条动态，开启萌系社交之旅吧！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/create-post');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('发布动态'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F7FD5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 5,
              shadowColor: const Color(0xFF7F7FD5).withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  // 构建底部加载指示器
  Widget _buildBottomIndicator() {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F7FD5)),
              ),
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
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_hasMore) {
      // 有更多数据但不在加载中，显示可点击的加载提示
      return Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () {
            if (!_isLoading && !_isLoadingMore && _hasMore) {
              _loadMorePosts();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF7F7FD5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  color: const Color(0xFF7F7FD5),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '点击加载更多',
                  style: TextStyle(
                    color: const Color(0xFF7F7FD5),
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

  Widget _buildPostCard(Post post, int index) {
    return PostCard(
      post: post,
      onLike: () => _toggleLike(post.id),
      onComment: () async {
        await Navigator.pushNamed(context, '/comments', arguments: post.id);
        _fetchPosts();
      },
      onAvatarTap: () {
        final heroTag = 'avatar_${post.id}';
        Navigator.pushNamed(context, '/user-profile', arguments: {
          'userId': post.userId,
          'userName': post.userName,
          'userAvatar': post.userAvatar,
          'heroTag': heroTag,
        });
      },
    );
  }
}

enum _HomeFeedMode {
  hot,
  latest,
  following,
  topic,
}

extension on _HomeFeedMode {
  bool get supportsPagination {
    switch (this) {
      case _HomeFeedMode.hot:
      case _HomeFeedMode.latest:
        return true;
      case _HomeFeedMode.following:
      case _HomeFeedMode.topic:
        return false;
    }
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  final double minExtent;
  @override
  final double maxExtent;
  final Widget child;

  _HomeHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) {
    return minExtent != oldDelegate.minExtent ||
        maxExtent != oldDelegate.maxExtent ||
        child != oldDelegate.child;
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color.withOpacity(0.14) : Colors.grey[50]!;
    final border =
        selected ? color.withOpacity(0.35) : Colors.grey.withOpacity(0.15);
    final fg = selected ? color : Colors.grey[700]!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: fg, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostPageResult {
  final List<Post> posts;
  final int total;

  const _PostPageResult({
    required this.posts,
    required this.total,
  });
}

class _HomeFeedCard {
  final Widget Function(BuildContext context) _builder;

  _HomeFeedCard(this._builder);

  Widget build(BuildContext context) => _builder(context);

  static _HomeFeedCard forIndex(int index) {
    if (index == 0) {
      // Card removed (kept for future use)
      return _HomeFeedCard((context) => const SizedBox.shrink());
    }

    return _HomeFeedCard((context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF7F7FD5).withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Color(0xFF7F7FD5), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '小提示：热门会根据点赞/评论自动排序',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  // no-op
                },
                child: const Text('知道了'),
              )
            ],
          ),
        ),
      );
    });
  }
}
