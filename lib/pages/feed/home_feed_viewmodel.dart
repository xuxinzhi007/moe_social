import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth_service.dart';
import '../../models/post.dart';
import '../../models/topic_tag.dart';
import '../../services/companion_service.dart';
import '../../services/like_state_manager.dart';
import '../../services/post_service.dart';
import '../../utils/moe_error_copy.dart';

/// 首页动态流模式（热门 / 最新 / 关注 / 话题）。
enum HomeFeedMode {
  hot,
  latest,
  following,
  topic,
}

extension HomeFeedModeX on HomeFeedMode {
  bool get supportsPagination =>
      this == HomeFeedMode.hot ||
      this == HomeFeedMode.latest ||
      this == HomeFeedMode.following ||
      this == HomeFeedMode.topic;

  String get apiFeedMode {
    switch (this) {
      case HomeFeedMode.hot:
        return 'hot';
      case HomeFeedMode.latest:
        return 'latest';
      case HomeFeedMode.following:
        return 'following';
      case HomeFeedMode.topic:
        return 'latest';
    }
  }
}

/// 首页 Feed 状态与加载逻辑（页面只负责 UI / 导航 / Scroll）。
class HomeFeedViewModel extends ChangeNotifier {
  HomeFeedViewModel({
    LikeStateManager? likeManager,
    CompanionService? companionService,
    this.pageSize = 10,
  })  : _likeManager = likeManager ?? LikeStateManager(),
        _companionService = companionService ?? CompanionService();

  final LikeStateManager _likeManager;
  final CompanionService _companionService;
  final int pageSize;

  List<Post> _allPosts = [];
  List<Post> _displayPosts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  Object? _feedError;
  String? _loadMoreErrorMessage;
  DateTime? _lastUpdatedAt;
  bool _isPrimaryRequestInFlight = false;
  bool _shouldReloadAfterCurrent = false;
  bool _queuedResetContent = false;
  bool _isLoadMoreRequestInFlight = false;
  CompanionSnapshotData? _companionSnapshot;
  CompanionCommunityIdentityData? _communityIdentity;
  HomeFeedMode _mode = HomeFeedMode.hot;
  TopicTag? _activeTopic;
  List<TopicTag> _availableTags = TopicTag.officialTags.take(12).toList();
  bool _disposed = false;

  LikeStateManager get likeManager => _likeManager;
  List<Post> get allPosts => _allPosts;
  List<Post> get displayPosts => _displayPosts;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  Object? get feedError => _feedError;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  CompanionSnapshotData? get companionSnapshot => _companionSnapshot;
  CompanionCommunityIdentityData? get communityIdentity => _communityIdentity;
  HomeFeedMode get mode => _mode;
  TopicTag? get activeTopic => _activeTopic;
  List<TopicTag> get availableTags => _availableTags;

  String sectionTitle() {
    if (_activeTopic != null) return '#${_activeTopic!.name}';
    switch (_mode) {
      case HomeFeedMode.hot:
        return '热门动态';
      case HomeFeedMode.latest:
        return '最新动态';
      case HomeFeedMode.following:
        return '关注动态';
      case HomeFeedMode.topic:
        return '分类动态';
    }
  }

  String feedRevealKey(String postId) =>
      '${_mode.name}_${_activeTopic?.id ?? 'all'}_$postId';

  Future<void> bootstrap() async {
    await Future.wait([
      fetchPosts(resetContent: true),
      loadCompanionPresence(),
    ]);
  }

  Future<void> loadCompanionPresence() async {
    try {
      final snapshot = await _companionService.getSnapshot();
      CompanionCommunityIdentityData? identity;
      if (snapshot.profile.agentId.trim().isNotEmpty) {
        try {
          identity = await _companionService.getCommunityIdentity();
        } catch (_) {}
      }
      if (_disposed) return;
      _companionSnapshot = snapshot;
      _communityIdentity = identity;
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _companionSnapshot = null;
      _communityIdentity = null;
      notifyListeners();
    }
  }

