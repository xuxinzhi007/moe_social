import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
      DateTime createdAt;
      final createdAtStr = json['created_at'] as String;
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (e) {
        try {
          createdAt = DateTime.parse('${createdAtStr.replaceAll(' ', 'T')}Z');
        } catch (e2) {
          if (kDebugMode) {
            debugPrint('Post.fromJson: 日期解析失败，使用当前时间: $createdAtStr');
          }
          createdAt = DateTime.now();
        }
      }

      List<TopicTag> topicTags = [];
      if (json['topic_tags'] != null) {
        try {
          final tagsList = json['topic_tags'];
          if (tagsList is List) {
            for (final tagJson in tagsList) {
              if (tagJson != null && tagJson is Map<String, dynamic>) {
                try {
                  topicTags.add(TopicTag.fromJson(tagJson));
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Post.fromJson: 单个话题标签解析失败: $e, data=$tagJson');
                  }
                }
              }
            }
          } else if (kDebugMode) {
            debugPrint(
                'Post.fromJson: topic_tags 类型异常: ${tagsList.runtimeType}');
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('Post.fromJson: 解析话题标签失败: $e\n$stackTrace');
          }
        }
      }

      final imagesData = json['images'];
      List<String> images = [];
      if (imagesData != null) {
        if (imagesData is List) {
          images = imagesData
              .where((img) => img != null && img.toString().isNotEmpty)
              .map((img) => img.toString())
              .toList();
        } else if (imagesData is String && imagesData.isNotEmpty) {
          try {
            final decoded = jsonDecode(imagesData) as List;
            images = decoded.map((img) => img.toString()).toList();
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Post.fromJson: 图片字符串解析失败: $e');
            }
          }
        }
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
      if (kDebugMode) {
        debugPrint('Post.fromJson 错误: $e\nJSON: $json\n$stackTrace');
      }
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
