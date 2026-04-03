import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'hand_draw_card.dart';
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
  final List<TopicTag> topicTags;
  /// 独立字段中的手绘 JSON（列表接口通常不下发，详情才有）
  final String handDrawCardJson;
  final String handDrawThumbUrl;
  /// ok | pending | rejected
  final String moderationStatus;

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
    this.handDrawCardJson = '',
    this.handDrawThumbUrl = '',
    this.moderationStatus = '',
  });

  /// 展示用正文（独立手绘字段时 content 即为配文；旧数据则去掉内嵌块）
  String get displayCaption {
    if (handDrawCardJson.isNotEmpty) return content.trim();
    return HandDrawCardCodec.stripForDisplay(content);
  }

  /// 解析手绘数据：优先独立字段，否则旧版 content 内嵌
  HandDrawCardData? get handDrawCard {
    if (handDrawCardJson.isNotEmpty) {
      return HandDrawCardData.tryParseJsonString(handDrawCardJson);
    }
    return HandDrawCardCodec.tryDecode(content);
  }

  bool get isPendingModeration =>
      moderationStatus.toLowerCase() == 'pending';

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
    String? handDrawCardJson,
    String? handDrawThumbUrl,
    String? moderationStatus,
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
      handDrawCardJson: handDrawCardJson ?? this.handDrawCardJson,
      handDrawThumbUrl: handDrawThumbUrl ?? this.handDrawThumbUrl,
      moderationStatus: moderationStatus ?? this.moderationStatus,
    );
  }

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

      final hd = json['hand_draw_card'];
      final handDrawCardJson = hd == null ? '' : hd.toString();

      final th = json['hand_draw_thumb_url'];
      final handDrawThumbUrl = th == null ? '' : th.toString();

      final ms = json['moderation_status'];
      final moderationStatus = ms == null ? '' : ms.toString();

      return Post(
        id: (json['id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        userName: (json['user_name'] ?? '未知用户').toString(),
        userAvatar: (json['user_avatar'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        images: images,
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
        isLiked: (json['is_liked'] as bool?) ?? false,
        createdAt: createdAt,
        topicTags: topicTags,
        handDrawCardJson: handDrawCardJson,
        handDrawThumbUrl: handDrawThumbUrl,
        moderationStatus: moderationStatus,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Post.fromJson 错误: $e\nJSON: $json\n$stackTrace');
      }
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'content': content,
      'images': images,
    };

    if (topicTags.isNotEmpty) {
      json['topic_tags'] = topicTags.map((tag) => tag.toJson()).toList();
    }
    if (handDrawCardJson.isNotEmpty) {
      json['hand_draw_card'] = handDrawCardJson;
    }
    if (handDrawThumbUrl.isNotEmpty) {
      json['hand_draw_thumb_url'] = handDrawThumbUrl;
    }

    return json;
  }
}
