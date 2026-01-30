import 'dart:convert';

/// 签到状态模型
class CheckInStatus {
  final bool hasCheckedToday;
  final int consecutiveDays;
  final int todayReward;
  final int nextDayReward;
  final bool canCheckIn;

  CheckInStatus({
    required this.hasCheckedToday,
    required this.consecutiveDays,
    required this.todayReward,
    required this.nextDayReward,
    required this.canCheckIn,
  });

  /// 从JSON创建CheckInStatus对象
  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    return CheckInStatus(
      hasCheckedToday: json['has_checked_today'] ?? false,
      consecutiveDays: json['consecutive_days'] ?? 0,
      todayReward: json['today_reward'] ?? 0,
      nextDayReward: json['next_day_reward'] ?? 10,
      canCheckIn: json['can_check_in'] ?? true,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'has_checked_today': hasCheckedToday,
      'consecutive_days': consecutiveDays,
      'today_reward': todayReward,
      'next_day_reward': nextDayReward,
      'can_check_in': canCheckIn,
    };
  }

  /// 从JSON字符串创建CheckInStatus对象
  factory CheckInStatus.fromJsonString(String str) {
    return CheckInStatus.fromJson(json.decode(str));
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return json.encode(toJson());
  }

  /// 复制对象并更新指定字段
  CheckInStatus copyWith({
    bool? hasCheckedToday,
    int? consecutiveDays,
    int? todayReward,
    int? nextDayReward,
    bool? canCheckIn,
  }) {
    return CheckInStatus(
      hasCheckedToday: hasCheckedToday ?? this.hasCheckedToday,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      todayReward: todayReward ?? this.todayReward,
      nextDayReward: nextDayReward ?? this.nextDayReward,
      canCheckIn: canCheckIn ?? this.canCheckIn,
    );
  }

  /// 获取签到状态描述文本
  String get statusText {
    if (hasCheckedToday) {
      return '今日已签到';
    } else if (canCheckIn) {
      return '可以签到';
    } else {
      return '无法签到';
    }
  }

  /// 获取连续签到天数的描述文本
  String get consecutiveDaysText {
    if (consecutiveDays <= 0) {
      return '尚未开始连续签到';
    } else if (consecutiveDays == 1) {
      return '连续签到 1 天';
    } else {
      return '连续签到 $consecutiveDays 天';
    }
  }

  /// 获取今日奖励的描述文本
  String get todayRewardText {
    if (hasCheckedToday) {
      return '今日已获得 $todayReward 经验';
    } else if (canCheckIn) {
      return '签到可获得 $todayReward 经验';
    } else {
      return '今日无法签到';
    }
  }

  /// 获取明日奖励的描述文本
  String get nextDayRewardText {
    return '明日签到可获得 $nextDayReward 经验';
  }

  @override
  String toString() {
    return 'CheckInStatus(hasCheckedToday: $hasCheckedToday, consecutiveDays: $consecutiveDays, '
           'todayReward: $todayReward, nextDayReward: $nextDayReward, canCheckIn: $canCheckIn)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckInStatus &&
        other.hasCheckedToday == hasCheckedToday &&
        other.consecutiveDays == consecutiveDays &&
        other.todayReward == todayReward &&
        other.nextDayReward == nextDayReward &&
        other.canCheckIn == canCheckIn;
  }

  @override
  int get hashCode {
    return hasCheckedToday.hashCode ^
        consecutiveDays.hashCode ^
        todayReward.hashCode ^
        nextDayReward.hashCode ^
        canCheckIn.hashCode;
  }
}