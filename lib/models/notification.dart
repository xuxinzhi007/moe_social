import '../utils/api_json.dart';

class NotificationModel {
  // 通知类型常量
  static const int like = 1;
  static const int comment = 2;
  static const int follow = 3;
  static const int system = 4;
  static const int directMessage = 6;
  static const int announcement = 7;

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

  /// 公告 ID（type=announcement 时由 post_id 承载）。
  String? get announcementId =>
      type == announcement && (postId ?? '').isNotEmpty ? postId : null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final typeRaw = json['type'];
    final senderRaw = json['sender_id'];
    return NotificationModel(
      id: idRaw == null ? '' : idRaw.toString(),
      type: (typeRaw is num) ? typeRaw.toInt() : int.tryParse('$typeRaw') ?? 0,
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      postId: apiField(json, 'post_id', 'postId')?.toString(),
      senderId: senderRaw?.toString(),
      senderName: json['sender_name']?.toString(),
      senderAvatar: json['sender_avatar']?.toString(),
    );
  }

  // copyWith 方法，用于创建副本并修改部分字段
  NotificationModel copyWith({
    String? id,
    int? type,
    String? content,
    bool? isRead,
    DateTime? createdAt,
    String? postId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      postId: postId ?? this.postId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
    );
  }

  // 获取通知标题
  String get title {
    switch (type) {
      case like:
        return senderName != null ? '$senderName 赞了你的动态' : '有人赞了你的动态';
      case comment:
        return senderName != null ? '$senderName 评论了你的动态' : '有人评论了你的动态';
      case follow:
        return senderName != null ? '$senderName 关注了你' : '有人关注了你';
      case system:
        return '系统通知';
      case announcement:
        return '系统公告';
      case directMessage:
        return senderName != null ? '$senderName 给你发来了私信' : '收到一条新的私信';
      default:
        return '新通知';
    }
  }

  // 获取关联用户头像（兼容性 getter）
  String? get relatedUserAvatar => senderAvatar;
}

// 兼容别名
typedef NotificationItem = NotificationModel;
