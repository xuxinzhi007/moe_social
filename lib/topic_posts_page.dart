import 'package:flutter/material.dart';
import 'models/post.dart';
import 'models/topic_tag.dart';
import 'services/post_service.dart';
import 'widgets/post_card.dart';
import 'auth_service.dart';
import 'widgets/fade_in_up.dart';
import 'widgets/topic_tag_selector.dart';
import 'utils/error_handler.dart';

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
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalPosts = 0;
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
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      // 获取所有帖子，然后在前端过滤（暂时方案）
      // TODO: 后端支持按话题ID筛选
      final result = await PostService.getPosts(page: 1, pageSize: 1000);
      final allPosts = result['posts'] as List<Post>;
      
      // 过滤出包含当前话题的帖子
      final filteredPosts = allPosts.where((post) {
        return post.topicTags.any((tag) => tag.id == widget.topicTag.id);
      }).toList();

      setState(() {
        _posts = filteredPosts;
        _totalPosts = filteredPosts.length;
        _currentPage = 1;
        _hasMore = false; // 暂时不支持分页
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
    // 暂时不支持分页
    setState(() {
      _isLoadingTriggered = false;
    });
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
      if (postIndex != -1) {
        _posts[postIndex] = updatedPost;
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
          ? const Center(child: CircularProgressIndicator())
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
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return FadeInUp(
                        delay: Duration(milliseconds: 30 * (index % 5)),
                        child: PostCard(
                          post: post,
                          onLike: () => _toggleLike(post.id),
                          onComment: () async {
                            await Navigator.pushNamed(context, '/comments', arguments: post.id);
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
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
