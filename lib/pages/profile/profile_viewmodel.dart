import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth_service.dart';
import '../../models/achievement_badge.dart';
import '../../models/user.dart';
import '../../services/achievement_service.dart';
import '../../services/commerce_service.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';

/// 个人主页状态与数据聚合层（解耦 [ProfilePage] 里的多路并发 IO 与缓存逻辑）。
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({AchievementService? achievementService})
      : _achievementService = achievementService ?? AchievementService();

  final AchievementService _achievementService;

  User? _user;
  bool _isLoading = true;
  bool _isLoadingDetails = false;
  bool _hasDetailsError = false;
  Object? _loadError;
  bool _isVip = false;
  int _postCount = 0;
  int _followingCount = 0;
  int _followerCount = 0;
  List<AchievementBadge> _userBadges = const [];
  Future<void>? _ongoingProfileLoad;
  bool _disposed = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoadingDetails => _isLoadingDetails;
  bool get hasDetailsError => _hasDetailsError;
  Object? get loadError => _loadError;
  bool get isVip => _isVip;
  int get postCount => _postCount;
  int get followingCount => _followingCount;
  int get followerCount => _followerCount;
  List<AchievementBadge> get userBadges => _userBadges;

  int get unlockedBadgeCount => _userBadges.where((b) => b.isUnlocked).length;

  BadgeStatistics? get badgeStatistics {
    final u = _user;
    if (u == null) return null;
    return _achievementService.getBadgeStatistics(u.id);
  }

  /// 加载当前登录用户主资料与聚合明细（支持防重入与强制刷新）。
  Future<void> loadUserInfo({
    bool forceRefresh = false,
    void Function(String userId)? onDetailsLoaded,
    void Function(Object error)? onRefreshErrorWithCachedUser,
  }) {
    if (_ongoingProfileLoad != null && !forceRefresh) {
      return _ongoingProfileLoad!;
    }
    final f = _loadUserInfoImpl(
      forceRefresh: forceRefresh,
      onDetailsLoaded: onDetailsLoaded,
      onRefreshErrorWithCachedUser: onRefreshErrorWithCachedUser,
    );
    _ongoingProfileLoad = f;
    f.whenComplete(() {
      if (identical(_ongoingProfileLoad, f)) _ongoingProfileLoad = null;
    });
    return f;
  }

  Future<void> _loadUserInfoImpl({
    required bool forceRefresh,
    void Function(String userId)? onDetailsLoaded,
    void Function(Object error)? onRefreshErrorWithCachedUser,
  }) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      _isLoading = false;
      _loadError = null;
      _notify();
      return;
    }

    final blockingLoad = _user == null;
    if (blockingLoad) {
      _isLoading = true;
    } else {
      _isLoadingDetails = true;
    }
    _loadError = null;
    _notify();

    try {
      final user = await AuthService.getUserInfo(forceRefresh: forceRefresh);
      if (_disposed) return;
      _user = user;
      _isLoading = false;
      _isLoadingDetails = true;
      _loadError = null;
      _notify();
      unawaited(
        loadProfileDetails(
          userId,
          onDetailsLoaded: onDetailsLoaded,
        ),
      );
    } catch (e) {
      if (_disposed) return;
      _isLoading = false;
      _isLoadingDetails = false;
      _loadError = e;
      _notify();
      if (_user != null) {
        onRefreshErrorWithCachedUser?.call(e);
      }
    }
  }

  /// 并发刷新徽章、VIP 状态、关注/粉丝/动态计数。
  Future<void> loadProfileDetails(
    String userId, {
    void Function(String userId)? onDetailsLoaded,
  }) async {
    if (!_isLoadingDetails) {
      _isLoadingDetails = true;
      _notify();
    }

    final badges = _loadDetail(
      () async {
        await _achievementService.initializeUserBadges(userId);
        return _achievementService.getUserBadges(userId);
      },
      const <AchievementBadge>[],
    );
    final vip = _loadDetail(
      () => CommerceService.getUserVipStatus(userId)
          .timeout(const Duration(seconds: 5)),
      <String, dynamic>{},
    );
    final following = _loadDetail(
      () => _getCount(
        () => UserService.getFollowings(userId, page: 1, pageSize: 1),
      ),
      0,
    );
    final followers = _loadDetail(
      () => _getCount(
        () => UserService.getFollowers(userId, page: 1, pageSize: 1),
      ),
      0,
    );
    final posts = _loadDetail(() => _getPostCount(userId), 0);

    final results =
        await Future.wait([badges, vip, following, followers, posts]);
    if (_disposed) return;

    final badgesResult = results[0] as _ProfileDetail<List<AchievementBadge>>;
    final vipResult = results[1] as _ProfileDetail<Map<String, dynamic>>;
    final followingResult = results[2] as _ProfileDetail<int>;
    final followersResult = results[3] as _ProfileDetail<int>;
    final postsResult = results[4] as _ProfileDetail<int>;

    if (vipResult.didLoad) {
      _isVip = vipResult.value['is_vip'] as bool? ?? false;
    }
    if (followingResult.didLoad) _followingCount = followingResult.value;
    if (followersResult.didLoad) _followerCount = followersResult.value;
    if (postsResult.didLoad) _postCount = postsResult.value;
    if (badgesResult.didLoad) _userBadges = badgesResult.value;
    _hasDetailsError = results.any((result) => !result.didLoad);
    _isLoadingDetails = false;
    _notify();
    onDetailsLoaded?.call(userId);
  }

  Future<_ProfileDetail<T>> _loadDetail<T>(
    Future<T> Function() loader,
    T fallback,
  ) async {
    try {
      return _ProfileDetail(value: await loader(), didLoad: true);
    } catch (_) {
      return _ProfileDetail(value: fallback, didLoad: false);
    }
  }

  Future<int> _getCount(Future<Map<String, dynamic>> Function() fn) async {
    final r = await fn().timeout(const Duration(seconds: 5));
    return r['total'] as int? ?? 0;
  }

  Future<int> _getPostCount(String userId) async {
    final viewer = AuthService.currentUser ?? '';
    final r = await PostService.getPosts(
      page: 1,
      pageSize: 1,
      viewerUserId: viewer.isEmpty ? null : viewer,
      authorUserId: userId,
    ).timeout(const Duration(seconds: 8));
    final total = r['total'];
    if (total is int) return total;
    if (total is num) return total.toInt();
    return 0;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _ProfileDetail<T> {
  const _ProfileDetail({required this.value, required this.didLoad});

  final T value;
  final bool didLoad;
}
