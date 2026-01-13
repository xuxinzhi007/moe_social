import 'package:flutter/material.dart';
import 'models/post.dart';
import 'models/topic_tag.dart';
import 'services/post_service.dart';
import 'widgets/avatar_image.dart';
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }

  Widget _renderContentWithEmojis(String content) {
    final emojiRegex = RegExp(r'\[emoji:(.*?)\]');
    final matches = emojiRegex.allMatches(content);
    
    if (matches.isEmpty) {
      return Text(
        content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      );
    }
    
    final List<InlineSpan> spans = [];
    int lastIndex = 0;
    
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ));
      }
      
      final emojiUrl = match.group(1) ?? '';
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Image.network(
            emojiUrl,
            width: 24,
            height: 24,
            fit: BoxFit.cover,
          ),
        ),
      ));
      
      lastIndex = match.end;
    }
    
    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      ));
    }
    
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildPostCard(Post post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Row(
              children: [
                GestureDetector(
                  onTap: () {
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
                  child: Hero(
                    tag: 'avatar_${post.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7F7FD5).withOpacity(0.3),
                            const Color(0xFF86A8E7).withOpacity(0.3),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7F7FD5).withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: NetworkAvatarImage(
                          imageUrl: post.userAvatar,
                          radius: 22,
                          placeholderIcon: Icons.person,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 帖子内容
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _renderContentWithEmojis(post.content),
            ),

            // 话题标签（排除当前话题，避免重复显示）
            if (post.topicTags.where((tag) => tag.id != widget.topicTag.id).isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: post.topicTags
                    .where((tag) => tag.id != widget.topicTag.id)
                    .map((tag) => TopicTagDisplay(
                          tag: tag,
                          fontSize: 12,
                          showUsageCount: false,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TopicPostsPage(topicTag: tag),
                              ),
                            );
                          },
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 12),

            // 帖子图片
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 4),
              post.images.length == 1
                  ? GestureDetector(
                      onTap: () {},
                      child: Hero(
                        tag: 'post_img_${post.id}_0',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.network(
                              post.images[0],
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 300,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: post.images.length,
                        itemBuilder: (context, imgIndex) {
                          return Container(
                            margin: EdgeInsets.only(
                              right: imgIndex < post.images.length - 1 ? 12 : 0,
                            ),
                            child: GestureDetector(
                              onTap: () {},
                              child: Hero(
                                tag: 'post_img_${post.id}_$imgIndex',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Image.network(
                                      post.images[imgIndex],
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 200,
                                          height: 200,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.broken_image),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],

            const SizedBox(height: 20),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey[200]!,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 帖子互动
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : Colors.grey[600],
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey[600]),
                  onPressed: () {
                    Navigator.pushNamed(context, '/comments', arguments: post.id);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.share_rounded, color: Colors.grey[600]),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                        child: _buildPostCard(post),
                      );
                    },
                  ),
                ),
    );
  }
}
