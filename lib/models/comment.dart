import '../utils/api_datetime.dart';

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
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    try {
      final createdAt = parseApiDateTime(json['created_at'] as String?);

      final rawParent = json['parent_id'];
      final parentId = rawParent == null
          ? ''
          : rawParent.toString().trim();

      return Comment(
        id: (json['id'] ?? '').toString(),
        postId: (json['post_id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        userName: (json['user_name'] ?? '未知用户').toString(),
        userAvatar:
            (json['user_avatar'] ?? 'https://picsum.photos/150').toString(),
        content: (json['content'] ?? '').toString(),
        likes: (json['likes'] as int?) ?? 0,
        isLiked: (json['is_liked'] ?? false) as bool,
        createdAt: createdAt,
        parentId: parentId == '0' ? '' : parentId,
        replyToUserName: (json['reply_to_user_name'] ?? '').toString(),
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
