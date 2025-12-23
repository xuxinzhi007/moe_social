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
  });

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
    );
  }

  // 从JSON创建Comment实例（支持snake_case和camelCase）
  factory Comment.fromJson(Map<String, dynamic> json) {
    try {
      // 解析日期，支持多种格式
      DateTime createdAt;
      final createdAtStr = json['created_at'] as String?;
      if (createdAtStr != null) {
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
      } else {
        createdAt = DateTime.now();
      }

      return Comment(
        id: (json['id'] ?? '').toString(),
        postId: (json['post_id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        userName: (json['user_name'] ?? '未知用户').toString(),
        userAvatar: (json['user_avatar'] ?? 'https://via.placeholder.com/150').toString(),
        content: (json['content'] ?? '').toString(),
        likes: (json['likes'] as int?) ?? 0,
        isLiked: (json['is_liked'] ?? false) as bool,
        createdAt: createdAt,
      );
    } catch (e, stackTrace) {
      print('❌ Comment.fromJson错误: $e');
      print('❌ JSON数据: $json');
      print('❌ 堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  // 转换为JSON（使用snake_case匹配后端期望）
  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'user_id': userId,
      'content': content,
    };
  }
}
