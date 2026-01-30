import 'dart:convert';

/// 经验日志记录模型
class ExpLogRecord {
  final String id;
  final int expChange;
  final String source;
  final String description;
  final String createdAt;

  ExpLogRecord({
    required this.id,
    required this.expChange,
    required this.source,
    required this.description,
    required this.createdAt,
  });

  /// 从JSON创建ExpLogRecord对象
  factory ExpLogRecord.fromJson(Map<String, dynamic> json) {
    return ExpLogRecord(
      id: json['id'] ?? '',
      expChange: json['exp_change'] ?? 0,
      source: json['source'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exp_change': expChange,
      'source': source,
      'description': description,
      'created_at': createdAt,
    };
  }

  /// 从JSON字符串创建ExpLogRecord对象
  factory ExpLogRecord.fromJsonString(String str) {
    return ExpLogRecord.fromJson(json.decode(str));
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return json.encode(toJson());
  }

  /// 复制对象并更新指定字段
  ExpLogRecord copyWith({
    String? id,
    int? expChange,
    String? source,
    String? description,
    String? createdAt,
  }) {
    return ExpLogRecord(
      id: id ?? this.id,
      expChange: expChange ?? this.expChange,
      source: source ?? this.source,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 获取经验变化的符号（+/-）
  String get expChangeSign {
    return expChange >= 0 ? '+' : '';
  }

  /// 获取经验变化的绝对值
  int get expChangeAbs {
    return expChange.abs();
  }

  /// 获取经验变化的文本（带符号）
  String get expChangeText {
    return '$expChangeSign$expChange';
  }

  /// 获取经验来源的显示文本
  String get sourceDisplayText {
    switch (source.toLowerCase()) {
      case 'check_in':
        return '每日签到';
      case 'post':
        return '发布帖子';
      case 'like':
        return '点赞互动';
      case 'comment':
        return '评论互动';
      case 'vip_bonus':
        return 'VIP奖励';
      case 'admin':
        return '管理员赠送';
      case 'activity':
        return '活动奖励';
      case 'achievement':
        return '成就奖励';
      default:
        return source;
    }
  }

  /// 获取经验来源的图标
  String get sourceIcon {
    switch (source.toLowerCase()) {
      case 'check_in':
        return '📅';
      case 'post':
        return '📝';
      case 'like':
        return '👍';
      case 'comment':
        return '💬';
      case 'vip_bonus':
        return '👑';
      case 'admin':
        return '🛡️';
      case 'activity':
        return '🎉';
      case 'achievement':
        return '🏆';
      default:
        return '⭐';
    }
  }

  /// 获取格式化的创建时间
  DateTime? get createdDateTime {
    try {
      return DateTime.parse(createdAt);
    } catch (e) {
      return null;
    }
  }

  /// 获取格式化的时间字符串（MM-dd HH:mm）
  String get formattedTime {
    final date = createdDateTime;
    if (date != null) {
      return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
             '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return createdAt;
  }

  /// 获取相对时间文本（如：2小时前）
  String get relativeTimeText {
    final date = createdDateTime;
    if (date == null) return createdAt;

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  /// 判断是否是今天的记录
  bool get isToday {
    final date = createdDateTime;
    if (date != null) {
      final now = DateTime.now();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }
    return false;
  }

  /// 判断经验是否为正数（获得经验）
  bool get isGain {
    return expChange > 0;
  }

  /// 判断经验是否为负数（消耗经验）
  bool get isLoss {
    return expChange < 0;
  }

  @override
  String toString() {
    return 'ExpLogRecord(id: $id, expChange: $expChange, source: $source, '
           'description: $description, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpLogRecord &&
        other.id == id &&
        other.expChange == expChange &&
        other.source == source &&
        other.description == description &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        expChange.hashCode ^
        source.hashCode ^
        description.hashCode ^
        createdAt.hashCode;
  }
}