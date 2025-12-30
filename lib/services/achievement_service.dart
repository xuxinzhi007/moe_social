import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/achievement_badge.dart';
import '../models/user.dart';
import '../utils/error_handler.dart';

/// 成就系统服务
class AchievementService {
  static const String _userBadgesKey = 'user_badges';
  static const String _badgeProgressKey = 'badge_progress';

  // 单例模式
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  // 内存缓存
  Map<String, UserBadgeProgress> _progressCache = {};
  List<String> _unlockedBadges = [];

  /// 初始化用户徽章数据
  Future<void> initializeUserBadges(String userId) async {
    try {
      await _loadUserBadgesFromLocal(userId);
      await _initializeDefaultProgress(userId);
    } catch (e) {
      print('初始化用户徽章数据失败: $e');
    }
  }

  /// 从本地存储加载用户徽章数据
  Future<void> _loadUserBadgesFromLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    // 加载已解锁徽章
    final unlockedJson = prefs.getString('${_userBadgesKey}_$userId');
    if (unlockedJson != null) {
      final List<dynamic> unlockedList = json.decode(unlockedJson);
      _unlockedBadges = unlockedList.cast<String>();
    }

    // 加载徽章进度
    final progressJson = prefs.getString('${_badgeProgressKey}_$userId');
    if (progressJson != null) {
      final Map<String, dynamic> progressMap = json.decode(progressJson);
      _progressCache = progressMap.map(
        (key, value) => MapEntry(key, UserBadgeProgress.fromJson(value)),
      );
    }
  }

  /// 初始化默认进度（为所有徽章创建进度记录）
  Future<void> _initializeDefaultProgress(String userId) async {
    for (final badge in AchievementBadge.defaultBadges) {
      if (!_progressCache.containsKey(badge.id)) {
        _progressCache[badge.id] = UserBadgeProgress(
          userId: userId,
          badgeId: badge.id,
          progress: 0.0,
          currentCount: 0,
          isUnlocked: false,
          updatedAt: DateTime.now(),
        );
      }
    }
    await _saveProgressToLocal(userId);
  }

  /// 保存进度到本地存储
  Future<void> _saveProgressToLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    // 保存已解锁徽章
    await prefs.setString(
      '${_userBadgesKey}_$userId',
      json.encode(_unlockedBadges),
    );

    // 保存徽章进度
    final progressMap = _progressCache.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await prefs.setString(
      '${_badgeProgressKey}_$userId',
      json.encode(progressMap),
    );
  }

  /// 获取用户的所有徽章（带进度信息）
  List<AchievementBadge> getUserBadges(String userId) {
    return AchievementBadge.defaultBadges.map((badge) {
      final progress = _progressCache[badge.id];
      final isUnlocked = _unlockedBadges.contains(badge.id);

      return badge.copyWith(
        progress: progress?.progress ?? 0.0,
        isUnlocked: isUnlocked,
        unlockedAt: progress?.unlockedAt,
      );
    }).toList();
  }

  /// 获取已解锁的徽章
  List<AchievementBadge> getUnlockedBadges(String userId) {
    return getUserBadges(userId).where((badge) => badge.isUnlocked).toList();
  }

  /// 获取推荐徽章（接近完成的）
  List<AchievementBadge> getRecommendedBadges(String userId) {
    return getUserBadges(userId)
        .where((badge) => !badge.isUnlocked && badge.progress > 0.3)
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
  }

  /// 更新徽章进度
  Future<List<AchievementBadge>> updateBadgeProgress(
    String userId,
    String badgeId,
    int increment,
  ) async {
    final newlyUnlocked = <AchievementBadge>[];

    if (!_progressCache.containsKey(badgeId)) return newlyUnlocked;

    final currentProgress = _progressCache[badgeId]!;
    if (currentProgress.isUnlocked) return newlyUnlocked;

    final badge = AchievementBadge.findById(badgeId);
    if (badge == null) return newlyUnlocked;

    // 更新计数和进度
    final newCount = currentProgress.currentCount + increment;
    final newProgress = (newCount / badge.requiredCount).clamp(0.0, 1.0);

    // 检查是否达成
    final isUnlocked = newCount >= badge.requiredCount;

    _progressCache[badgeId] = UserBadgeProgress(
      userId: userId,
      badgeId: badgeId,
      progress: newProgress,
      currentCount: newCount,
      isUnlocked: isUnlocked,
      unlockedAt: isUnlocked ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );

    // 如果解锁了新徽章
    if (isUnlocked && !_unlockedBadges.contains(badgeId)) {
      _unlockedBadges.add(badgeId);
      newlyUnlocked.add(badge.copyWith(
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      ));
    }

    // 保存到本地
    await _saveProgressToLocal(userId);

    return newlyUnlocked;
  }

  /// 触发特定行为的徽章检查
  Future<List<AchievementBadge>> triggerAction(
    String userId,
    AchievementAction action, {
    Map<String, dynamic>? params,
  }) async {
    final newlyUnlocked = <AchievementBadge>[];

    switch (action) {
      case AchievementAction.postCreated:
        // 发布动态相关徽章
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'first_post', 1));
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'post_master', 1));

        // 检查是否是带图片的动态
        final hasImages = params?['hasImages'] as bool? ?? false;
        if (hasImages) {
          newlyUnlocked.addAll(await updateBadgeProgress(userId, 'photographer', 1));
        }

        // 检查是否使用了情绪标签
        final emotionTagId = params?['emotionTagId'] as String?;
        if (emotionTagId != null) {
          newlyUnlocked.addAll(await updateBadgeProgress(userId, 'emotion_expert', 1));
        }
        break;

      case AchievementAction.likeReceived:
        // 获得点赞（需要传入具体数量）
        final likeCount = params?['likeCount'] as int? ?? 1;
        if (likeCount >= 100) {
          newlyUnlocked.addAll(await updateBadgeProgress(userId, 'like_magnet', 1));
        }
        break;

      case AchievementAction.commentCreated:
        // 发表评论
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'social_butterfly', 1));
        break;

      case AchievementAction.giftSent:
        // 送礼物
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'generous_giver', 1));

        // 检查礼物价值
        final giftValue = params?['giftValue'] as double? ?? 0.0;
        if (giftValue > 0) {
          // 更新礼物大亨徽章（需要累计价值）
          final currentProgress = _progressCache['gift_tycoon'];
          final currentValue = currentProgress?.currentCount ?? 0;
          final newValue = (currentValue + giftValue).round();

          _progressCache['gift_tycoon'] = UserBadgeProgress(
            userId: userId,
            badgeId: 'gift_tycoon',
            progress: (newValue / 1000.0).clamp(0.0, 1.0),
            currentCount: newValue,
            isUnlocked: newValue >= 1000,
            unlockedAt: newValue >= 1000 ? DateTime.now() : null,
            updatedAt: DateTime.now(),
          );

          if (newValue >= 1000 && !_unlockedBadges.contains('gift_tycoon')) {
            _unlockedBadges.add('gift_tycoon');
            final badge = AchievementBadge.findById('gift_tycoon');
            if (badge != null) {
              newlyUnlocked.add(badge.copyWith(
                isUnlocked: true,
                unlockedAt: DateTime.now(),
              ));
            }
          }
        }
        break;

      case AchievementAction.loginDaily:
        // 每日登录
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'loyal_user', 1));
        break;

      case AchievementAction.earlyPost:
        // 早起发帖
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'early_bird', 1));
        break;

      case AchievementAction.latePost:
        // 夜猫子发帖
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'night_owl', 1));
        break;

      case AchievementAction.vipPurchased:
        // 购买VIP
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'vip_member', 1));
        break;

      case AchievementAction.topicCreated:
        // 创建话题（需要传入使用次数）
        final usageCount = params?['usageCount'] as int? ?? 0;
        if (usageCount >= 100) {
          newlyUnlocked.addAll(await updateBadgeProgress(userId, 'trendsetter', 1));
        }
        break;
    }

    // 保存更新后的数据
    await _saveProgressToLocal(userId);

    return newlyUnlocked;
  }

  /// 获取徽章统计信息
  BadgeStatistics getBadgeStatistics(String userId) {
    final allBadges = getUserBadges(userId);
    final unlockedCount = allBadges.where((badge) => badge.isUnlocked).length;
    final totalCount = allBadges.length;

    // 按稀有度分组统计
    final rarityStats = <BadgeRarity, int>{};
    for (final rarity in BadgeRarity.values) {
      rarityStats[rarity] = allBadges
          .where((badge) => badge.rarity == rarity && badge.isUnlocked)
          .length;
    }

    return BadgeStatistics(
      totalBadges: totalCount,
      unlockedBadges: unlockedCount,
      completionPercentage: totalCount > 0 ? (unlockedCount / totalCount) * 100 : 0.0,
      rarityStatistics: rarityStats,
    );
  }

  /// 清除用户数据（用于测试或重置）
  Future<void> clearUserData(String userId) async {
    _progressCache.clear();
    _unlockedBadges.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_userBadgesKey}_$userId');
    await prefs.remove('${_badgeProgressKey}_$userId');
  }
}

/// 成就行为枚举
enum AchievementAction {
  postCreated,      // 发布动态
  likeReceived,     // 获得点赞
  commentCreated,   // 发表评论
  giftSent,         // 送礼物
  loginDaily,       // 每日登录
  earlyPost,        // 早起发帖
  latePost,         // 夜猫子发帖
  vipPurchased,     // 购买VIP
  topicCreated,     // 创建话题
}

/// 徽章统计信息
class BadgeStatistics {
  final int totalBadges;
  final int unlockedBadges;
  final double completionPercentage;
  final Map<BadgeRarity, int> rarityStatistics;

  BadgeStatistics({
    required this.totalBadges,
    required this.unlockedBadges,
    required this.completionPercentage,
    required this.rarityStatistics,
  });
}