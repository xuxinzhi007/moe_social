import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import '../utils/api_json.dart';
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
  /// 独立字段中的手绘 JSON（列表不下发；回放时懒加载 GET /hand-draw）
  final String handDrawCardJson;
  final String handDrawThumbUrl;
  /// 服务端标记：帖子含手绘（列表仅下发此标志 + 缩略图 URL）
  final bool hasHandDraw;
  /// ok | pending | rejected
  final String moderationStatus;
  final String moodTag;
  final bool authorIsBot;
  final String authorBotAgentKey;

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
    this.hasHandDraw = false,
    this.moderationStatus = '',
    this.moodTag = '',
    this.authorIsBot = false,
    this.authorBotAgentKey = '',
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
    bool? hasHandDraw,
    String? moderationStatus,
    String? moodTag,
    bool? authorIsBot,
    String? authorBotAgentKey,
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
      hasHandDraw: hasHandDraw ?? this.hasHandDraw,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      moodTag: moodTag ?? this.moodTag,
      authorIsBot: authorIsBot ?? this.authorIsBot,
      authorBotAgentKey: authorBotAgentKey ?? this.authorBotAgentKey,
    );
  }

  static DateTime _parseCreatedAt(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(s);
      } catch (_) {
        try {
          return DateTime.parse('${s.replaceAll(' ', 'T')}Z');
        } catch (_) {
          if (kDebugMode) {
            debugPrint('Post.fromJson: 日期解析失败，使用当前时间: $s');
          }
          return DateTime.now();
        }
      }
    }
    if (raw is int) {
      if (raw < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    if (raw is num) {
      final v = raw.toInt();
      if (v < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    }
    return DateTime.now();
  }

  static bool _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final s = raw.toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post._fromJsonMap(json);
  }

  factory Post.fromJsonDynamic(dynamic raw) {
    return Post._fromJsonMap(apiMap(raw));
  }

  static Post _fromJsonMap(Map<String, dynamic> json) {
    try {
      final createdAt =
          _parseCreatedAt(apiField(json, 'created_at', 'createdAt'));

      List<TopicTag> topicTags = [];
      final topicTagsRaw = apiField(json, 'topic_tags', 'topicTags');
      if (topicTagsRaw != null) {
        try {
          final tagsList = topicTagsRaw;
          if (tagsList is List) {
            for (final tagJson in tagsList) {
              if (tagJson is Map) {
                try {
                  topicTags.add(TopicTag.fromJson(apiMap(tagJson)));
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

      final hd = apiField(json, 'hand_draw_card', 'handDrawCard');
      final handDrawCardJson = hd == null ? '' : hd.toString();

      final th = apiField(json, 'hand_draw_thumb_url', 'handDrawThumbUrl');
      final handDrawThumbUrl = th == null ? '' : th.toString();

      final hasHandDraw = _parseBool(apiField(json, 'has_hand_draw', 'hasHandDraw')) ||
          handDrawCardJson.isNotEmpty ||
          handDrawThumbUrl.isNotEmpty;

      final ms = apiField(json, 'moderation_status', 'moderationStatus');
      final moderationStatus = ms == null ? '' : ms.toString();

      return Post(
        id: (json['id'] ?? '').toString(),
        userId: apiString(json, 'user_id', 'userId'),
        userName: apiString(json, 'user_name', 'userName', fallback: '未知用户'),
        userAvatar: apiString(json, 'user_avatar', 'userAvatar'),
        content: (json['content'] ?? '').toString(),
        images: images,
        likes: apiInt(apiField(json, 'likes', 'likes')),
        comments: apiInt(apiField(json, 'comments', 'comments')),
        isLiked: _parseBool(apiField(json, 'is_liked', 'isLiked')),
        createdAt: createdAt,
        topicTags: topicTags,
        handDrawCardJson: handDrawCardJson,
        handDrawThumbUrl: handDrawThumbUrl,
        hasHandDraw: hasHandDraw,
        moderationStatus: moderationStatus,
        moodTag: apiString(json, 'mood_tag', 'moodTag'),
        authorIsBot: _parseBool(apiField(json, 'author_is_bot', 'authorIsBot')),
        authorBotAgentKey:
            apiString(json, 'author_bot_agent_key', 'authorBotAgentKey'),
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
    if (moodTag.isNotEmpty) {
      json['mood_tag'] = moodTag;
    }

    return json;
  }
}
