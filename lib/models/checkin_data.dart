import 'dart:convert';

/// 签到操作返回数据模型
class CheckInData {
  final int expGained;
  final int newLevel;
  final int consecutiveDays;
  final bool levelUp;
  final String specialReward;
  final List<String> newlyUnlockedBadgeIds;

  CheckInData({
    required this.expGained,
    required this.newLevel,
    required this.consecutiveDays,
    this.levelUp = false,
    this.specialReward = '',
    this.newlyUnlockedBadgeIds = const [],
  });

  /// 从JSON创建CheckInData对象
  factory CheckInData.fromJson(Map<String, dynamic> json) {
    final raw = json['newly_unlocked_badge_ids'];
    List<String> ids = const [];
    if (raw is List) {
      ids = raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return CheckInData(
      expGained: json['exp_gained'] ?? 0,
      newLevel: json['new_level'] ?? 1,
      consecutiveDays: json['consecutive_days'] ?? 1,
      levelUp: json['level_up'] ?? false,
      specialReward: json['special_reward'] ?? '',
      newlyUnlockedBadgeIds: ids,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'exp_gained': expGained,
      'new_level': newLevel,
      'consecutive_days': consecutiveDays,
      'level_up': levelUp,
      'special_reward': specialReward,
      'newly_unlocked_badge_ids': newlyUnlockedBadgeIds,
    };
  }

  /// 从JSON字符串创建CheckInData对象
  factory CheckInData.fromJsonString(String str) {
    return CheckInData.fromJson(json.decode(str));
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return json.encode(toJson());
  }

  /// 复制对象并更新指定字段
  CheckInData copyWith({
    int? expGained,
    int? newLevel,
    int? consecutiveDays,
    bool? levelUp,
    String? specialReward,
    List<String>? newlyUnlockedBadgeIds,
  }) {
    return CheckInData(
      expGained: expGained ?? this.expGained,
      newLevel: newLevel ?? this.newLevel,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      levelUp: levelUp ?? this.levelUp,
      specialReward: specialReward ?? this.specialReward,
      newlyUnlockedBadgeIds:
          newlyUnlockedBadgeIds ?? this.newlyUnlockedBadgeIds,
    );
  }

  /// 获取签到成功的描述文本
  String get successText {
    String text = '签到成功！获得 $expGained 经验值';
    if (levelUp) {
      text += '，恭喜升级到 Lv.$newLevel！';
    }
    return text;
  }

  /// 获取连续签到天数的描述文本
  String get consecutiveDaysText {
    return '连续签到 $consecutiveDays 天';
  }

  /// 获取特殊奖励的描述文本
  String get specialRewardText {
    return specialReward.isNotEmpty ? specialReward : '无特殊奖励';
  }

  /// 判断是否有特殊奖励
  bool get hasSpecialReward {
    return specialReward.isNotEmpty;
  }

  @override
  String toString() {
    return 'CheckInData(expGained: $expGained, newLevel: $newLevel, '
           'consecutiveDays: $consecutiveDays, levelUp: $levelUp, specialReward: $specialReward, '
           'newlyUnlockedBadgeIds: $newlyUnlockedBadgeIds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckInData &&
        other.expGained == expGained &&
        other.newLevel == newLevel &&
        other.consecutiveDays == consecutiveDays &&
        other.levelUp == levelUp &&
        other.specialReward == specialReward &&
        _listEq(other.newlyUnlockedBadgeIds, newlyUnlockedBadgeIds);
  }

  @override
  int get hashCode {
    return expGained.hashCode ^
        newLevel.hashCode ^
        consecutiveDays.hashCode ^
        levelUp.hashCode ^
        specialReward.hashCode ^
        Object.hashAll(newlyUnlockedBadgeIds);
  }
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}