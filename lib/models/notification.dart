class NotificationModel {
  // 通知类型枚举
  static const String like = 'like';
  static const String comment = 'comment';
  static const String follow = 'follow';
  static const String system = 'system';

  final String id;
  final String type;
  final String title;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedPostId;
  final String? relatedUserId;
  final String? relatedUserName;
  final String? relatedUserAvatar;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.isRead = false,
    required this.createdAt,
    this.relatedPostId,
    this.relatedUserId,
    this.relatedUserName,
    this.relatedUserAvatar,
  });

  // 从JSON创建通知对象
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      relatedPostId: json['related_post_id'] as String?,
      relatedUserId: json['related_user_id'] as String?,
      relatedUserName: json['related_user_name'] as String?,
      relatedUserAvatar: json['related_user_avatar'] as String?,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'related_post_id': relatedPostId,
      'related_user_id': relatedUserId,
      'related_user_name': relatedUserName,
      'related_user_avatar': relatedUserAvatar,
    };
  }

  // 复制方法，用于更新isRead状态
  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      type: type,
      title: title,
      content: content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      relatedPostId: relatedPostId,
      relatedUserId: relatedUserId,
      relatedUserName: relatedUserName,
      relatedUserAvatar: relatedUserAvatar,
    );
  }
}
