import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../models/user.dart';
import '../../services/achievement_hooks.dart';
import '../../auth_service.dart';
import '../../services/companion_service.dart';
import '../../services/like_state_manager.dart';
import '../../utils/moe_error_copy.dart';
import '../../utils/comment_mentions.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/ai_bot_badge.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_like_action_button.dart';
import '../../widgets/post_card.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../theme/moe_tokens.dart';
import 'comments_viewmodel.dart';

const double _detailContentMaxWidth = 600;

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

  /// 正文超过折叠行数后，用户点开「展开全文」的评论 id
  final Set<String> _expandedCommentBodies = {};
  final Set<String> _revealedCommentKeys = <String>{};
  static const int _initialReplyVisible = 5;
  static const int _replyLoadStep = 10;
  static const int _collapsedBodyLines = 6;

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
    _commentController.addListener(_syncMention);
    unawaited(_vm.bootstrap());
  }

  void _syncMention() {
    final selection = _commentController.selection.baseOffset;
    _vm.updateMention(_commentController.text, selection);
  }

  void _insertAtSign() {
    final text = _commentController.text;
    var cursor = _commentController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) cursor = text.length;
    final needsSpace = cursor > 0 && !RegExp(r'\s').hasMatch(text[cursor - 1]);
    final insert = needsSpace ? ' @' : '@';
    final next = text.replaceRange(cursor, cursor, insert);
    _commentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor + insert.length),
    );
    _commentFocus.requestFocus();
  }

  void _insertMention(User user) {
    final edit = applyCommentMention(
      _commentController.text,
      _commentController.selection.baseOffset,
      user.username,
    );
    _commentController.value = TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.cursor),
    );
    _commentFocus.requestFocus();
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

  List<Comment> get _topLevelComments {
    return _vm.comments.where((c) => c.isTopLevel).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 楼中楼只展示两级：一级评论 + 其下所有回复（不再逐层右缩进）。
  String _threadRootId(Comment c) {
    if (c.isTopLevel) return c.id;
    var pid = c.parentId;
    final byId = {for (final x in _vm.comments) x.id: x};
    while (pid.isNotEmpty && pid != '0') {
      final p = byId[pid];
      if (p == null) break;
      if (p.isTopLevel) return p.id;
      pid = p.parentId;
    }
    return c.parentId;
  }

  List<Comment> _allRepliesUnderRoot(String rootId) {
    return _vm.comments
        .where((c) => !c.isTopLevel && _threadRootId(c) == rootId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
    for (final c in _vm.comments) {
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
    _commentController.removeListener(_syncMention);
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
        backgroundColor: MoeTokens.pageBackground,
        appBar: AppBar(
          backgroundColor: MoeTokens.pageBackground,
          foregroundColor: MoeTokens.inkDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          shape: const Border(
            bottom: BorderSide(color: MoeTokens.surfaceBorder),
          ),
          title: Text(
            widget.embeddedPost != null ? '帖子对话' : '评论 (${_vm.commentCount})',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: MoeTokens.textMd,
              color: MoeTokens.inkDark,
            ),
          ),
          leading: IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () => Navigator.pop(context, _vm.commentCount),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > _detailContentMaxWidth
                ? _detailContentMaxWidth
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  mediaPresentation:
                                      PostCardMediaPresentation.detail,
                                  onComment: () {
                                    _commentFocus.requestFocus();
                                  },
                                  onShare: () => Share.share(
                                    widget.embeddedPost!.displayCaption
                                            .trim()
                                            .isEmpty
                                        ? '分享了一条动态'
                                        : widget.embeddedPost!.displayCaption
                                            .trim(),
                                  ),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: _buildConversationHeading(scheme),
                            ),
                            if (_vm.isLoading)
                              const SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 120,
                                  child: Center(child: MoeLoading()),
                                ),
                              )
                            else if (_vm.loadError != null &&
                                _vm.comments.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: MoeErrorState.fromError(
                                  _vm.loadError,
                                  scene: MoeErrorScene.feed,
                                  onRetry: _vm.fetchComments,
                                ),
                              )
                            else if (_vm.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: MoeEmptyState(
                                    title: '还没有回应',
                                    subtitle: '说说你的想法，开启这段对话',
                                    showCard: false,
                                    compact: true,
                                    image: _CommentEmptyMark(),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  MoeTokens.spaceLg,
                                  MoeTokens.spaceSm,
                                  MoeTokens.spaceLg,
                                  MoeTokens.spaceLg,
                                ),
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
                        ),
                      ),
                    ),
                    _buildCommentComposer(scheme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConversationHeading(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceLg,
        MoeTokens.spaceSm,
        MoeTokens.spaceLg,
        MoeTokens.spaceXs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.forum_rounded,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          Text(
            widget.embeddedPost != null ? '对话' : '评论',
            style: TextStyle(
              color: MoeTokens.titleText,
              fontSize: MoeTokens.textLg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          Text(
            '${_vm.commentCount} 条回应',
            style: TextStyle(
              color: MoeTokens.inkMuted.withValues(alpha: 0.8),
              fontSize: MoeTokens.textSm,
            ),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          Expanded(
            child: Divider(
              height: 1,
              color: MoeTokens.lineSoft.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer(ColorScheme scheme) {
    return Container(
      decoration: const BoxDecoration(
        color: MoeTokens.surface1,
        border: Border(top: BorderSide(color: MoeTokens.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MoeTokens.spaceLg,
            MoeTokens.spaceSm,
            MoeTokens.spaceLg,
            MoeTokens.spaceSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.communityIdentity?.isValid == true) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: MoeTokens.spaceSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MoeTokens.spaceMd,
                      vertical: MoeTokens.spaceSm,
                    ),
                    decoration: BoxDecoration(
                      color: MoeTokens.softChipBg,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                      border: Border.all(color: MoeTokens.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.smart_toy_rounded,
                          size: 18,
                          color: MoeTokens.primary,
                        ),
                        const SizedBox(width: MoeTokens.spaceSm),
                        Expanded(
                          child: Text(
                            '当前以 ${widget.communityIdentity!.userName.isNotEmpty ? widget.communityIdentity!.userName : 'AI 伙伴'} 回复',
                            style: TextStyle(
                              fontSize: MoeTokens.textSm,
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        AiBotBadge(
                          compact: true,
                          agentKey: widget.communityIdentity!.authorBotAgentKey
                                  .isNotEmpty
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
                  padding: const EdgeInsets.only(
                    bottom: MoeTokens.spaceXs,
                    left: MoeTokens.spaceXs,
                    right: MoeTokens.spaceXs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: MoeTokens.spaceXs),
                      Expanded(
                        child: Text(
                          '回复 @${_vm.replyToUserName}',
                          style: TextStyle(
                            fontSize: MoeTokens.textSm,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '取消回复',
                        visualDensity: VisualDensity.compact,
                        onPressed: _cancelReply,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              if (_vm.mentionActive) _buildMentionPicker(scheme),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  NetworkAvatarImage(
                    imageUrl: _vm.userAvatar,
                    radius: 16,
                    placeholderIcon: Icons.person,
                  ),
                  const SizedBox(width: MoeTokens.spaceSm),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: MoeTokens.pageBackground,
                        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                        border: Border.all(color: MoeTokens.surfaceBorder),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: MoeTokens.spaceMd,
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocus,
                        decoration: InputDecoration(
                          hintText: _vm.replyToUserName != null
                              ? '回复 @${_vm.replyToUserName}'
                              : '回复这条动态...',
                          border: InputBorder.none,
                          isDense: true,
                          hintStyle: const TextStyle(
                            color: MoeTokens.hintText,
                            fontSize: MoeTokens.textBase,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: MoeTokens.spaceSm,
                          ),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: MoeTokens.spaceSm),
                  MoePressable(
                    onTap: _insertAtSign,
                    pressedScale: MoeTokens.motionPressScale,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    child: const SizedBox(
                      width: 36,
                      height: 40,
                      child: Icon(
                        Icons.alternate_email_rounded,
                        color: MoeTokens.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: MoeTokens.spaceXs),
                  _vm.isSubmitting
                      ? const Padding(
                          padding: EdgeInsets.all(MoeTokens.spaceXs),
                          child: MoeSmallLoading(size: 22),
                        )
                      : MoePressable(
                          onTap: _addComment,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: MoeTokens.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMentionPicker(ColorScheme scheme) {
    final suggestions = _vm.mentionSuggestions;
    return Padding(
      padding: const EdgeInsets.only(bottom: MoeTokens.spaceSm),
      child: Material(
        color: MoeTokens.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          side: const BorderSide(color: MoeTokens.surfaceBorder),
        ),
        child: suggestions.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MoeTokens.spaceMd,
                  vertical: MoeTokens.spaceSm,
                ),
                child: Text(
                  '没有匹配的好友',
                  style: TextStyle(
                    color: MoeTokens.hintText,
                    fontSize: MoeTokens.textSm,
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final user in suggestions)
                    InkWell(
                      onTap: () => _insertMention(user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MoeTokens.spaceMd,
                          vertical: MoeTokens.spaceSm,
                        ),
                        child: Row(
                          children: [
                            NetworkAvatarImage(
                              imageUrl: user.avatar,
                              radius: 14,
                              placeholderIcon: Icons.person,
                            ),
                            const SizedBox(width: MoeTokens.spaceSm),
                            Expanded(
                              child: Text(
                                user.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: MoeTokens.textBase,
                                ),
                              ),
                            ),
                          ],
                        ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: MoeTokens.spaceSm),
      child: MoePressable(
        onTap: onTap,
        pressedScale: MoeTokens.motionPressScale,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MoeTokens.spaceMd,
            vertical: MoeTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: MoeTokens.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: MoeTokens.primary),
              const SizedBox(width: MoeTokens.spaceXs),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MoeTokens.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentLikeAction(Comment comment) {
    return ValueListenableBuilder<bool>(
      valueListenable: LikeStateManager().getCommentStatusNotifier(
        comment.id,
        initialValue: comment.isLiked,
      ),
      builder: (context, isLiked, _) {
        return ValueListenableBuilder<int>(
          valueListenable: LikeStateManager().getCommentCountNotifier(
            comment.id,
            initialValue: comment.likes,
          ),
          builder: (context, likeCount, _) {
            return MoeLikeActionButton(
              key: ValueKey('comment_like_${comment.id}'),
              isLiked: isLiked,
              likeCount: likeCount,
              compact: true,
              showCountWhenZero: false,
              onPressed: _vm.isCommentLikePending(comment.id)
                  ? null
                  : () => _toggleCommentLike(comment.id),
            );
          },
        );
      },
    );
  }

  /// 一级评论，回复默认收成一颗胶囊，展开后沿左侧细线排成同一套行样式。
  Widget _buildTopLevelThread(Comment root) {
    final replies = _allRepliesUnderRoot(root.id);
    final expanded = _isReplyThreadExpanded(root.id);
    final visible = _visibleCountForParent(root.id, replies.length);
    final shown = replies.take(visible).toList();
    final remaining = replies.length - visible;

    return Padding(
      padding: const EdgeInsets.only(bottom: MoeTokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentRow(root, isReply: false),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: MoeTokens.spaceLg,
                top: MoeTokens.spaceXs,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: MoeTokens.primary.withValues(alpha: 0.22),
                      width: 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: MoeTokens.spaceMd),
                  child: expanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final reply in shown)
                              _buildCommentRow(reply, isReply: true),
                            if (remaining > 0)
                              _buildThreadToggle(
                                label: '再看 $remaining 条',
                                icon: Icons.add_rounded,
                                onTap: () =>
                                    _showMoreReplies(root.id, replies.length),
                              ),
                            _buildThreadToggle(
                              label: '收起',
                              icon: Icons.expand_less_rounded,
                              onTap: () => _toggleReplyThread(
                                root.id,
                                replyCount: replies.length,
                              ),
                            ),
                          ],
                        )
                      : _buildThreadToggle(
                          label: '${replies.length} 条回复',
                          icon: Icons.subdirectory_arrow_right_rounded,
                          onTap: () => _toggleReplyThread(
                            root.id,
                            replyCount: replies.length,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentRow(Comment comment, {required bool isReply}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? MoeTokens.spaceMd : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkAvatarImage(
            imageUrl: comment.userAvatar,
            radius: isReply ? 14 : 18,
            placeholderIcon: Icons.person,
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoePressable(
                  onTap: () => _startReply(comment),
                  pressedScale: 1,
                  pressedOpacity: 0.72,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isReply ? 12 : 13,
                            color: MoeTokens.titleText,
                          ),
                        ),
                      ),
                      if (comment.authorIsBot) ...[
                        const SizedBox(width: MoeTokens.spaceXs),
                        AiBotBadge(
                          compact: true,
                          agentKey: comment.authorBotAgentKey,
                        ),
                      ],
                      const SizedBox(width: MoeTokens.spaceSm),
                      Text(
                        _formatTime(comment.createdAt),
                        style: const TextStyle(
                          color: MoeTokens.hintText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceXs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCommentBody(comment, isReply)),
                    const SizedBox(width: MoeTokens.spaceSm),
                    _buildCommentLikeAction(comment),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBody(Comment comment, bool isReply) {
    final text = _displayContent(comment);
    final replyName = comment.replyToUserName.trim();
    final expanded = _expandedCommentBodies.contains(comment.id);
    final span = TextSpan(
      style: TextStyle(
        height: 1.5,
        fontSize: isReply ? 13 : 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      children: [
        if (replyName.isNotEmpty)
          TextSpan(
            text: '@$replyName ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ...commentMentionSpans(
          text,
          TextStyle(
            height: 1.5,
            fontSize: isReply ? 13 : 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          TextStyle(
            height: 1.5,
            fontSize: isReply ? 13 : 14,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: span,
          maxLines: _collapsedBodyLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflow = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoePressable(
              onTap: () => _startReply(comment),
              pressedScale: 1,
              pressedOpacity: 0.72,
              child: Text.rich(
                span,
                maxLines: expanded ? null : _collapsedBodyLines,
                overflow:
                    expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            if (overflow)
              MoePressable(
                onTap: () {
                  setState(() {
                    if (expanded) {
                      _expandedCommentBodies.remove(comment.id);
                    } else {
                      _expandedCommentBodies.add(comment.id);
                    }
                  });
                },
                pressedScale: MoeTokens.motionPressScale,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: Padding(
                  padding: const EdgeInsets.only(top: MoeTokens.spaceXs),
                  child: Text(
                    expanded ? '收起' : '展开全文',
                    style: const TextStyle(
                      color: MoeTokens.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

/// 评论空态插图：叠放的小纸条，替代大号渐变圆。
class _CommentEmptyMark extends StatelessWidget {
  const _CommentEmptyMark();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _CommentEmptyMarkPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _CommentEmptyMarkPainter extends CustomPainter {
  const _CommentEmptyMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final back = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.06,
        size.width * 0.58,
        size.height * 0.52,
      ),
      const Radius.circular(MoeTokens.radiusMd),
    );
    canvas.drawRRect(
      back,
      Paint()..color = MoeTokens.secondary.withValues(alpha: 0.38),
    );

    final front = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.24,
        size.width * 0.68,
        size.height * 0.62,
      ),
      const Radius.circular(MoeTokens.radiusLg),
    );
    canvas.drawRRect(front, Paint()..color = MoeTokens.cardBackground);
    canvas.drawRRect(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = MoeTokens.primary.withValues(alpha: 0.4),
    );

    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = MoeTokens.primary.withValues(alpha: 0.5);
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.46),
      Offset(size.width * 0.56, size.height * 0.46),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.42, size.height * 0.6),
      line..color = MoeTokens.secondary.withValues(alpha: 0.75),
    );

    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.3),
      7,
      Paint()..color = MoeTokens.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
