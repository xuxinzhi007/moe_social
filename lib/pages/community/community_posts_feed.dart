import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../auth_service.dart';
import '../../theme/moe_tokens.dart';
import '../../theme/moe_theme_extension.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/post_card.dart';
import '../../utils/post_navigation.dart';

/// 社区内「话题讨论 / 内容广场」共用的帖子流：走 [PostService.getPosts]，点赞与评论与首页闭环一致。
///
/// 使用 [CustomScrollView]，筛选条与帖子同一滚动，避免「只有底部一小块能滑」。
class CommunityPostsFeed extends StatefulWidget {
  const CommunityPostsFeed({
    super.key,
    this.topicTagId,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.showVisualKindRow = false,
    this.topBar,
  });

  /// 传入官方话题 id（与动态话题一致）时只拉该话题下帖子；为 null 表示全站最新。
  final String? topicTagId;
  final String emptyTitle;
  final String emptySubtitle;

  /// 为 true 时，话题条下方展示形态筛选（仅客户端过滤已拉取的列表）。
  final bool showVisualKindRow;

  /// 可选顶部条（如话题 Chip），与列表一体滚动。
  final Widget? topBar;

  @override
  State<CommunityPostsFeed> createState() => _CommunityPostsFeedState();
}

enum _VisualKind { all, image, handDraw, text }

class _CommunityPostsFeedState extends State<CommunityPostsFeed> {
  List<Post> _posts = [];
  bool _loading = true;
  Object? _loadError;
  _VisualKind _visualKind = _VisualKind.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CommunityPostsFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicTagId != widget.topicTagId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final viewer = AuthService.currentUser;
      final map = await PostService.getPosts(
        page: 1,
        pageSize: 30,
        viewerUserId: viewer,
        feedMode: 'latest',
        topicTagId: widget.topicTagId,
      );
      if (!mounted) return;
      setState(() {
        _posts = map['posts'] as List<Post>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  List<Post> get _filtered {
    var list = _posts;
    if (widget.showVisualKindRow) {
      switch (_visualKind) {
        case _VisualKind.all:
          break;
        case _VisualKind.image:
          list = list
              .where(
                  (p) => p.images.isNotEmpty || p.handDrawThumbUrl.isNotEmpty)
              .toList();
          break;
        case _VisualKind.handDraw:
          list = list
              .where((p) => p.hasHandDraw || p.handDrawCardJson.isNotEmpty)
              .toList();
          break;
        case _VisualKind.text:
          list = list
              .where((p) =>
                  p.images.isEmpty &&
                  !p.hasHandDraw &&
                  p.handDrawCardJson.isEmpty &&
                  p.handDrawThumbUrl.isEmpty)
              .toList();
          break;
      }
    }
    return list;
  }

  void _openPostDetail(Post post) {
    openPostDetail(context, post).then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    if (_loading) {
      return Center(child: MoeLoading(color: moe.primary));
    }
    if (_loadError != null) {
      return Center(
        child: MoeErrorState.fromError(
          _loadError,
          scene: MoeErrorScene.community,
          variant: MoeErrorVariant.plain,
          onRetry: _load,
        ),
      );
    }

    final list = _filtered;

    return RefreshIndicator(
      color: moe.primary,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (widget.topBar != null) SliverToBoxAdapter(child: widget.topBar),
          if (widget.showVisualKindRow)
            SliverToBoxAdapter(child: _buildVisualRow()),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum_outlined,
                          size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        widget.emptyTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: MoeTokens.textLg,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.emptySubtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final post = list[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PostCard(
                          post: post,
                          heroTagPrefix: 'cfeed_',
                          onComment: () => _openPostDetail(post),
                          onLike: () {
                            if (mounted) _load();
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12, bottom: 4),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _openPostDetail(post),
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 18),
                              label: const Text('查看全文与评论'),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: list.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualRow() {
    final scheme = Theme.of(context).colorScheme;
    const items = <(_VisualKind, String)>[
      (_VisualKind.all, '全部'),
      (_VisualKind.image, '带图'),
      (_VisualKind.handDraw, '手绘'),
      (_VisualKind.text, '文字'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: _VisualSegment(
                  label: item.$2,
                  selected: _visualKind == item.$1,
                  onTap: () => setState(() => _visualKind = item.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisualSegment extends StatelessWidget {
  const _VisualSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: MoeTokens.textSm,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
