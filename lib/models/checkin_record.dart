import 'dart:convert';

/// 签到记录模型
class CheckInRecord {
  final String checkInDate;
  final int consecutiveDays;
  final int expReward;
  final bool isSpecialReward;
  final String specialRewardDesc;

  CheckInRecord({
    required this.checkInDate,
    required this.consecutiveDays,
    required this.expReward,
    this.isSpecialReward = false,
    this.specialRewardDesc = '',
  });

  /// 从JSON创建CheckInRecord对象
  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      checkInDate: json['check_in_date'] ?? '',
      consecutiveDays: json['consecutive_days'] ?? 1,
      expReward: json['exp_reward'] ?? 10,
      isSpecialReward: json['is_special_reward'] ?? false,
      specialRewardDesc: json['special_reward_desc'] ?? '',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'check_in_date': checkInDate,
      'consecutive_days': consecutiveDays,
      'exp_reward': expReward,
      'is_special_reward': isSpecialReward,
      'special_reward_desc': specialRewardDesc,
    };
  }

  /// 从JSON字符串创建CheckInRecord对象
  factory CheckInRecord.fromJsonString(String str) {
    return CheckInRecord.fromJson(json.decode(str));
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return json.encode(toJson());
  }

  /// 复制对象并更新指定字段
  CheckInRecord copyWith({
    String? checkInDate,
    int? consecutiveDays,
    int? expReward,
    bool? isSpecialReward,
    String? specialRewardDesc,
  }) {
    return CheckInRecord(
      checkInDate: checkInDate ?? this.checkInDate,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      expReward: expReward ?? this.expReward,
      isSpecialReward: isSpecialReward ?? this.isSpecialReward,
      specialRewardDesc: specialRewardDesc ?? this.specialRewardDesc,
    );
  }

  /// 获取格式化的签到日期
  DateTime? get checkInDateTime {
    try {
      return DateTime.parse(checkInDate);
    } catch (e) {
      return null;
    }
  }

  /// 获取格式化的日期字符串（MM-dd）
  String get formattedDate {
    final date = checkInDateTime;
    if (date != null) {
      return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    return checkInDate;
  }

  /// 获取格式化的完整日期字符串（yyyy年MM月dd日）
  String get formattedFullDate {
    final date = checkInDateTime;
    if (date != null) {
      return '${date.year}年${date.month}月${date.day}日';
    }
    return checkInDate;
  }

  /// 获取星期几的文本
  String get weekdayText {
    final date = checkInDateTime;
    if (date != null) {
      const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      return weekdays[date.weekday % 7];
    }
    return '';
  }

  /// 获取经验奖励的描述文本
  String get rewardText {
    if (isSpecialReward && specialRewardDesc.isNotEmpty) {
      return '$expReward经验 ($specialRewardDesc)';
    }
    return '$expReward经验';
  }

  /// 判断是否是今天的签到记录
  bool get isToday {
    final date = checkInDateTime;
    if (date != null) {
      final now = DateTime.now();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }
    return false;
  }

  /// 判断是否是这周的签到记录
  bool get isThisWeek {
    final date = checkInDateTime;
    if (date != null) {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return date.isAfter(startOfWeek) && date.isBefore(endOfWeek.add(const Duration(days: 1)));
    }
    return false;
  }

  @override
  String toString() {
    return 'CheckInRecord(checkInDate: $checkInDate, consecutiveDays: $consecutiveDays, '
           'expReward: $expReward, isSpecialReward: $isSpecialReward, specialRewardDesc: $specialRewardDesc)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckInRecord &&
        other.checkInDate == checkInDate &&
        other.consecutiveDays == consecutiveDays &&
        other.expReward == expReward &&
        other.isSpecialReward == isSpecialReward &&
        other.specialRewardDesc == specialRewardDesc;
  }

  @override
  int get hashCode {
    return checkInDate.hashCode ^
        consecutiveDays.hashCode ^
        expReward.hashCode ^
        isSpecialReward.hashCode ^
        specialRewardDesc.hashCode;
  }
}