import 'package:flutter/material.dart';
import 'models/comment.dart';
import 'services/post_service.dart';
import 'services/api_service.dart';
import 'auth_service.dart';
import 'services/like_state_manager.dart';
import 'widgets/avatar_image.dart';
import 'widgets/like_button.dart';
import 'widgets/moe_toast.dart';

class CommentsPage extends StatefulWidget {
  final String postId;

  const CommentsPage({
    Key? key,
    required this.postId,
  }) : super(key: key);

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _userName;
  String? _userAvatar;

  // Moe 风格颜色
  final Color _primaryColor = const Color(0xFF7F7FD5);
  final Color _accentColor = const Color(0xFF86A8E7);

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchComments();
  }

  Future<void> _loadUserInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    try {
      final user = await ApiService.getUserInfo(userId);
      setState(() {
        _userName = user.username;
        _userAvatar = user.avatar.isNotEmpty ? user.avatar : null;
      });
    } catch (e) {
      print('加载用户信息失败: $e');
    }
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await PostService.getComments(widget.postId);
      setState(() {
        _comments = comments;
      });
    } catch (e) {
      print('Failed to fetch comments: $e');
      _showCustomSnackBar(context, '获取评论失败', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      _showCustomSnackBar(context, '请输入评论内容', isError: true);
      return;
    }

    final userId = AuthService.currentUser;
    if (userId == null) {
      _showCustomSnackBar(context, '请先登录', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final comment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        postId: widget.postId,
        userId: userId,
        userName: _userName ?? '用户',
        userAvatar: _userAvatar ?? 'https://picsum.photos/150',
        content: _commentController.text.trim(),
        likes: 0,
        isLiked: false,
        createdAt: DateTime.now(),
      );

      await PostService.addComment(comment);
      
      _commentController.clear();
      await _fetchComments();

      _showCustomSnackBar(context, '评论成功', isError: false);
    } catch (e) {
      print('Failed to add comment: $e');
      _showCustomSnackBar(context, '评论失败，请重试', isError: true);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      _showCustomSnackBar(context, '请先登录', isError: true);
      return;
    }

    // 乐观更新：LikeStateManager 会自动处理状态变化，UI 通过 ValueListenableBuilder 监听更新
    // 这里只需要调用 Service 方法即可
    try {
      await PostService.toggleCommentLike(commentId, userId);
      // 无需手动 setState 更新 _comments，因为 LikeButton 现在直接监听 LikeStateManager
    } catch (e) {
      print('Failed to toggle comment like: $e');
      _showCustomSnackBar(context, '操作失败', isError: true);
    }
  }

  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (isError) {
      MoeToast.error(context, message);
    } else {
      MoeToast.success(context, message);
    }
  }

  @override
  void dispose() {
    _commentFocus.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_comments.length);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text('评论 (${_comments.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context, _comments.length),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: _primaryColor,
              onRefresh: _fetchComments,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  if (_isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_comments.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded,
                                  size: 48, color: Color(0xFF7F7FD5)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无评论，下拉可刷新',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '快来抢沙发吧～',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final comment = _comments[index];
                            return KeyedSubtree(
                              key: ValueKey('comment_${comment.id}'),
                              child: _buildBubbleCommentItem(comment),
                            );
                          },
                          childCount: _comments.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 底部悬浮输入区域
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), // 适配全面屏底部
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF7F7FD5).withOpacity(0.3), width: 1.5),
                  ),
                  child: NetworkAvatarImage(
                    imageUrl: _userAvatar,
                    radius: 16,
                    placeholderIcon: Icons.person,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocus,
                      decoration: const InputDecoration(
                        hintText: '写下你的想法...',
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7F7FD5)),
                      )
                    : InkWell(
                        onTap: _addComment,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildBubbleCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkAvatarImage(
            imageUrl: comment.userAvatar,
            radius: 18,
            placeholderIcon: Icons.person,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                      topLeft: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7F7FD5).withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    comment.content,
                    style: TextStyle(
                      height: 1.5,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: LikeStateManager().getCommentStatusNotifier(
                        comment.id,
                        initialValue: comment.isLiked,
                      ),
                      builder: (context, isLiked, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: LikeStateManager().getCommentCountNotifier(
                            comment.id,
                            initialValue: comment.likes,
                          ),
                          builder: (context, likeCount, _) {
                            return LikeButton(
                              isLiked: isLiked,
                              likeCount: likeCount,
                              onTap: () => _toggleCommentLike(comment.id),
                              size: 18,
                              showCount: true,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () {
                        _commentController.text = '@${comment.userName} ';
                        _commentController.selection = TextSelection.collapsed(
                            offset: _commentController.text.length);
                        _commentFocus.requestFocus();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '回复',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}
