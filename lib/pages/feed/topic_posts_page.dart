import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../models/topic_tag.dart';
import '../../services/post_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/moe_loading.dart';
import '../../auth_service.dart';
import '../../utils/error_handler.dart';

/// 话题动态列表页面 - 显示指定话题下的所有动态
class TopicPostsPage extends StatefulWidget {
  final TopicTag topicTag;

  const TopicPostsPage({
    super.key,
    required this.topicTag,
  });

  @override
  State<TopicPostsPage> createState() => _TopicPostsPageState();
}

class _TopicPostsPageState extends State<TopicPostsPage> {
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalPosts = 0;
  int _currentPage = 1;
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  bool _isLoadingTriggered = false;

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

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore || _isLoadingTriggered) {
      return;
    }

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    final threshold = maxScroll > 0 ? maxScroll - 300 : 0;
    final isNearBottom = currentScroll >= threshold ||
        (maxScroll > 0 && currentScroll >= maxScroll - 50);

    if (isNearBottom) {
      _isLoadingTriggered = true;
      _loadMorePosts();
    }
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _currentPage = 1;
      _posts = [];
    });

    try {
      final result = await PostService.getPosts(
        page: 1,
        pageSize: _pageSize,
        feedMode: 'latest',
        topicTagId: widget.topicTag.id,
      );
      final posts = result['posts'] as List<Post>;
      final totalRaw = result['total'];
      final total = totalRaw is int
          ? totalRaw
          : (totalRaw is num ? totalRaw.toInt() : 0);

      setState(() {
        _posts = posts;
        _totalPosts = total;
        _hasMore = posts.length < total;
      });
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
    if (_isLoading || _isLoadingMore || !_hasMore) {
      setState(() {
        _isLoadingTriggered = false;
      });
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await PostService.getPosts(
        page: nextPage,
        pageSize: _pageSize,
        feedMode: 'latest',
        topicTagId: widget.topicTag.id,
      );
      final morePosts = result['posts'] as List<Post>;
      final totalRaw = result['total'];
      final total = totalRaw is int
          ? totalRaw
          : (totalRaw is num ? totalRaw.toInt() : 0);

      if (morePosts.isEmpty) {
        setState(() {
          _hasMore = false;
        });
        return;
      }

      setState(() {
        _posts.addAll(morePosts);
        _totalPosts = total;
        _currentPage = nextPage;
        _hasMore = _posts.length < total;
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
        _isLoadingTriggered = false;
      });
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
      final updatedPost = await PostService.toggleLike(postId, userId);

      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1 && mounted) {
        setState(() {
          _posts[postIndex] = updatedPost;
        });
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.topicTag.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '${_totalPosts} 条动态',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && _posts.isEmpty
          ? const Center(child: MoeLoading())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tag_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '还没有相关动态呢 ~',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPosts,
                  color: Theme.of(context).primaryColor,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _posts.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                MoeSmallLoading(),
                                SizedBox(height: 8),
                                Text(
                                  '加载中...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final post = _posts[index];
                      return PostCard(
                        key: ValueKey('topic_post_${post.id}'),
                        post: post,
                        onLike: () => _toggleLike(post.id),
                        onComment: () async {
                          await Navigator.pushNamed(
                              context, '/comments', arguments: post.id);
                        },
                        onShare: () {},
                        onAvatarTap: () {
                          Navigator.pushNamed(
                            context,
                            '/user-profile',
                            arguments: {
                              'userId': post.userId,
                              'userName': post.userName,
                              'userAvatar': post.userAvatar,
                              'heroTag': 'avatar_${post.id}',
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
