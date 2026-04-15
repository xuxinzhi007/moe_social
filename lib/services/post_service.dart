import 'dart:async';
import '../models/post.dart';
import '../models/comment.dart';
import 'api_service.dart';
import '../auth_service.dart';
import 'like_state_manager.dart';

class PostService {
  // 获取所有帖子（支持分页），并同步全局状态
  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int pageSize = 10,
    String? feedMode,
    String? topicTagId,
    String? authorUserId,
  }) async {
    final viewer =
        AuthService.isLoggedIn ? (AuthService.currentUser ?? '') : '';
    final result = await ApiService.getPosts(
      page: page,
      pageSize: pageSize,
      viewerUserId: viewer.isEmpty ? null : viewer,
      feedMode: feedMode,
      topicTagId: topicTagId,
      authorUserId: authorUserId,
    );
    List<Post> posts = result['posts'];

    for (var post in posts) {
      LikeStateManager().syncState(post.id, post.isLiked, post.likes);
    }
    
    return result;
  }

  // 获取单个帖子
  static Future<Post?> getPostById(String id) async {
    try {
      final viewer =
          AuthService.isLoggedIn ? (AuthService.currentUser ?? '') : '';
      var post = await ApiService.getPostById(
        id,
        viewerUserId: viewer.isEmpty ? null : viewer,
      );

      LikeStateManager().syncState(post.id, post.isLiked, post.likes);
      return post;
    } catch (e) {
      print('Failed to get post: $e');
      return null;
    }
  }

  // 点赞/取消点赞帖子
  static Future<Post> toggleLike(String postId, String userId) async {
    // 1. 乐观更新全局状态管理器（立即更新 UI）
    final manager = LikeStateManager();
    
    // 获取当前状态用于回滚
    bool originalLiked = false;
    int originalCount = 0;
    
    final statusNotifier = manager.getStatusNotifier(postId);
    final countNotifier = manager.getCountNotifier(postId);
    originalLiked = statusNotifier.value;
    originalCount = countNotifier.value;

    // 立即切换状态
    manager.toggleLike(postId);
    
    try {
      // 2. 调用 API
      final updatedPost = await ApiService.toggleLike(postId, userId);
      
      // 3. 成功后使用服务器返回的最新状态确认更新（修正可能存在的偏差）
      manager.updateState(postId, updatedPost.isLiked, updatedPost.likes);

      return updatedPost;
    } catch (e) {
      // 5. 失败回滚
      manager.setLike(postId, originalLiked);
      manager.setCount(postId, originalCount);
      rethrow;
    }
  }

  // 增加评论数
  static Future<Post> incrementComments(String postId) async {
    // 评论数会在添加评论时由后端自动更新
    // 这里不需要单独调用API
    final viewer =
        AuthService.isLoggedIn ? (AuthService.currentUser ?? '') : '';
    final post = await ApiService.getPostById(
      postId,
      viewerUserId: viewer.isEmpty ? null : viewer,
    );
    return post;
  }

  // 获取帖子评论
  static Future<List<Comment>> getComments(String postId) async {
    final viewer =
        AuthService.isLoggedIn ? (AuthService.currentUser ?? '') : '';
    final comments = await ApiService.getComments(
      postId,
      viewerUserId: viewer.isEmpty ? null : viewer,
    );
    
    // 同步到全局状态管理器
    for (var comment in comments) {
      LikeStateManager().syncCommentState(comment.id, comment.isLiked, comment.likes);
    }
    
    return comments;
  }

  // 添加评论
  static Future<Comment> addComment(Comment comment) async {
    return await ApiService.addComment(comment);
  }

  // 点赞/取消点赞评论
  static Future<Comment> toggleCommentLike(String commentId, String userId) async {
    // 1. 乐观更新全局状态管理器（立即更新 UI）
    final manager = LikeStateManager();
    
    // 获取当前状态用于回滚
    bool originalLiked = false;
    int originalCount = 0;
    
    final statusNotifier = manager.getCommentStatusNotifier(commentId);
    final countNotifier = manager.getCommentCountNotifier(commentId);
    originalLiked = statusNotifier.value;
    originalCount = countNotifier.value;

    // 立即切换状态
    manager.toggleCommentLike(commentId);
    
    try {
      // 2. 调用 API
      final updatedComment = await ApiService.toggleCommentLike(commentId, userId);
      
      // 3. 成功后确认更新
      manager.updateCommentState(commentId, updatedComment.isLiked, updatedComment.likes);
      
      return updatedComment;
    } catch (e) {
      // 4. 失败回滚
      manager.setCommentLike(commentId, originalLiked);
      manager.setCommentCount(commentId, originalCount);
      rethrow;
    }
  }
}
