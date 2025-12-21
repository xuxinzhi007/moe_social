import 'package:flutter/material.dart';
import 'models/comment.dart';
import 'services/post_service.dart';
import 'widgets/avatar_image.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchComments();
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

    try {
      final newComment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        postId: widget.postId,
        userId: 'current_user',
        userName: '当前用户',
        userAvatar: 'https://randomuser.me/api/portraits/men/97.jpg',
        content: _commentController.text.trim(),
        likes: 0,
        isLiked: false,
        createdAt: DateTime.now(),
      );

      await PostService.addComment(newComment);
      
      setState(() {
        _comments.add(newComment);
        _commentController.clear();
      });

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
    try {
      final updatedComment = await PostService.toggleCommentLike(commentId);
      setState(() {
        _comments = _comments.map((comment) {
          if (comment.id == commentId) {
            return updatedComment;
          }
          return comment;
        }).toList();
      });
    } catch (e) {
      print('Failed to toggle comment like: $e');
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('评论 (${_comments.length})'),
      ),
      body: Column(
        children: [
          // 评论列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无评论，快来抢沙发吧！',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
          ),

          // 评论输入框
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    'https://randomuser.me/api/portraits/men/97.jpg',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: '写下你的评论...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: _addComment,
                        icon: const Icon(Icons.send),
                        color: Colors.blueAccent,
                        iconSize: 24,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkAvatarImage(
            imageUrl: comment.userAvatar,
            radius: 20,
            placeholderIcon: Icons.person,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        comment.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatTime(comment.createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.content),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _toggleCommentLike(comment.id),
                        icon: Icon(
                          comment.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: comment.isLiked ? Colors.red : Colors.grey,
                          size: 16,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.likes}',
                        style: TextStyle(
                          color: comment.isLiked ? Colors.red : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.reply_outlined,
                          color: Colors.grey,
                          size: 16,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '回复',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
