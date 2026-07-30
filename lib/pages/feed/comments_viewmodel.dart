import 'package:flutter/foundation.dart';

import '../../auth_service.dart';
import '../../models/achievement_unlock.dart';
import '../../models/comment.dart';
import '../../services/companion_service.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../utils/moe_error_copy.dart';

/// 评论页状态：列表加载、乐观发表评论、回复上下文。
class CommentsViewModel extends ChangeNotifier {
  CommentsViewModel({
    required this.postId,
    this.communityIdentity,
  });

  final String postId;
  final CompanionCommunityIdentityData? communityIdentity;

  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  Object? _loadError;
  String? userName;
  String? userAvatar;
  String? authorUserId;
  String? replyParentId;
  String? replyToUserName;
  bool _disposed = false;

  List<Comment> get comments => _comments;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  Object? get loadError => _loadError;
  int get commentCount => _comments.length;
  bool get isEmpty => !_isLoading && _loadError == null && _comments.isEmpty;

  Future<void> bootstrap() async {
    await Future.wait([loadUserInfo(), fetchComments()]);
  }

  Future<void> loadUserInfo() async {
    final identity = communityIdentity;
    if (identity != null && identity.isValid) {
      authorUserId = identity.userId;
      userName = identity.userName.isNotEmpty ? identity.userName : 'AI 伙伴';
      userAvatar = identity.userAvatar.isNotEmpty ? identity.userAvatar : null;
      _notify();
      return;
    }

    final userId = AuthService.currentUser;
    if (userId == null) return;
    try {
      final user = await UserService.getUserInfo(userId);
      if (_disposed) return;
      authorUserId = userId;
      userName = user.username;
      userAvatar = user.avatar.isNotEmpty ? user.avatar : null;
      _notify();
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    }
  }

  Future<void> fetchComments() async {
    _isLoading = true;
    _loadError = null;
    _notify();
    try {
      final comments = await PostService.getComments(postId);
      if (_disposed) return;
      _comments = comments;
      _loadError = null;
    } catch (e) {
      if (_disposed) return;
      _loadError = e;
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void beginReply({required String parentId, required String toUserName}) {
    replyParentId = parentId;
    replyToUserName = toUserName;
    _notify();
  }

  void cancelReply() {
    replyParentId = null;
    replyToUserName = null;
    _notify();
  }

  /// 乐观插入；成功返回解锁列表；失败回滚并抛错由页面 Toast。
  Future<List<AchievementUnlock>> submitComment(String rawContent) async {
    final content = rawContent.trim();
    if (content.isEmpty) {
      throw StateError('请输入评论内容');
    }
    final userId = authorUserId ?? AuthService.currentUser;
    if (userId == null) {
      throw StateError('请先登录');
    }

    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = Comment(
      id: localId,
      postId: postId,
      userId: userId,
      userName: userName ?? '用户',
      userAvatar: userAvatar ?? '',
      content: content,
      likes: 0,
      isLiked: false,
      createdAt: DateTime.now(),
      parentId: replyParentId ?? '',
      replyToUserName: replyToUserName ?? '',
    );

    _isSubmitting = true;
    _comments = [optimistic, ..._comments];
    final savedParent = replyParentId;
    final savedReplyName = replyToUserName;
    replyParentId = null;
    replyToUserName = null;
    _notify();

    try {
      final result = await PostService.addCommentWithUnlocks(optimistic);
      if (_disposed) return result.newAchievements;
      try {
        final fresh = await PostService.getComments(postId);
        if (!_disposed) {
          _comments = fresh;
          _notify();
        }
      } catch (_) {
        // 乐观项已在；对齐失败不打断成功路径
      }
      return result.newAchievements;
    } catch (e) {
      if (!_disposed) {
        _comments = _comments.where((c) => c.id != localId).toList();
        replyParentId = savedParent;
        replyToUserName = savedReplyName;
        _notify();
      }
      throw StateError(MoeErrorCopy.toast(e, scene: MoeErrorScene.feed));
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        _notify();
      }
    }
  }

  Future<void> toggleCommentLike(String commentId) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      throw StateError('请先登录');
    }
    final idx = _comments.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      await PostService.toggleCommentLike(commentId, userId);
      return;
    }
    final before = _comments[idx];
    final liked = !before.isLiked;
    final likes =
        liked ? before.likes + 1 : (before.likes > 0 ? before.likes - 1 : 0);
    _comments[idx] = before.copyWith(isLiked: liked, likes: likes);
    _notify();
    try {
      await PostService.toggleCommentLike(commentId, userId);
    } catch (e) {
      if (!_disposed && idx < _comments.length && _comments[idx].id == commentId) {
        _comments[idx] = before;
        _notify();
      }
      throw StateError(MoeErrorCopy.toast(e, scene: MoeErrorScene.feed));
    }
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
