import 'package:flutter/material.dart';

/// 成就徽章模型
class AchievementBadge {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final Color color;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final int requiredCount; // 达成条件的数量要求
  final String condition; // 达成条件描述
  final double progress; // 当前进度（0.0 - 1.0）
  final int currentCount; // 当前累计值（用于展示真实进度）
  final bool isUnlocked; // 是否已解锁
  final DateTime? unlockedAt; // 解锁时间

  const AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.category,
    required this.rarity,
    required this.requiredCount,
    required this.condition,
    this.progress = 0.0,
    this.currentCount = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  // 预定义的徽章列表
  static const List<AchievementBadge> defaultBadges = [
    AchievementBadge(
      id: 'welcome_aboard',
      name: '初来乍到',
      description: '完成首次登录，欢迎加入 Moe Social',
      emoji: '✨',
      color: Color(0xFF7F7FD5),
      category: BadgeCategory.special,
      rarity: BadgeRarity.common,
      requiredCount: 1,
      condition: '首次登录应用',
    ),
    // 社交类徽章
    AchievementBadge(
      id: 'first_post',
      name: '初出茅庐',
      description: '发布第一条动态',
      emoji: '🌱',
      color: Color(0xFF4CAF50),
      category: BadgeCategory.social,
      rarity: BadgeRarity.common,
      requiredCount: 1,
      condition: '发布1条动态',
    ),
    AchievementBadge(
      id: 'post_master',
      name: '内容达人',
      description: '持续分享，发布30条动态',
      emoji: '📝',
      color: Color(0xFF2196F3),
      category: BadgeCategory.social,
      rarity: BadgeRarity.rare,
      requiredCount: 30,
      condition: '发布30条动态',
    ),
    AchievementBadge(
      id: 'like_magnet',
      name: '点赞收割机',
      description: '单条动态获得20个点赞',
      emoji: '🧲',
      color: Color(0xFFE91E63),
      category: BadgeCategory.social,
      rarity: BadgeRarity.epic,
      requiredCount: 20,
      condition: '单条动态获得20个点赞',
    ),
    AchievementBadge(
      id: 'social_butterfly',
      name: '社交达人',
      description: '发表评论20次',
      emoji: '🦋',
      color: Color(0xFF9C27B0),
      category: BadgeCategory.social,
      rarity: BadgeRarity.rare,
      requiredCount: 20,
      condition: '发表20条评论',
    ),

    // 互动类徽章
    AchievementBadge(
      id: 'generous_giver',
      name: '慷慨之星',
      description: '送出5个礼物',
      emoji: '🎁',
      color: Color(0xFFFF9800),
      category: BadgeCategory.interaction,
      rarity: BadgeRarity.uncommon,
      requiredCount: 5,
      condition: '送出5个礼物',
    ),
    AchievementBadge(
      id: 'gift_tycoon',
      name: '礼物大亨',
      description: '礼物总价值达到200',
      emoji: '💰',
      color: Color(0xFFFFD700),
      category: BadgeCategory.interaction,
      rarity: BadgeRarity.legendary,
      requiredCount: 200,
      condition: '礼物总价值达到200',
    ),
    AchievementBadge(
      id: 'emotion_expert',
      name: '情感专家',
      description: '发布动态时使用5次情绪标签',
      emoji: '🎭',
      color: Color(0xFF607D8B),
      category: BadgeCategory.interaction,
      rarity: BadgeRarity.rare,
      requiredCount: 5,
      condition: '使用5次情绪标签',
    ),

    // 时间类徽章
    AchievementBadge(
      id: 'early_bird',
      name: '早起鸟儿',
      description: '在早晨 8 点前发布3次动态',
      emoji: '🐦',
      color: Color(0xFF03DAC5),
      category: BadgeCategory.time,
      rarity: BadgeRarity.uncommon,
      requiredCount: 3,
      condition: '早于8点发布3条动态',
    ),
    AchievementBadge(
      id: 'night_owl',
      name: '夜猫子',
      description: '在夜间 23 点后发布3次动态',
      emoji: '🦉',
      color: Color(0xFF6A1B9A),
      category: BadgeCategory.time,
      rarity: BadgeRarity.uncommon,
      requiredCount: 3,
      condition: '晚于23点发布3条动态',
    ),
    AchievementBadge(
      id: 'loyal_user',
      name: '忠实用户',
      description: '完成7次每日活跃签到',
      emoji: '⭐',
      color: Color(0xFFF57C00),
      category: BadgeCategory.time,
      rarity: BadgeRarity.rare,
      requiredCount: 7,
      condition: '完成7次每日签到/活跃',
    ),
    AchievementBadge(
      id: 'daily_task_keeper',
      name: '日常打卡王',
      description: '完成5天日常任务组合',
      emoji: '📅',
      color: Color(0xFF86A8E7),
      category: BadgeCategory.time,
      rarity: BadgeRarity.uncommon,
      requiredCount: 5,
      condition: '同一天完成至少2个日常任务，共5天',
    ),
    AchievementBadge(
      id: 'weekly_task_keeper',
      name: '周常执行官',
      description: '完成4次周常任务目标',
      emoji: '🗓️',
      color: Color(0xFF91EAE4),
      category: BadgeCategory.time,
      rarity: BadgeRarity.rare,
      requiredCount: 4,
      condition: '同一周完成至少8个任务行为，共4周',
    ),

    // 特殊类徽章
    AchievementBadge(
      id: 'vip_member',
      name: 'VIP会员',
      description: '成为VIP会员',
      emoji: '👑',
      color: Color(0xFFFFD700),
      category: BadgeCategory.special,
      rarity: BadgeRarity.epic,
      requiredCount: 1,
      condition: '开通VIP会员',
    ),
    AchievementBadge(
      id: 'trendsetter',
      name: '潮流引领者',
      description: '发布20条带话题动态',
      emoji: '🔥',
      color: Color(0xFFFF5722),
      category: BadgeCategory.special,
      rarity: BadgeRarity.legendary,
      requiredCount: 20,
      condition: '累计发布20条带话题的动态',
    ),
    AchievementBadge(
      id: 'photographer',
      name: '摄影师',
      description: '发布10张照片',
      emoji: '📸',
      color: Color(0xFF795548),
      category: BadgeCategory.special,
      rarity: BadgeRarity.uncommon,
      requiredCount: 10,
      condition: '发布10张照片',
    ),
    AchievementBadge(
      id: 'influencer',
      name: '意见领袖',
      description: '粉丝数量达到200',
      emoji: '📢',
      color: Color(0xFFE040FB),
      category: BadgeCategory.special,
      rarity: BadgeRarity.legendary,
      requiredCount: 200,
      condition: '粉丝数量达到200',
    ),

    // 创意类徽章
    AchievementBadge(
      id: 'creative_genius',
      name: '创意天才',
      description: '获得3个原创内容认证',
      emoji: '💡',
      color: Color(0xFFFFEB3B),
      category: BadgeCategory.creative,
      rarity: BadgeRarity.epic,
      requiredCount: 3,
      condition: '获得3个原创内容认证',
    ),
    AchievementBadge(
      id: 'storyteller',
      name: '故事大王',
      description: '发布3个长文章',
      emoji: '📚',
      color: Color(0xFF8BC34A),
      category: BadgeCategory.creative,
      rarity: BadgeRarity.rare,
      requiredCount: 3,
      condition: '发布3个长文章（>500字）',
    ),
  ];

