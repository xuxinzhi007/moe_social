class NotificationModel {
  final String id;
  final int type; // 1:like, 2:comment, 3:follow, 4:system
  final String content;
  bool isRead;
  final DateTime createdAt;
  
  // 关联信息
  final String? postId;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;

  NotificationModel({
    required this.id,
    required this.type,
    required this.content,
    this.isRead = false,
    required this.createdAt,
    this.postId,
    this.senderId,
    this.senderName,
    this.senderAvatar,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as int,
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      postId: json['post_id'] as String?,
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
    );
  }
}

// 兼容别名
typedef NotificationItem = NotificationModel;
