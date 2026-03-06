import 'package:flutter/material.dart';
import 'models/comment.dart';
import 'services/post_service.dart';
import 'services/api_service.dart';
import 'auth_service.dart';
import 'widgets/avatar_image.dart';
import 'widgets/fade_in_up.dart';
import 'widgets/like_button.dart';

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
  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _userName;
  String? _userAvatar;

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

    setState(() {
      _isSubmitting = true;
    });

    final userId = AuthService.currentUser;
    if (userId == null) {
      _showCustomSnackBar(context, '请先登录', isError: true);
      return;
    }

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

    // 乐观更新
    setState(() {
      _comments = _comments.map((comment) {
        if (comment.id == commentId) {
          final isLiked = !comment.isLiked;
          return comment.copyWith(
            isLiked: isLiked,
            likes: isLiked ? comment.likes + 1 : comment.likes - 1,
          );
        }
        return comment;
      }).toList();
    });

    try {
      final updatedComment = await PostService.toggleCommentLike(commentId, userId);
      setState(() {
        _comments = _comments.map((comment) {
          if (comment.id == commentId) {
            // 如果服务端返回的状态与当前乐观状态不一致（比如并发修改），以服务端为准
            // 但如果仅仅是 likes 数量差异，尽量不闪烁
            if (comment.isLiked != updatedComment.isLiked) {
               return updatedComment;
            }
            return comment;
          }
          return comment;
        }).toList();
      });
    } catch (e) {
      print('Failed to toggle comment like: $e');
      _showCustomSnackBar(context, '操作失败', isError: true);
      // 回滚
      setState(() {
        _comments = _comments.map((comment) {
          if (comment.id == commentId) {
            final isLiked = !comment.isLiked;
            return comment.copyWith(
              isLiked: isLiked,
              likes: isLiked ? comment.likes + 1 : comment.likes - 1,
            );
          }
          return comment;
        }).toList();
      });
    }
  }

  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('评论 (${_comments.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 评论列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7F7FD5).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFF7F7FD5)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无评论，快来抢沙发吧！',
                              style: TextStyle(color: Colors.grey[600], fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return FadeInUp(
                            delay: Duration(milliseconds: 30 * index),
                            child: _buildBubbleCommentItem(comment)
                          );
                        },
                      ),
          ),

          // 底部悬浮输入区域
          SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
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
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: '写下你的想法...',
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                              color: Color(0xFF7F7FD5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
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
          const SizedBox(width: 10),
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                    style: const TextStyle(height: 1.4, fontSize: 14, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 4),
                // 交互按钮行
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 使用新的点赞按钮
                    LikeButton(
                      isLiked: comment.isLiked,
                      likeCount: comment.likes,
                      onTap: () => _toggleCommentLike(comment.id),
                      size: 18,
                      showCount: true,
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
