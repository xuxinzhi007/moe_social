import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/achievement_badge.dart';
import 'api_service.dart';

/// 成就系统服务（进度以服务端为准；礼物/部分话题等仍走本地）
class AchievementService {
  static const String _userBadgesKey = 'user_badges';
  static const String _badgeProgressKey = 'badge_progress';

  /// 无服务端记录的徽章（仍用本地 triggerAction）
  static const Set<String> clientOnlyBadgeIds = {
    'generous_giver',
    'gift_tycoon',
    'emotion_expert',
    'trendsetter',
    'creative_genius',
  };

  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  Map<String, UserBadgeProgress> _progressCache = {};
  List<String> _unlockedBadges = [];

  /// 加载本地缓存、补全默认项、再从服务端同步（发帖/评论/VIP 等由服务端更新）
  Future<void> initializeUserBadges(String userId) async {
    try {
      await _loadUserBadgesFromLocal(userId);
      await _initializeDefaultProgress(userId);
      await syncFromServer(userId);
    } catch (e) {
      print('初始化用户徽章数据失败: $e');
    }
  }

  /// 用 GET /achievements 覆盖非 client-only 徽章的进度与解锁状态
  Future<void> syncFromServer(String userId) async {
    try {
      final rows = await ApiService.getUserAchievements(userId);
      final byId = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final id = row['badge_id']?.toString() ?? '';
        if (id.isNotEmpty) byId[id] = row;
      }
      final now = DateTime.now();
      for (final badge in AchievementBadge.defaultBadges) {
        if (clientOnlyBadgeIds.contains(badge.id)) continue;
        final row = byId[badge.id];
        final count =
            row != null ? ((row['current_count'] as num?)?.toInt() ?? 0) : 0;
        final unlocked = row != null && row['is_unlocked'] == true;
        DateTime? ua;
        final uas = row?['unlocked_at']?.toString();
        if (uas != null && uas.isNotEmpty) {
          try {
            ua = DateTime.parse(uas);
          } catch (_) {}
        }
        final prog = (count / badge.requiredCount).clamp(0.0, 1.0);
        _progressCache[badge.id] = UserBadgeProgress(
          userId: userId,
          badgeId: badge.id,
          progress: prog,
          currentCount: count,
          isUnlocked: unlocked,
          unlockedAt: ua,
          updatedAt: now,
        );
        if (unlocked) {
          if (!_unlockedBadges.contains(badge.id)) {
            _unlockedBadges.add(badge.id);
          }
        } else {
          _unlockedBadges.remove(badge.id);
        }
      }
      await _saveProgressToLocal(userId);
    } catch (e) {
      print('同步成就失败: $e');
    }
  }

  /// 接口返回的本批新解锁 id（与 sync 二选一或叠加均可）
  Future<void> applyServerNewUnlocks(String userId, List<String> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now();
    for (final id in ids) {
      final def = AchievementBadge.findById(id);
      if (def == null) continue;
      if (!clientOnlyBadgeIds.contains(id)) {
        if (!_unlockedBadges.contains(id)) _unlockedBadges.add(id);
        _progressCache[id] = UserBadgeProgress(
          userId: userId,
          badgeId: id,
          progress: 1.0,
          currentCount: def.requiredCount,
          isUnlocked: true,
          unlockedAt: now,
          updatedAt: now,
        );
      }
    }
    await _saveProgressToLocal(userId);
  }

  Future<void> _loadUserBadgesFromLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    final unlockedJson = prefs.getString('${_userBadgesKey}_$userId');
    if (unlockedJson != null) {
      final List<dynamic> unlockedList = json.decode(unlockedJson);
      _unlockedBadges = unlockedList.cast<String>();
    }

    final progressJson = prefs.getString('${_badgeProgressKey}_$userId');
    if (progressJson != null) {
      final Map<String, dynamic> progressMap = json.decode(progressJson);
      _progressCache = progressMap.map(
        (key, value) => MapEntry(key, UserBadgeProgress.fromJson(value)),
      );
    }
  }

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

  Future<void> _saveProgressToLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      '${_userBadgesKey}_$userId',
      json.encode(_unlockedBadges),
    );

    final progressMap = _progressCache.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await prefs.setString(
      '${_badgeProgressKey}_$userId',
      json.encode(progressMap),
    );
  }

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

  List<AchievementBadge> getUnlockedBadges(String userId) {
    return getUserBadges(userId).where((badge) => badge.isUnlocked).toList();
  }

  List<AchievementBadge> getRecommendedBadges(String userId) {
    return getUserBadges(userId)
        .where((badge) => !badge.isUnlocked && badge.progress > 0.3)
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
  }

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

    final newCount = currentProgress.currentCount + increment;
    final newProgress = (newCount / badge.requiredCount).clamp(0.0, 1.0);

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

    if (isUnlocked && !_unlockedBadges.contains(badgeId)) {
      _unlockedBadges.add(badgeId);
      newlyUnlocked.add(badge.copyWith(
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      ));
    }

    await _saveProgressToLocal(userId);

    return newlyUnlocked;
  }

  /// 仅 [clientOnlyBadgeIds] 与未上云逻辑仍走本地；其余已由服务端处理
  Future<List<AchievementBadge>> triggerAction(
    String userId,
    AchievementAction action, {
    Map<String, dynamic>? params,
  }) async {
    final newlyUnlocked = <AchievementBadge>[];

    switch (action) {
      case AchievementAction.giftSent:
        newlyUnlocked.addAll(await updateBadgeProgress(userId, 'generous_giver', 1));

        final giftValue = params?['giftValue'] as double? ?? 0.0;
        if (giftValue > 0) {
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

      case AchievementAction.topicCreated:
        final usageCount = params?['usageCount'] as int? ?? 0;
        if (usageCount >= 100) {
          newlyUnlocked.addAll(await updateBadgeProgress(userId, 'trendsetter', 1));
        }
        break;

      case AchievementAction.postCreated:
      case AchievementAction.likeReceived:
      case AchievementAction.commentCreated:
      case AchievementAction.loginDaily:
      case AchievementAction.earlyPost:
      case AchievementAction.latePost:
      case AchievementAction.vipPurchased:
        break;
    }

    await _saveProgressToLocal(userId);

    return newlyUnlocked;
  }

  BadgeStatistics getBadgeStatistics(String userId) {
    final allBadges = getUserBadges(userId);
    final unlockedCount = allBadges.where((badge) => badge.isUnlocked).length;
    final totalCount = allBadges.length;

    final rarityStats = <BadgeRarity, int>{};
    for (final rarity in BadgeRarity.values) {
      rarityStats[rarity] = allBadges
          .where((badge) => badge.rarity == rarity && badge.isUnlocked)
          .length;
    }

    return BadgeStatistics(
      totalBadges: totalCount,
      unlockedBadges: unlockedCount,
      completionPercentage:
          totalCount > 0 ? (unlockedCount / totalCount) * 100 : 0.0,
      rarityStatistics: rarityStats,
    );
  }

  Future<void> clearUserData(String userId) async {
    _progressCache.clear();
    _unlockedBadges.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_userBadgesKey}_$userId');
    await prefs.remove('${_badgeProgressKey}_$userId');
  }
}

enum AchievementAction {
  postCreated,
  likeReceived,
  commentCreated,
  giftSent,
  loginDaily,
  earlyPost,
  latePost,
  vipPurchased,
  topicCreated,
}

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
