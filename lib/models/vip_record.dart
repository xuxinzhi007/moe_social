class VipRecord {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final String startAt; // 后端返回的是字符串格式
  final String endAt; // 后端返回的是字符串格式
  final String status;
  final String createdAt; // 后端返回的是字符串格式

  VipRecord({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.createdAt,
  });

  // 从JSON创建VipRecord实例（后端返回格式）
  factory VipRecord.fromJson(Map<String, dynamic> json) {
    return VipRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String,
      planName: json['plan_name'] as String? ?? '',
      startAt: json['start_at'] as String,
      endAt: json['end_at'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  // 转换为JSON（用于发送到后端）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_id': planId,
      'plan_name': planName,
      'start_at': startAt,
      'end_at': endAt,
      'status': status,
      'created_at': createdAt,
    };
  }

  // 获取开始时间的DateTime对象（用于显示）
  DateTime? get startAtDateTime {
    try {
      return DateTime.parse(startAt);
    } catch (e) {
      return null;
    }
  }

  // 获取结束时间的DateTime对象（用于显示）
  DateTime? get endAtDateTime {
    try {
      return DateTime.parse(endAt);
    } catch (e) {
      return null;
    }
  }

  // 获取创建时间的DateTime对象（用于显示）
  DateTime? get createdAtDateTime {
    try {
      return DateTime.parse(createdAt);
    } catch (e) {
      return null;
    }
  }

  // 检查是否活跃（根据状态和结束时间）
  bool get isActive {
    if (status.toLowerCase() != 'active') return false;
    final end = endAtDateTime;
    if (end == null) return false;
    return end.isAfter(DateTime.now());
  }
}