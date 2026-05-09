import 'package:flutter/foundation.dart';

/// 全局点赞状态管理器
/// 用于跨页面实时同步点赞状态和数量
class LikeStateManager {
  // 单例模式
  static final LikeStateManager _instance = LikeStateManager._internal();
  factory LikeStateManager() => _instance;
  LikeStateManager._internal();

  // 存储点赞状态: postId -> isLiked
  final Map<String, ValueNotifier<bool>> _likeStatus = {};
  // 存储点赞数量: postId -> count
  final Map<String, ValueNotifier<int>> _likeCounts = {};
  final Map<String, int> _postTouchTicks = {};

  // 存储评论点赞状态: commentId -> isLiked
  final Map<String, ValueNotifier<bool>> _commentLikeStatus = {};
  // 存储评论点赞数量: commentId -> count
  final Map<String, ValueNotifier<int>> _commentLikeCounts = {};
  final Map<String, int> _commentTouchTicks = {};

  int _tick = 0;

  static const int _defaultPostCacheLimit = 800;
  static const int _defaultCommentCacheLimit = 1600;

  int _nextTick() => ++_tick;

  void _touchPost(String postId) {
    if (postId.isEmpty) return;
    _postTouchTicks[postId] = _nextTick();
  }

  void _touchComment(String commentId) {
    if (commentId.isEmpty) return;
    _commentTouchTicks[commentId] = _nextTick();
  }

  // 获取点赞状态的监听器
  ValueNotifier<bool> getStatusNotifier(
    String postId, {
    bool initialValue = false,
  }) {
    // 强制使用非空 ID，防止空 ID 导致的全局联动
    if (postId.isEmpty) {
      debugPrint(
        'LikeStateManager: Warning! getStatusNotifier called with empty postId',
      );
      return ValueNotifier<bool>(initialValue);
    }
    if (!_likeStatus.containsKey(postId)) {
      _likeStatus[postId] = ValueNotifier<bool>(initialValue);
    }
    _touchPost(postId);
    return _likeStatus[postId]!;
  }

  // 获取点赞数量的监听器
  ValueNotifier<int> getCountNotifier(String postId, {int initialValue = 0}) {
    if (postId.isEmpty) {
      debugPrint(
        'LikeStateManager: Warning! getCountNotifier called with empty postId',
      );
      return ValueNotifier<int>(initialValue);
    }
    if (!_likeCounts.containsKey(postId)) {
      _likeCounts[postId] = ValueNotifier<int>(initialValue);
    }
    _touchPost(postId);
    return _likeCounts[postId]!;
  }

  // 初始化或更新状态（例如从API获取列表后调用）
  void syncState(String postId, bool isLiked, int count) {
    if (postId.isEmpty) return;

    if (!_likeStatus.containsKey(postId)) {
      _likeStatus[postId] = ValueNotifier<bool>(isLiked);
    } else if (_likeStatus[postId]!.value != isLiked) {
      _likeStatus[postId]!.value = isLiked;
    }

    if (!_likeCounts.containsKey(postId)) {
      _likeCounts[postId] = ValueNotifier<int>(count);
    } else if (_likeCounts[postId]!.value != count) {
      _likeCounts[postId]!.value = count;
    }
    _touchPost(postId);
  }

  // 强制更新状态（例如 API 明确返回了最新详情）
  void updateState(String postId, bool isLiked, int count) {
    if (_likeStatus.containsKey(postId)) {
      _likeStatus[postId]!.value = isLiked;
    } else {
      _likeStatus[postId] = ValueNotifier<bool>(isLiked);
    }

    if (_likeCounts.containsKey(postId)) {
      _likeCounts[postId]!.value = count;
    } else {
      _likeCounts[postId] = ValueNotifier<int>(count);
    }
    _touchPost(postId);
  }

  // 切换点赞状态
  void toggleLike(String postId) {
    debugPrint('LikeStateManager: toggling POST like for $postId');
    if (_likeStatus.containsKey(postId)) {
      final current = _likeStatus[postId]!.value;
      _likeStatus[postId]!.value = !current;

      // 同时更新数量
      if (_likeCounts.containsKey(postId)) {
        final currentCount = _likeCounts[postId]!.value;
        _likeCounts[postId]!.value = currentCount + (!current ? 1 : -1);
      }
    }
    _touchPost(postId);
  }

  // 仅设置点赞状态（回滚用）
  void setLike(String postId, bool isLiked) {
    if (_likeStatus.containsKey(postId)) {
      _likeStatus[postId]!.value = isLiked;
    }
    _touchPost(postId);
  }

  // 仅设置数量（回滚用）
  void setCount(String postId, int count) {
    if (_likeCounts.containsKey(postId)) {
      _likeCounts[postId]!.value = count;
    }
    _touchPost(postId);
  }

  // 获取评论点赞状态的监听器
  ValueNotifier<bool> getCommentStatusNotifier(
    String commentId, {
    bool initialValue = false,
  }) {
    if (commentId.isEmpty) {
      debugPrint(
        'LikeStateManager: Warning! getCommentStatusNotifier called with empty commentId',
      );
      return ValueNotifier<bool>(initialValue);
    }
    if (!_commentLikeStatus.containsKey(commentId)) {
      _commentLikeStatus[commentId] = ValueNotifier<bool>(initialValue);
    }
    _touchComment(commentId);
    return _commentLikeStatus[commentId]!;
  }