  // 从JSON创建实例
  factory AchievementBadge.fromJson(Map<String, dynamic> json) {
    return AchievementBadge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      emoji: json['emoji'] as String,
      color: Color(json['color'] as int),
      category: BadgeCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => BadgeCategory.social,
      ),
      rarity: BadgeRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => BadgeRarity.common,
      ),
      requiredCount: json['required_count'] as int,
      condition: json['condition'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      currentCount: json['current_count'] as int? ?? 0,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'color': color.toARGB32(),
      'category': category.name,
      'rarity': rarity.name,
      'required_count': requiredCount,
      'condition': condition,
      'progress': progress,
      'current_count': currentCount,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }

  // 根据ID查找徽章
  static AchievementBadge? findById(String id) {
    try {
      return defaultBadges.firstWhere((badge) => badge.id == id);
    } catch (e) {
      return null;
    }
  }

  // 根据分类获取徽章
  static List<AchievementBadge> getBadgesByCategory(BadgeCategory category) {
    return defaultBadges.where((badge) => badge.category == category).toList();
  }

  // 根据稀有度获取徽章
  static List<AchievementBadge> getBadgesByRarity(BadgeRarity rarity) {
    return defaultBadges.where((badge) => badge.rarity == rarity).toList();
  }

  // 获取已解锁的徽章
  static List<AchievementBadge> getUnlockedBadges(List<String> unlockedIds) {
    return defaultBadges
        .where((badge) => unlockedIds.contains(badge.id))
        .map((badge) => badge.copyWith(isUnlocked: true))
        .toList();
  }

  // 获取推荐徽章（接近完成的）
  static List<AchievementBadge> getRecommendedBadges(
      Map<String, double> progressMap) {
    return defaultBadges
        .where((badge) =>
            !badge.isUnlocked &&
            (progressMap[badge.id] ?? 0.0) > 0.5 &&
            (progressMap[badge.id] ?? 0.0) < 1.0)
        .map((badge) => badge.copyWith(progress: progressMap[badge.id] ?? 0.0))
        .toList();
  }

  // 复制并修改属性
  AchievementBadge copyWith({
    String? id,
    String? name,
    String? description,
    String? emoji,
    Color? color,
    BadgeCategory? category,
    BadgeRarity? rarity,
    int? requiredCount,
    String? condition,
    double? progress,
    int? currentCount,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return AchievementBadge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      requiredCount: requiredCount ?? this.requiredCount,
      condition: condition ?? this.condition,
      progress: progress ?? this.progress,
      currentCount: currentCount ?? this.currentCount,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementBadge &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 徽章分类枚举
enum BadgeCategory {
  social('社交', Icons.groups_rounded),
  interaction('互动', Icons.volunteer_activism_rounded),
  time('时间', Icons.schedule_rounded),
  special('特殊', Icons.auto_awesome_rounded),
  creative('创意', Icons.palette_rounded);

  const BadgeCategory(this.displayName, this.categoryIcon);

  final String displayName;
  final IconData categoryIcon;
}

/// 徽章稀有度枚举
enum BadgeRarity {
  common('普通', Color(0xFF9E9E9E), 1),
  uncommon('少见', Color(0xFF4CAF50), 2),
  rare('稀有', Color(0xFF2196F3), 3),
  epic('史诗', Color(0xFF9C27B0), 4),
  legendary('传说', Color(0xFFFFD700), 5);

  const BadgeRarity(this.displayName, this.color, this.level);

  final String displayName;
  final Color color;
  final int level;

  /// 外环渐变（用于徽章金属质感）
  List<Color> get tierGradient {
    switch (this) {
      case BadgeRarity.common:
        return const [Color(0xFFB0BEC5), Color(0xFF455A64)];
      case BadgeRarity.uncommon:
        return const [Color(0xFF81C784), Color(0xFF1B5E20)];
      case BadgeRarity.rare:
        return const [Color(0xFF64B5F6), Color(0xFF0D47A1)];
      case BadgeRarity.epic:
        return const [Color(0xFFCE93D8), Color(0xFF4A148C)];
      case BadgeRarity.legendary:
        return const [Color(0xFFFFE082), Color(0xFFFF9100), Color(0xFFE65100)];
    }
  }
}

/// 用户徽章进度模型
class UserBadgeProgress {
  final String userId;
  final String badgeId;
  final double progress;
  final int currentCount;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final DateTime updatedAt;

  UserBadgeProgress({
    required this.userId,
    required this.badgeId,
    required this.progress,
    required this.currentCount,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.updatedAt,
  });

  // 获取徽章信息
  AchievementBadge? get badge => AchievementBadge.findById(badgeId);

  // 从JSON创建实例
  factory UserBadgeProgress.fromJson(Map<String, dynamic> json) {
    return UserBadgeProgress(
      userId: json['user_id'] as String,
      badgeId: json['badge_id'] as String,
      progress: (json['progress'] as num).toDouble(),
      currentCount: json['current_count'] as int,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'badge_id': badgeId,
      'progress': progress,
      'current_count': currentCount,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}