  /// Companion WS 推送：刷新首页轻卡问候/心情。
  void applyLiveCompanionPresence({
    String? greeting,
    String? moodThought,
    String? activityLabel,
  }) {
    final snap = _companionSnapshot;
    if (_disposed || snap == null) return;
    final nextState = snap.state.copyWith(
      greeting: (greeting != null && greeting.trim().isNotEmpty)
          ? greeting.trim()
          : null,
      moodThought: (moodThought != null && moodThought.trim().isNotEmpty)
          ? moodThought.trim()
          : null,
      activityLabel: (activityLabel != null && activityLabel.trim().isNotEmpty)
          ? activityLabel.trim()
          : null,
    );
    if (nextState.greeting == snap.state.greeting &&
        nextState.moodThought == snap.state.moodThought &&
        nextState.activityLabel == snap.state.activityLabel) {
      return;
    }
    _companionSnapshot = CompanionSnapshotData(
      profile: snap.profile,
      state: nextState,
    );
    notifyListeners();
  }

  void setMode(HomeFeedMode mode, {bool clearTopic = true}) {
    if (_mode == mode && (!clearTopic || _activeTopic == null)) return;
    _mode = mode;
    if (clearTopic) _activeTopic = null;
    notifyListeners();
    unawaited(fetchPosts(resetContent: true));
  }

  void selectTopic(TopicTag? tag, {required HomeFeedMode fallbackMode}) {
    if (tag?.id == _activeTopic?.id) {
      _activeTopic = null;
      _mode = fallbackMode;
    } else {
      _activeTopic = tag;
      if (tag != null) _mode = HomeFeedMode.topic;
    }
    notifyListeners();
    unawaited(fetchPosts(resetContent: true));
  }

  void insertCreatedPost(Post post) {
    if (_activeTopic != null) {
      final matchesTopic = post.topicTags.any((t) => t.id == _activeTopic!.id);
      if (!matchesTopic) return;
    }
    if (_mode == HomeFeedMode.following) return;
    if (_allPosts.any((p) => p.id == post.id)) return;
    _allPosts = [post, ..._allPosts];
    _displayPosts = List<Post>.from(_allPosts);
    _lastUpdatedAt = DateTime.now();
    _refreshAvailableTags(notify: false);
    notifyListeners();
  }

  Future<void> fetchPosts({bool resetContent = true}) async {
    if (_isPrimaryRequestInFlight) {
      _shouldReloadAfterCurrent = true;
      _queuedResetContent = _queuedResetContent || resetContent;
      return;
    }
    _isPrimaryRequestInFlight = true;
    final hasExistingPosts = _displayPosts.isNotEmpty;
    _feedError = null;
    _loadMoreErrorMessage = null;
    _hasMore = true;
    _currentPage = 1;
    if (!hasExistingPosts) {
      _isLoading = true;
      _isRefreshing = false;
    } else {
      _isRefreshing = true;
      _isLoading = false;
    }
    notifyListeners();

    try {
      final result = await _fetchPostsForMode(page: 1);
      if (_disposed) return;
      _allPosts = result.posts;
      _displayPosts = List<Post>.from(result.posts);
      _currentPage = 1;
      _hasMore =
          _mode.supportsPagination ? result.posts.length < result.total : false;
      _feedError = null;
      _lastUpdatedAt = DateTime.now();
      _refreshAvailableTags(notify: false);
    } catch (e) {
      if (_disposed) return;
      _feedError = e;
      _hasMore = false;
      rethrow;
    } finally {
      final shouldReload = _shouldReloadAfterCurrent;
      final queuedReset = _queuedResetContent;
      _isPrimaryRequestInFlight = false;
      _shouldReloadAfterCurrent = false;
      _queuedResetContent = false;
      if (!_disposed) {
        _isLoading = false;
        _isRefreshing = false;
        notifyListeners();
      }
      if (shouldReload) {
        unawaited(fetchPosts(resetContent: queuedReset));
      }
    }
  }