  // 获取评论点赞数量的监听器
  ValueNotifier<int> getCommentCountNotifier(
    String commentId, {
    int initialValue = 0,
  }) {
    if (commentId.isEmpty) {
      debugPrint(
        'LikeStateManager: Warning! getCommentCountNotifier called with empty commentId',
      );
      return ValueNotifier<int>(initialValue);
    }
    if (!_commentLikeCounts.containsKey(commentId)) {
      _commentLikeCounts[commentId] = ValueNotifier<int>(initialValue);
    }
    _touchComment(commentId);
    return _commentLikeCounts[commentId]!;
  }

  // 同步评论状态
  void syncCommentState(String commentId, bool isLiked, int count) {
    if (commentId.isEmpty) return;

    if (!_commentLikeStatus.containsKey(commentId)) {
      _commentLikeStatus[commentId] = ValueNotifier<bool>(isLiked);
    } else if (_commentLikeStatus[commentId]!.value != isLiked) {
      _commentLikeStatus[commentId]!.value = isLiked;
    }

    if (!_commentLikeCounts.containsKey(commentId)) {
      _commentLikeCounts[commentId] = ValueNotifier<int>(count);
    } else if (_commentLikeCounts[commentId]!.value != count) {
      _commentLikeCounts[commentId]!.value = count;
    }
    _touchComment(commentId);
  }

  // 强制更新评论状态
  void updateCommentState(String commentId, bool isLiked, int count) {
    if (_commentLikeStatus.containsKey(commentId)) {
      _commentLikeStatus[commentId]!.value = isLiked;
    } else {
      _commentLikeStatus[commentId] = ValueNotifier<bool>(isLiked);
    }

    if (_commentLikeCounts.containsKey(commentId)) {
      _commentLikeCounts[commentId]!.value = count;
    } else {
      _commentLikeCounts[commentId] = ValueNotifier<int>(count);
    }
    _touchComment(commentId);
  }

  // 切换评论点赞状态
  void toggleCommentLike(String commentId) {
    debugPrint('LikeStateManager: toggling COMMENT like for $commentId');
    if (_commentLikeStatus.containsKey(commentId)) {
      final current = _commentLikeStatus[commentId]!.value;
      _commentLikeStatus[commentId]!.value = !current;

      if (_commentLikeCounts.containsKey(commentId)) {
        final currentCount = _commentLikeCounts[commentId]!.value;
        _commentLikeCounts[commentId]!.value = currentCount + (!current ? 1 : -1);
      }
    }
    _touchComment(commentId);
  }

  // 仅设置评论点赞状态（回滚用）
  void setCommentLike(String commentId, bool isLiked) {
    if (_commentLikeStatus.containsKey(commentId)) {
      _commentLikeStatus[commentId]!.value = isLiked;
    }
    _touchComment(commentId);
  }

  // 仅设置评论数量（回滚用）
  void setCommentCount(String commentId, int count) {
    if (_commentLikeCounts.containsKey(commentId)) {
      _commentLikeCounts[commentId]!.value = count;
    }
    _touchComment(commentId);
  }

  /// 驱逐单个帖子点赞缓存（状态 + 计数 + 访问时间）
  void evictPost(String postId) {
    _likeStatus.remove(postId)?.dispose();
    _likeCounts.remove(postId)?.dispose();
    _postTouchTicks.remove(postId);
  }

  /// 批量驱逐帖子点赞缓存
  void evictPosts(Iterable<String> postIds) {
    for (final id in postIds) {
      evictPost(id);
    }
  }

  /// 按最大条目数裁剪帖子点赞缓存（LRU）
  void trimPostCaches({int maxEntries = _defaultPostCacheLimit}) {
    if (maxEntries <= 0 || _likeStatus.length <= maxEntries) return;
    final keys = _postTouchTicks.keys.toList()
      ..sort((a, b) => (_postTouchTicks[a] ?? 0).compareTo(_postTouchTicks[b] ?? 0));
    final overflow = _likeStatus.length - maxEntries;
    for (var i = 0; i < overflow && i < keys.length; i++) {
      evictPost(keys[i]);
    }
  }

  /// 驱逐单条评论点赞缓存（状态 + 计数 + 访问时间）
  void evictComment(String commentId) {
    _commentLikeStatus.remove(commentId)?.dispose();
    _commentLikeCounts.remove(commentId)?.dispose();
    _commentTouchTicks.remove(commentId);
  }

  /// 批量驱逐评论点赞缓存
  void evictComments(Iterable<String> commentIds) {
    for (final id in commentIds) {
      evictComment(id);
    }
  }

  /// 按最大条目数裁剪评论点赞缓存（LRU）
  void trimCommentCaches({int maxEntries = _defaultCommentCacheLimit}) {
    if (maxEntries <= 0 || _commentLikeStatus.length <= maxEntries) return;
    final keys = _commentTouchTicks.keys.toList()
      ..sort((a, b) => (_commentTouchTicks[a] ?? 0).compareTo(_commentTouchTicks[b] ?? 0));
    final overflow = _commentLikeStatus.length - maxEntries;
    for (var i = 0; i < overflow && i < keys.length; i++) {
      evictComment(keys[i]);
    }
  }

  /// 同时裁剪帖子/评论缓存
  void trimCaches({
    int maxPostEntries = _defaultPostCacheLimit,
    int maxCommentEntries = _defaultCommentCacheLimit,
  }) {
    trimPostCaches(maxEntries: maxPostEntries);
    trimCommentCaches(maxEntries: maxCommentEntries);
  }

  /// 调试用：返回当前缓存条目数
  Map<String, int> debugStats() {
    return {
      'postStatus': _likeStatus.length,
      'postCount': _likeCounts.length,
      'commentStatus': _commentLikeStatus.length,
      'commentCount': _commentLikeCounts.length,
    };
  }
}
