import 'dart:convert';
import 'topic_tag.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final List<String> images;
  final int likes;
  final int comments;
  final bool isLiked;
  final DateTime createdAt;
  final List<TopicTag> topicTags; // 话题标签列表

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    this.images = const [],
    this.likes = 0,
    this.comments = 0,
    this.isLiked = false,
    required this.createdAt,
    this.topicTags = const [],
  });

  Post copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? content,
    List<String>? images,
    int? likes,
    int? comments,
    bool? isLiked,
    DateTime? createdAt,
    List<TopicTag>? topicTags,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      images: images ?? this.images,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      topicTags: topicTags ?? this.topicTags,
    );
  }

  // 从JSON创建Post实例
  factory Post.fromJson(Map<String, dynamic> json) {
    try {
      // 调试：打印原始JSON的关键字段
      final contentStr = json['content']?.toString() ?? '';
      final contentPreview = contentStr.length > 30 ? '${contentStr.substring(0, 30)}...' : contentStr;
      print('📋 解析帖子 ID: ${json['id']}');
      print('   内容: $contentPreview');
      print('   images字段: ${json['images']} (类型: ${json['images']?.runtimeType})');
      print('   topic_tags字段: ${json['topic_tags']} (类型: ${json['topic_tags']?.runtimeType})');
      // 解析日期，支持多种格式
      DateTime createdAt;
      final createdAtStr = json['created_at'] as String;
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (e) {
        // 如果标准格式解析失败，尝试自定义格式
        try {
          createdAt = DateTime.parse(createdAtStr.replaceAll(' ', 'T') + 'Z');
        } catch (e2) {
          // 如果还是失败，使用当前时间
          print('⚠️ 日期解析失败: $createdAtStr, 使用当前时间');
          createdAt = DateTime.now();
        }
      }
      
      // 解析话题标签
      List<TopicTag> topicTags = [];
      if (json['topic_tags'] != null) {
        try {
          final tagsList = json['topic_tags'];
          if (tagsList is List) {
            topicTags = tagsList
                .where((tag) => tag != null)
                .map((tagJson) {
                  if (tagJson is Map<String, dynamic>) {
                    return TopicTag.fromJson(tagJson);
                  }
                  return null;
                })
                .whereType<TopicTag>()
                .toList();
            print('📌 解析话题标签: ${topicTags.length} 个');
          }
        } catch (e) {
          print('⚠️ 解析话题标签失败: $e');
        }
      } else {
        print('⚠️ topic_tags 字段为 null');
      }
      
      // 处理images为null的情况
      final imagesData = json['images'];
      List<String> images = [];
      if (imagesData != null) {
        if (imagesData is List) {
          images = imagesData
              .where((img) => img != null && img.toString().isNotEmpty)
              .map((img) => img.toString())
              .toList();
          print('🖼️ 解析图片: ${images.length} 张');
        } else if (imagesData is String && imagesData.isNotEmpty) {
          // 兼容字符串格式（虽然不应该出现）
          try {
            final decoded = jsonDecode(imagesData) as List;
            images = decoded.map((img) => img.toString()).toList();
            print('🖼️ 从字符串解析图片: ${images.length} 张');
          } catch (e) {
            print('⚠️ 图片字符串解析失败: $e');
          }
        }
      } else {
        print('⚠️ images 字段为 null');
      }

      return Post(
        id: (json['id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        userName: (json['user_name'] ?? '未知用户').toString(),
        userAvatar: (json['user_avatar'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        images: images,
        likes: (json['likes'] as int?) ?? 0,
        comments: (json['comments'] as int?) ?? 0,
        isLiked: (json['is_liked'] as bool?) ?? false,
        createdAt: createdAt,
        topicTags: topicTags,
      );
    } catch (e, stackTrace) {
      print('❌ Post.fromJson错误: $e');
      print('❌ JSON数据: $json');
      print('❌ 堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  // 转换为JSON，注意使用下划线命名格式匹配后端期望
  Map<String, dynamic> toJson() {
    final json = {
      'user_id': userId,
      'content': content,
      'images': images,
    };

    // 添加话题标签（如果存在）
    if (topicTags.isNotEmpty) {
      json['topic_tags'] = topicTags.map((tag) => tag.toJson()).toList();
    }

    return json;
  }
}
