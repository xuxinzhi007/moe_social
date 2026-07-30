import '../utils/api_datetime.dart';
import '../utils/api_json.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final int likes;
  final bool isLiked;
  final DateTime createdAt;

  /// 父评论 ID；空或 "0" 表示一级评论
  final String parentId;
  final String replyToUserName;
  final bool authorIsBot;
  final String authorBotAgentKey;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    this.likes = 0,
    this.isLiked = false,
    required this.createdAt,
    this.parentId = '',
    this.replyToUserName = '',
    this.authorIsBot = false,
    this.authorBotAgentKey = '',
  });

  bool get isTopLevel => parentId.isEmpty || parentId == '0';

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? content,
    int? likes,
    bool? isLiked,
    DateTime? createdAt,
    String? parentId,
    String? replyToUserName,
    bool? authorIsBot,
    String? authorBotAgentKey,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
      replyToUserName: replyToUserName ?? this.replyToUserName,
      authorIsBot: authorIsBot ?? this.authorIsBot,
      authorBotAgentKey: authorBotAgentKey ?? this.authorBotAgentKey,
    );
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

  factory Comment.fromJson(Map<String, dynamic> json) {
    try {
      final createdRaw = apiField(json, 'created_at', 'createdAt');
      final createdAt = parseApiDateTime(createdRaw?.toString());

      final rawParent = apiField(json, 'parent_id', 'parentId');
      final parentId = rawParent == null ? '' : rawParent.toString().trim();

      final likesRaw = apiField(json, 'likes', 'likes');
      final isLikedRaw = apiField(json, 'is_liked', 'isLiked');

      return Comment(
        id: (json['id'] ?? '').toString(),
        postId: apiString(json, 'post_id', 'postId'),
        userId: apiString(json, 'user_id', 'userId'),
        userName: apiString(json, 'user_name', 'userName', fallback: '未知用户'),
        userAvatar: apiString(
          json,
          'user_avatar',
          'userAvatar',
          fallback: '',
        ),
        content: (json['content'] ?? '').toString(),
        likes: (likesRaw as num?)?.toInt() ?? 0,
        isLiked: isLikedRaw is bool
            ? isLikedRaw
            : (isLikedRaw is num ? isLikedRaw != 0 : false),
        createdAt: createdAt,
        parentId: parentId == '0' ? '' : parentId,
        replyToUserName:
            apiString(json, 'reply_to_user_name', 'replyToUserName'),
        authorIsBot: _parseBool(apiField(json, 'author_is_bot', 'authorIsBot')),
        authorBotAgentKey:
            apiString(json, 'author_bot_agent_key', 'authorBotAgentKey'),
      );
    } catch (e, stackTrace) {
      print('❌ Comment.fromJson错误: $e');
      print('❌ JSON数据: $json');
      print('❌ 堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'post_id': postId,
      'user_id': userId,
      'content': content,
    };
    if (!isTopLevel) {
      map['parent_id'] = parentId;
    }
    return map;
  }
}
