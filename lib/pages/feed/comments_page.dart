import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/achievement_hooks.dart';
import '../../services/api_service.dart';
import '../../auth_service.dart';
import '../../services/like_state_manager.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/post_card.dart';

class CommentsPage extends StatefulWidget {
  final String postId;
  /// 非空时：顶部展示完整动态（与首页 [PostCard] 一致，含手绘/多图），下方为评论区，用于社区详情闭环。
  final Post? embeddedPost;
  /// 下拉刷新时先于拉评论执行（例如重新拉帖子详情）。
  final Future<void> Function()? onRefreshPreamble;

  const CommentsPage({
    Key? key,
    required this.postId,
    this.embeddedPost,
    this.onRefreshPreamble,
  }) : super(key: key);

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _userName;
  String? _userAvatar;
  /// 正在回复的评论 ID（作为 parent_id 提交）
  String? _replyParentId;
  String? _replyToUserName;
  /// 每条一级评论下已展开的回复条数（楼中楼展开后分页）
  final Map<String, int> _visibleReplyCount = {};
  /// 已展开楼中楼的一级评论 id
  final Set<String> _expandedReplyThreads = {};
  static const int _initialReplyVisible = 5;
  static const int _replyLoadStep = 10;

  // Moe 风格颜色
  final Color _primaryColor = const Color(0xFF7F7FD5);
  final Color _accentColor = const Color(0xFF86A8E7);

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchComments();
  }

  Future<void> _loadUserInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    try {
      final user = await ApiService.getUserInfo(userId);
      setState(() {
        _userName = user.username;
        _userAvatar = user.avatar.isNotEmpty ? user.avatar : null;
      });
    } catch (e) {
      print('加载用户信息失败: $e');
    }
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await PostService.getComments(widget.postId);
      setState(() {
        _comments = comments;
      });
    } catch (e) {
      print('Failed to fetch comments: $e');
      _showCustomSnackBar(context, '获取评论失败', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      _showCustomSnackBar(context, '请输入评论内容', isError: true);
      return;
    }

    final userId = AuthService.currentUser;
    if (userId == null) {
      _showCustomSnackBar(context, '请先登录', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final comment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        postId: widget.postId,
        userId: userId,
        userName: _userName ?? '用户',
        userAvatar: _userAvatar ?? 'https://picsum.photos/150',
        content: _commentController.text.trim(),
        likes: 0,
        isLiked: false,
        createdAt: DateTime.now(),
        parentId: _replyParentId ?? '',
        replyToUserName: _replyToUserName ?? '',
      );

      final result = await ApiService.addCommentWithUnlocks(comment);
      final unlocked = result.newAchievements;

      final expandRootId = _replyThreadRootIdForParent(_replyParentId);
      _commentController.clear();
      setState(() {
        if (expandRootId != null) {
          _expandedReplyThreads.add(expandRootId);
        }
        _replyParentId = null;
        _replyToUserName = null;
      });
      await _fetchComments();

      if (!mounted) return;
      if (unlocked.isNotEmpty) {
        AchievementHooks.scheduleServerUnlocks(userId, unlocked);
      }
      _showCustomSnackBar(context, '评论成功', isError: false);
    } catch (e) {
      print('Failed to add comment: $e');
      _showCustomSnackBar(context, '评论失败，请重试', isError: true);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      _showCustomSnackBar(context, '请先登录', isError: true);
      return;
    }

    // 乐观更新：LikeStateManager 会自动处理状态变化，UI 通过 ValueListenableBuilder 监听更新
    // 这里只需要调用 Service 方法即可
    try {
      await PostService.toggleCommentLike(commentId, userId);
      // 无需手动 setState 更新 _comments，因为 LikeButton 现在直接监听 LikeStateManager
    } catch (e) {
      print('Failed to toggle comment like: $e');
      _showCustomSnackBar(context, '操作失败', isError: true);
    }
  }

  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (isError) {
      MoeToast.error(context, message);
    } else {
      MoeToast.success(context, message);
    }
  }

  /// 兼容旧版仅 @昵称、未写 parent_id 的回复
  List<Comment> get _normalizedComments {
    return _comments.map(_normalizeCommentParent).toList();
  }

  Comment _normalizeCommentParent(Comment c) {
    if (!c.isTopLevel) return c;
    final inferredParentId = _inferParentForOrphanReply(c);
    if (inferredParentId == null) return c;
    Comment? parent;
    for (final x in _comments) {
      if (x.id == inferredParentId) {
        parent = x;
        break;
      }
    }
    return c.copyWith(
      parentId: inferredParentId,
      replyToUserName: parent?.userName ?? c.replyToUserName,
    );
  }

  String? _inferParentForOrphanReply(Comment c) {
    final trimmed = c.content.trim();
    if (!trimmed.startsWith('@')) return null;
    final match = RegExp(r'^@(\S+)').firstMatch(trimmed);
    if (match == null) return null;
    final targetName = match.group(1)!;

    Comment? best;
    for (final other in _comments) {
      if (other.id == c.id || other.userName != targetName) continue;
      if (other.createdAt.isAfter(c.createdAt)) continue;
      if (best == null || other.createdAt.isAfter(best.createdAt)) {
        best = other;
      }
    }
    return best?.id;
  }

  List<Comment> get _topLevelComments {
    return _normalizedComments.where((c) => c.isTopLevel).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 楼中楼只展示两级：一级评论 + 其下所有回复（不再逐层右缩进）。
  String _threadRootId(Comment c) {
    if (c.isTopLevel) return c.id;
    var pid = c.parentId;
    final byId = {for (final x in _normalizedComments) x.id: x};
    while (pid.isNotEmpty && pid != '0') {
      final p = byId[pid];
      if (p == null) break;
      if (p.isTopLevel) return p.id;
      pid = p.parentId;
    }
    return c.parentId;
  }

  List<Comment> _allRepliesUnderRoot(String rootId) {
    return _normalizedComments
        .where((c) => !c.isTopLevel && _threadRootId(c) == rootId)
        .map(_ensureReplyTargetName)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Comment _ensureReplyTargetName(Comment c) {
    if (c.replyToUserName.trim().isNotEmpty) return c;
    for (final x in _normalizedComments) {
      if (x.id == c.parentId) {
        return c.copyWith(replyToUserName: x.userName);
      }
    }
    return c;
  }

  void _startReply(Comment comment) {
    setState(() {
      _replyParentId = comment.id;
      _replyToUserName = comment.userName;
    });
    _commentController.clear();
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyParentId = null;
      _replyToUserName = null;
    });
  }

  int _visibleCountForParent(String parentId, int totalReplies) {
    final v = _visibleReplyCount[parentId] ?? _initialReplyVisible;
    return v > totalReplies ? totalReplies : v;
  }

  void _showMoreReplies(String parentId, int totalReplies) {
    setState(() {
      final current = _visibleReplyCount[parentId] ?? _initialReplyVisible;
      _visibleReplyCount[parentId] =
          (current + _replyLoadStep).clamp(0, totalReplies);
    });
  }

  bool _isReplyThreadExpanded(String rootId) =>
      _expandedReplyThreads.contains(rootId);

  void _toggleReplyThread(String rootId, {required int replyCount}) {
    setState(() {
      if (_expandedReplyThreads.contains(rootId)) {
        _expandedReplyThreads.remove(rootId);
      } else {
        _expandedReplyThreads.add(rootId);
        _visibleReplyCount.putIfAbsent(
          rootId,
          () => replyCount.clamp(0, _initialReplyVisible),
        );
      }
    });
  }

  String? _replyThreadRootIdForParent(String? parentId) {
    if (parentId == null || parentId.isEmpty) return null;
    for (final c in _normalizedComments) {
      if (c.id == parentId) return _threadRootId(c);
    }
    return null;
  }

  String _displayContent(Comment comment) {
    final name = comment.replyToUserName.trim();
    if (name.isEmpty) return comment.content;
    for (final prefix in ['@$name ', '@$name']) {
      if (comment.content.startsWith(prefix)) {
        return comment.content.substring(prefix.length).trimLeft();
      }
    }
    return comment.content;
  }

  @override
  void dispose() {
    _commentFocus.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_comments.length);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                widget.embeddedPost != null
                    ? '动态详情'
                    : '评论 (${_comments.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context, _comments.length),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: _primaryColor,
              onRefresh: () async {
                if (widget.onRefreshPreamble != null) {
                  await widget.onRefreshPreamble!();
                }
                await _fetchComments();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  if (widget.embeddedPost != null)
                    SliverToBoxAdapter(
                      child: PostCard(
                        post: widget.embeddedPost!,
                        heroTagPrefix: 'cdetail_',
                        onComment: () {
                          _commentFocus.requestFocus();
                        },
                        onShare: () => Share.share(
                          widget.embeddedPost!.displayCaption.trim().isEmpty
                              ? '分享了一条动态'
                              : widget.embeddedPost!.displayCaption.trim(),
                        ),
                      ),
                    ),
                  if (_isLoading)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: widget.embeddedPost != null ? 140 : 400,
                        child: const Center(child: MoeLoading()),
                      ),
                    )
                  else ...[
                    if (widget.embeddedPost != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          child: Row(
                            children: [
                              Icon(Icons.chat_bubble_rounded,
                                  size: 18, color: scheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                '全部评论 · ${_comments.length} 条',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_comments.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 48,
                                    color: Color(0xFF7F7FD5)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '暂无评论，下拉可刷新',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '快来抢沙发吧～',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant
                                      .withOpacity(0.85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final comment = _topLevelComments[index];
                            return KeyedSubtree(
                              key: ValueKey('comment_${comment.id}'),
                              child: _buildTopLevelThread(comment),
                            );
                          },
                          childCount: _topLevelComments.length,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 底部悬浮输入区域
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), // 适配全面屏底部
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_replyParentId != null && _replyToUserName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '回复 @$_replyToUserName',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _cancelReply,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF7F7FD5).withOpacity(0.3), width: 1.5),
                  ),
                  child: NetworkAvatarImage(
                    imageUrl: _userAvatar,
                    radius: 16,
                    placeholderIcon: Icons.person,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocus,
                      decoration: InputDecoration(
                        hintText: _replyToUserName != null
                            ? '回复 @$_replyToUserName'
                            : '写下你的想法...',
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: MoeSmallLoading(size: 22),
                      )
                    : InkWell(
                        onTap: _addComment,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                        ),
                      ),
              ],
            ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildThreadToggle({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _primaryColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 一级评论 + 可收起楼中楼（紧凑样式，与主评论气泡区分）。
  Widget _buildTopLevelThread(Comment root) {
    final replies = _allRepliesUnderRoot(root.id);
    final expanded = _isReplyThreadExpanded(root.id);
    final visible = _visibleCountForParent(root.id, replies.length);
    final shown = replies.take(visible).toList();
    final remaining = replies.length - visible;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentRow(root, isReply: false),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 50, top: 2),
              child: expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final reply in shown)
                          _buildCompactReplyRow(reply),
                        if (remaining > 0)
                          _buildThreadToggle(
                            label: '展开更多 $remaining 条回复',
                            icon: Icons.expand_more_rounded,
                            onTap: () =>
                                _showMoreReplies(root.id, replies.length),
                          ),
                        _buildThreadToggle(
                          label: '收起回复',
                          icon: Icons.expand_less_rounded,
                          onTap: () => _toggleReplyThread(
                            root.id,
                            replyCount: replies.length,
                          ),
                        ),
                      ],
                    )
                  : _buildThreadToggle(
                      label: '展开 ${replies.length} 条回复',
                      icon: Icons.expand_more_rounded,
                      onTap: () => _toggleReplyThread(
                        root.id,
                        replyCount: replies.length,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  /// 楼中楼紧凑行：无大气泡，与主评论视觉层级一致但更轻。
  Widget _buildCompactReplyRow(Comment comment) {
    final text = _displayContent(comment);
    final replyName = comment.replyToUserName.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkAvatarImage(
            imageUrl: comment.userAvatar,
            radius: 12,
            placeholderIcon: Icons.person,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: '${comment.userName} ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (replyName.isNotEmpty)
                        TextSpan(
                          text: '@$replyName ',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      TextSpan(text: text),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          LikeStateManager().getCommentStatusNotifier(
                        comment.id,
                        initialValue: comment.isLiked,
                      ),
                      builder: (context, isLiked, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable:
                              LikeStateManager().getCommentCountNotifier(
                            comment.id,
                            initialValue: comment.likes,
                          ),
                          builder: (context, likeCount, _) {
                            return GestureDetector(
                              onTap: () => _toggleCommentLike(comment.id),
                              child: Row(
                                children: [
                                  Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 14,
                                    color: isLiked ? Colors.red : Colors.grey,
                                  ),
                                  if (likeCount > 0) ...[
                                    const SizedBox(width: 2),
                                    Text(
                                      '$likeCount',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isLiked
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _startReply(comment),
                      child: Text(
                        '回复',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentRow(Comment comment, {required bool isReply}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NetworkAvatarImage(
          imageUrl: comment.userAvatar,
          radius: isReply ? 14 : 18,
          placeholderIcon: Icons.person,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comment.userName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isReply ? 12 : 13,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(comment.createdAt),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isReply ? 12 : 16,
                  vertical: isReply ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topRight: const Radius.circular(16),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: const Radius.circular(16),
                    topLeft: Radius.circular(isReply ? 12 : 4),
                  ),
                  boxShadow: isReply
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF7F7FD5).withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(2, 4),
                          ),
                        ],
                ),
                child: _buildCommentBody(comment, isReply),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        LikeStateManager().getCommentStatusNotifier(
                      comment.id,
                      initialValue: comment.isLiked,
                    ),
                    builder: (context, isLiked, _) {
                      return ValueListenableBuilder<int>(
                        valueListenable:
                            LikeStateManager().getCommentCountNotifier(
                          comment.id,
                          initialValue: comment.likes,
                        ),
                        builder: (context, likeCount, _) {
                          return GestureDetector(
                            onTap: () => _toggleCommentLike(comment.id),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isLiked ? Colors.red : Colors.grey,
                                  size: isReply ? 16 : 18,
                                ),
                                const SizedBox(width: 4),
                                if (likeCount > 0)
                                  Text(
                                    likeCount.toString(),
                                    style: TextStyle(
                                      color:
                                          isLiked ? Colors.red : Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _startReply(comment),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            color: Colors.grey[400],
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '回复',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentBody(Comment comment, bool isReply) {
    final text = _displayContent(comment);
    final replyName = comment.replyToUserName.trim();
    final showMention = replyName.isNotEmpty;
    if (!showMention) {
      return Text(
        text,
        style: TextStyle(
          height: 1.5,
          fontSize: isReply ? 13 : 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          height: 1.5,
          fontSize: isReply ? 13 : 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          TextSpan(
            text: '@$replyName ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}
