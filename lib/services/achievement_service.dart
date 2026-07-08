import 'package:flutter/foundation.dart';

import '../models/achievement_badge.dart';
import '../models/achievement_unlock.dart';
import 'api_service.dart';

/// 成就系统服务（服务端为唯一数据源）。
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  String? _cachedUserId;
  List<AchievementBadge> _badges = [];
  BadgeStatistics? _summary;

  /// 登录后初始化：确保欢迎成就并拉取全量列表。
  Future<void> initializeUserBadges(String userId) async {
    if (userId.isEmpty) return;
    try {
      await ApiService.ensureUserAchievements(userId);
      await refreshFromServer(userId);
    } catch (e) {
      debugPrint('初始化成就失败: $e');
    }
  }

  /// 从服务端刷新成就列表与概览。
  Future<void> refreshFromServer(String userId) async {
    final badges = await ApiService.getUserAchievements(userId);
    final summary = await ApiService.getUserAchievementSummary(userId);
    _cachedUserId = userId;
    _badges = badges;
    _summary = summary;
  }

  List<AchievementBadge> getUserBadges(String userId) {
    if (_cachedUserId != userId || _badges.isEmpty) {
      return AchievementBadge.defaultBadges;
    }
    return List.unmodifiable(_badges);
  }

  List<AchievementBadge> getUnlockedBadges(String userId) {
    return getUserBadges(userId).where((b) => b.isUnlocked).toList();
  }

  List<AchievementBadge> getRecommendedBadges(String userId) {
    return getUserBadges(userId)
        .where((b) => !b.isUnlocked && b.progress > 0.3)
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
  }

  BadgeStatistics getBadgeStatistics(String userId) {
    if (_summary != null && _cachedUserId == userId) {
      return _summary!;
    }
    final all = getUserBadges(userId);
    final unlocked = all.where((b) => b.isUnlocked).length;
    final total = all.length;
    final rarityStats = <BadgeRarity, int>{};
    for (final rarity in BadgeRarity.values) {
      rarityStats[rarity] =
          all.where((b) => b.rarity == rarity && b.isUnlocked).length;
    }
    return BadgeStatistics(
      totalBadges: total,
      unlockedBadges: unlocked,
      completionPercentage: total > 0 ? unlocked / total * 100 : 0,
      rarityStatistics: rarityStats,
    );
  }

  /// 业务接口返回解锁列表后刷新本地缓存。
  Future<List<AchievementBadge>> applyServerUnlocks(
    String userId,
    List<AchievementUnlock> unlocks,
  ) async {
    if (userId.isEmpty || unlocks.isEmpty) return [];
    await refreshFromServer(userId);
    return unlocks.map((u) => u.toDisplayBadge()).toList();
  }

  Future<void> clearUserData(String userId) async {
    if (_cachedUserId == userId) {
      _cachedUserId = null;
      _badges = [];
      _summary = null;
    }
  }
}
