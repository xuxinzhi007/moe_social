import 'dart:convert';

/// 用户等级信息模型
class UserLevelInfo {
  final int level;
  final int experience;
  final int totalExp;
  final int nextLevelExp;
  final String levelTitle;
  final String badgeUrl;
  final double progress;

  UserLevelInfo({
    required this.level,
    required this.experience,
    required this.totalExp,
    required this.nextLevelExp,
    required this.levelTitle,
    this.badgeUrl = '',
    required this.progress,
  });

  /// 从JSON创建UserLevelInfo对象
  factory UserLevelInfo.fromJson(Map<String, dynamic> json) {
    return UserLevelInfo(
      level: json['level'] ?? 1,
      experience: json['experience'] ?? 0,
      totalExp: json['total_exp'] ?? 0,
      nextLevelExp: json['next_level_exp'] ?? 100,
      levelTitle: json['level_title'] ?? '萌新菜鸟',
      badgeUrl: json['badge_url'] ?? '',
      progress: (json['progress'] ?? 0.0).toDouble(),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'experience': experience,
      'total_exp': totalExp,
      'next_level_exp': nextLevelExp,
      'level_title': levelTitle,
      'badge_url': badgeUrl,
      'progress': progress,
    };
  }

  /// 从JSON字符串创建UserLevelInfo对象
  factory UserLevelInfo.fromJsonString(String str) {
    return UserLevelInfo.fromJson(json.decode(str));
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return json.encode(toJson());
  }

  /// 复制对象并更新指定字段
  UserLevelInfo copyWith({
    int? level,
    int? experience,
    int? totalExp,
    int? nextLevelExp,
    String? levelTitle,
    String? badgeUrl,
    double? progress,
  }) {
    return UserLevelInfo(
      level: level ?? this.level,
      experience: experience ?? this.experience,
      totalExp: totalExp ?? this.totalExp,
      nextLevelExp: nextLevelExp ?? this.nextLevelExp,
      levelTitle: levelTitle ?? this.levelTitle,
      badgeUrl: badgeUrl ?? this.badgeUrl,
      progress: progress ?? this.progress,
    );
  }

  /// 获取到下一级所需的经验值
  int get expToNext => nextLevelExp - experience;

  /// 判断是否为最高等级
  bool get isMaxLevel => level >= 5;

  /// 获取等级进度百分比（0-100）
  double get progressPercentage => (progress * 100).clamp(0.0, 100.0);

  @override
  String toString() {
    return 'UserLevelInfo(level: $level, experience: $experience, totalExp: $totalExp, '
           'nextLevelExp: $nextLevelExp, levelTitle: $levelTitle, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserLevelInfo &&
        other.level == level &&
        other.experience == experience &&
        other.totalExp == totalExp &&
        other.nextLevelExp == nextLevelExp &&
        other.levelTitle == levelTitle &&
        other.badgeUrl == badgeUrl &&
        other.progress == progress;
  }

  @override
  int get hashCode {
    return level.hashCode ^
        experience.hashCode ^
        totalExp.hashCode ^
        nextLevelExp.hashCode ^
        levelTitle.hashCode ^
        badgeUrl.hashCode ^
        progress.hashCode;
  }
}