  Future<void> loadMorePosts() async {
    if (_isLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        _isLoadMoreRequestInFlight ||
        !_hasMore) {
      return;
    }
    _isLoadMoreRequestInFlight = true;
    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    notifyListeners();
    try {
      final nextPage = _currentPage + 1;
      final result = await _fetchPostsForMode(page: nextPage);
      if (_disposed) return;
      if (result.posts.isEmpty) {
        _hasMore = false;
        _isLoadingMore = false;
        notifyListeners();
        return;
      }
      _allPosts.addAll(result.posts);
      _displayPosts = List<Post>.from(_allPosts);
      _currentPage = nextPage;
      _hasMore =
          _mode.supportsPagination ? _allPosts.length < result.total : false;
      _loadMoreErrorMessage = null;
      _lastUpdatedAt = DateTime.now();
      _refreshAvailableTags(notify: false);
    } catch (e) {
      if (_disposed) return;
      _loadMoreErrorMessage =
          MoeErrorCopy.resolve(e, scene: MoeErrorScene.feed).subtitle;
      rethrow;
    } finally {
      _isLoadMoreRequestInFlight = false;
      if (!_disposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void syncLikeSnapshot({
    required String postId,
    required bool isLiked,
    required int likeCount,
  }) {
    final allIndex = _allPosts.indexWhere((p) => p.id == postId);
    if (allIndex != -1) {
      _allPosts[allIndex] = _allPosts[allIndex].copyWith(
        isLiked: isLiked,
        likes: likeCount,
      );
    }
    final displayIndex = _displayPosts.indexWhere((p) => p.id == postId);
    if (displayIndex != -1) {
      _displayPosts[displayIndex] = _displayPosts[displayIndex].copyWith(
        isLiked: isLiked,
        likes: likeCount,
      );
    }
  }

  void toggleLikeLocal(String postId) {
    final isLiked = _likeManager.getStatusNotifier(postId).value;
    final likeCount = _likeManager.getCountNotifier(postId).value;
    syncLikeSnapshot(postId: postId, isLiked: isLiked, likeCount: likeCount);
  }

  void updatePostComments(String postId, int comments) {
    final allIndex = _allPosts.indexWhere((p) => p.id == postId);
    if (allIndex != -1) {
      _allPosts[allIndex] = _allPosts[allIndex].copyWith(comments: comments);
    }
    final displayIndex = _displayPosts.indexWhere((p) => p.id == postId);
    if (displayIndex != -1) {
      _displayPosts[displayIndex] =
          _displayPosts[displayIndex].copyWith(comments: comments);
    }
    notifyListeners();
  }

  void mergeUpdatedPost(Post updated, Post existing) {
    final merged = updated.copyWith(
      likes: existing.likes,
      comments: existing.comments,
      isLiked: existing.isLiked,
      userName:
          updated.userName.isNotEmpty ? updated.userName : existing.userName,
      userAvatar: updated.userAvatar.isNotEmpty
          ? updated.userAvatar
          : existing.userAvatar,
    );
    final allIndex = _allPosts.indexWhere((p) => p.id == updated.id);
    if (allIndex != -1) _allPosts[allIndex] = merged;
    final displayIndex = _displayPosts.indexWhere((p) => p.id == updated.id);
    if (displayIndex != -1) _displayPosts[displayIndex] = merged;
    notifyListeners();
  }

  void removePost(String postId) {
    _allPosts.removeWhere((p) => p.id == postId);
    _displayPosts.removeWhere((p) => p.id == postId);
    _likeManager.evictPost(postId);
    notifyListeners();
  }

  Future<_PostPageResult> _fetchPostsForMode({required int page}) async {
    final result = await PostService.getPosts(
      page: page,
      pageSize: pageSize,
      feedMode: _mode.apiFeedMode,
      topicTagId: _activeTopic?.id,
      viewerUserId: AuthService.isLoggedIn ? AuthService.currentUser : null,
    );
    final posts = result['posts'] as List<Post>;
    final totalRaw = result['total'];
    final total =
        totalRaw is int ? totalRaw : (totalRaw is num ? totalRaw.toInt() : 0);
    return _PostPageResult(posts: posts, total: total);
  }

  void _refreshAvailableTags({bool notify = true}) {
    final byId = <String, TopicTag>{};
    for (final tag in TopicTag.officialTags) {
      byId[tag.id] = tag;
    }
    for (final p in _allPosts) {
      for (final tag in p.topicTags) {
        byId[tag.id] = tag;
      }
    }
    final tags = byId.values.toList()
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    final nextTags = tags.take(15).toList();
    if (_isSameTagSequence(_availableTags, nextTags)) return;
    _availableTags = nextTags;
    if (notify) notifyListeners();
  }

  bool _isSameTagSequence(List<TopicTag> a, List<TopicTag> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _PostPageResult {
  const _PostPageResult({required this.posts, required this.total});
  final List<Post> posts;
  final int total;
}
