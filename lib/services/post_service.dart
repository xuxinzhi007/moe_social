import 'dart:async';
import '../models/post.dart';
import '../models/comment.dart';
import 'api_service.dart';

class PostService {
  // 获取所有帖子（支持分页）
  static Future<List<Post>> getPosts({int page = 1, int pageSize = 10}) async {
    return await ApiService.getPosts(page: page, pageSize: pageSize);
  }

  // 获取单个帖子
  static Future<Post?> getPostById(String id) async {
    try {
      return await ApiService.getPostById(id);
    } catch (e) {
      print('Failed to get post: $e');
      return null;
    }
  }

  // 创建新帖子
  static Future<Post> createPost(Post post) async {
    return await ApiService.createPost(post);
  }

  // 点赞/取消点赞帖子
  static Future<Post> toggleLike(String postId) async {
    return await ApiService.toggleLike(postId);
  }

  // 增加评论数
  static Future<Post> incrementComments(String postId) async {
    // 评论数会在添加评论时由后端自动更新
    // 这里不需要单独调用API
    final post = await ApiService.getPostById(postId);
    return post;
  }

  // 获取帖子评论
  static Future<List<Comment>> getComments(String postId) async {
    return await ApiService.getComments(postId);
  }

  // 添加评论
  static Future<Comment> addComment(Comment comment) async {
    return await ApiService.addComment(comment);
  }

  // 点赞/取消点赞评论
  static Future<Comment> toggleCommentLike(String commentId) async {
    return await ApiService.toggleCommentLike(commentId);
  }
}
