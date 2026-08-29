import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../services/achievement_hooks.dart';
import '../../auth_service.dart';
import '../../services/companion_service.dart';
import '../../services/like_state_manager.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/ai_bot_badge.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/post_card.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../theme/moe_tokens.dart';
import 'comments_viewmodel.dart';

class CommentsPage extends StatefulWidget {
  final String postId;

  /// 非空时：顶部展示完整动态（与首页 [PostCard] 一致，含手绘/多图），下方为评论区，用于社区详情闭环。
  final Post? embeddedPost;

  /// 作为社区 AI 账号评论时使用。
  final CompanionCommunityIdentityData? communityIdentity;

  /// 下拉刷新时先于拉评论执行（例如重新拉帖子详情）。
  final Future<void> Function()? onRefreshPreamble;

  const CommentsPage({
    super.key,
    required this.postId,
    this.embeddedPost,
    this.onRefreshPreamble,
    this.communityIdentity,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  late final CommentsViewModel _vm;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  /// 每条一级评论下已展开的回复条数（楼中楼展开后分页）
  final Map<String, int> _visibleReplyCount = {};

  /// 已展开楼中楼的一级评论 id
  final Set<String> _expandedReplyThreads = {};
  final Set<String> _revealedCommentKeys = <String>{};
  static const int _initialReplyVisible = 5;
  static const int _replyLoadStep = 10;

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _vm = CommentsViewModel(
      postId: widget.postId,
      communityIdentity: widget.communityIdentity,
    );
    _vm.addListener(_onVmChanged);
    unawaited(_vm.bootstrap());
  }

  Future<void> _addComment() async {
    try {
      final expandRootId = _replyThreadRootIdForParent(_vm.replyParentId);
      final unlocks = await _vm.submitComment(_commentController.text);
      _commentController.clear();
      if (expandRootId != null) {
        _expandedReplyThreads.add(expandRootId);
      }
      if (!mounted) return;
      final userId = _vm.authorUserId ?? AuthService.currentUser;
      if (userId != null && unlocks.isNotEmpty) {
        AchievementHooks.scheduleServerUnlocks(userId, unlocks);
      }
      _showCustomSnackBar(context, '评论成功', isError: false);
    } on StateError catch (e) {
      if (!mounted) return;
      _showCustomSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showCustomSnackBar(
        context,
        MoeErrorCopy.toast(e, scene: MoeErrorScene.feed),
        isError: true,
      );
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    try {
      await _vm.toggleCommentLike(commentId);
    } on StateError catch (e) {
      if (!mounted) return;
      _showCustomSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showCustomSnackBar(
        context,
        MoeErrorCopy.toast(e, scene: MoeErrorScene.feed),
        isError: true,
      );
    }
  }

  void _showCustomSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    if (isError) {
      MoeToast.error(context, message);
    } else {
      MoeToast.success(context, message);
    }
  }

  /// 兼容旧版仅 @昵称、未写 parent_id 的回复
  List<Comment> get _normalizedComments {
    return _vm.comments.map(_normalizeCommentParent).toList();
  }

  Comment _normalizeCommentParent(Comment c) {
    if (!c.isTopLevel) return c;
    final inferredParentId = _inferParentForOrphanReply(c);
    if (inferredParentId == null) return c;
    Comment? parent;
    for (final x in _vm.comments) {
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
    for (final other in _vm.comments) {
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
    _vm.beginReply(parentId: comment.id, toUserName: comment.userName);
    _commentController.clear();
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    _vm.cancelReply();
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
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
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
        Navigator.of(context).pop(_vm.commentCount);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [MoeTokens.primary, MoeTokens.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: MoeTokens.primary.withValues(alpha: 0.2),
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
                      : '评论 (${_vm.commentCount})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context, _vm.commentCount),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: MoeTokens.primary,
                onRefresh: () async {
                  if (widget.onRefreshPreamble != null) {
                    await widget.onRefreshPreamble!();
                  }
                  await _vm.fetchComments();
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
                          mediaPresentation: PostCardMediaPresentation.detail,
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
                    if (_vm.isLoading)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: widget.embeddedPost != null ? 140 : 400,
                          child: const Center(child: MoeLoading()),
                        ),
                      )
                    else if (_vm.loadError != null && _vm.comments.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: MoeErrorState.fromError(
                          _vm.loadError,
                          scene: MoeErrorScene.feed,
                          onRetry: _vm.fetchComments,
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
                                  '全部评论 · ${_vm.commentCount} 条',
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
                      if (_vm.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: MoeEmptyState(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: '暂无评论',
                              subtitle: '快来抢沙发吧～',
                              showCard: false,
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
                                  child: MoeStaggerReveal(
                                    index: index,
                                    itemKey: 'cmt_${comment.id}',
                                    revealedKeys: _revealedCommentKeys,
                                    child: _buildTopLevelThread(comment),
                                  ),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.communityIdentity?.isValid == true) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.smart_toy_rounded,
                              size: 18,
                              color: MoeTokens.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '当前以 ${widget.communityIdentity!.userName.isNotEmpty ? widget.communityIdentity!.userName : 'AI 伙伴'} 回复',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            AiBotBadge(
                              compact: true,
                              agentKey: widget.communityIdentity!
                                      .authorBotAgentKey.isNotEmpty
                                  ? widget.communityIdentity!.authorBotAgentKey
                                  : widget.communityIdentity!.agentId,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_vm.replyParentId != null && _vm.replyToUserName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '回复 @${_vm.replyToUserName}',
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
                          border: Border.all(
                              color: MoeTokens.primary.withValues(alpha: 0.3),
                              width: 1.5),
                        ),
                        child: NetworkAvatarImage(
                          imageUrl: _vm.userAvatar,
                          radius: 16,
                          placeholderIcon: Icons.person,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: MoeTokens.pageBackground,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocus,
                            decoration: InputDecoration(
                              hintText: _vm.replyToUserName != null
                                  ? '回复 @${_vm.replyToUserName}'
                                  : '写下你的想法...',
                              border: InputBorder.none,
                              isDense: true,
                              hintStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 14),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _vm.isSubmitting
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
                                    colors: [
                                      MoeTokens.primary,
                                      MoeTokens.secondary
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_upward_rounded,
                                    color: Colors.white, size: 20),
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
            Icon(icon, size: 16, color: MoeTokens.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MoeTokens.primary,
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
                        for (final reply in shown) _buildCompactReplyRow(reply),
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
                Text.rich(
                  TextSpan(
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
                      if (comment.authorIsBot)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: AiBotBadge(
                              compact: true,
                              agentKey: comment.authorBotAgentKey,
                            ),
                          ),
                        ),
                      if (replyName.isNotEmpty)
                        TextSpan(
                          text: '@$replyName ',
                          style: TextStyle(
                            color: MoeTokens.primary,
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
                                        color:
                                            isLiked ? Colors.red : Colors.grey,
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
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: comment.userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isReply ? 12 : 13,
                              color: Colors.grey[800],
                            ),
                          ),
                          if (comment.authorIsBot)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: AiBotBadge(
                                  compact: true,
                                  agentKey: comment.authorBotAgentKey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
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
                            color: MoeTokens.primary.withValues(alpha: 0.05),
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
                                      color: isLiked ? Colors.red : Colors.grey,
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
