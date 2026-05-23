import 'achievement_badge.dart';
import 'checkin_data.dart';
import 'post.dart';

/// 服务端返回的成就解锁通知。
class AchievementUnlock {
  final String badgeId;
  final String name;
  final int expGranted;
  final bool levelUp;
  final int newLevel;

  const AchievementUnlock({
    required this.badgeId,
    required this.name,
    this.expGranted = 0,
    this.levelUp = false,
    this.newLevel = 0,
  });

  factory AchievementUnlock.fromJson(Map<String, dynamic> json) {
    return AchievementUnlock(
      badgeId: json['badge_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      expGranted: (json['exp_granted'] as num?)?.toInt() ?? 0,
      levelUp: json['level_up'] as bool? ?? false,
      newLevel: (json['new_level'] as num?)?.toInt() ?? 0,
    );
  }

  /// 转为展示用徽章（合并本地图标/配色元数据）。
  AchievementBadge toDisplayBadge() {
    final template = AchievementBadge.findById(badgeId);
    return (template ?? AchievementBadge.defaultBadges.first).copyWith(
      id: badgeId,
      name: name.isNotEmpty ? name : (template?.name ?? badgeId),
      isUnlocked: true,
      unlockedAt: DateTime.now(),
      progress: 1.0,
    );
  }

  static List<AchievementUnlock> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => AchievementUnlock.fromJson(Map<String, dynamic>.from(e)))
        .where((u) => u.badgeId.isNotEmpty)
        .toList();
  }
}

/// 发帖接口返回（含成就解锁）。
class PostCreateResult {
  final Post post;
  final List<AchievementUnlock> newAchievements;

  const PostCreateResult({
    required this.post,
    this.newAchievements = const [],
  });
}

/// 签到接口返回（含成就解锁）。
class CheckInResult {
  final CheckInData data;
  final List<AchievementUnlock> newAchievements;

  const CheckInResult({
    required this.data,
    this.newAchievements = const [],
  });
}
