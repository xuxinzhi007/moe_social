import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../auth_service.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/post_card.dart';
import '../../utils/post_navigation.dart';

/// 社区内「话题讨论 / 内容广场」共用的帖子流：走 [ApiService.getPosts]，点赞与评论与首页闭环一致。
class CommunityPostsFeed extends StatefulWidget {
  const CommunityPostsFeed({
    super.key,
    this.topicTagId,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.showTextSearch = false,
    this.showVisualKindRow = false,
  });

  /// 传入官方话题 id（与动态话题一致）时只拉该话题下帖子；为 null 表示全站最新。
  final String? topicTagId;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showTextSearch;
  /// 为 true 时展示「全部 / 带图 / 手绘 / 文字」筛选（仅客户端过滤已拉取的列表）。
  final bool showVisualKindRow;

  @override
  State<CommunityPostsFeed> createState() => _CommunityPostsFeedState();
}

enum _VisualKind { all, image, handDraw, text }

class _CommunityPostsFeedState extends State<CommunityPostsFeed> {
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
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

  String _err(Object e) {
    if (e is ApiException) return e.message;
    return '加载失败，请稍后重试';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final viewer = AuthService.currentUser;
      final map = await ApiService.getPosts(
        page: 1,
        pageSize: 30,
        viewerUserId: viewer,
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
        _error = _err(e);
      });
    }
  }

  List<Post> get _filtered {
    var list = _posts;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) {
        final cap = p.displayCaption.toLowerCase();
        final name = p.userName.toLowerCase();
        final tags = p.topicTags.map((t) => t.name.toLowerCase()).join(' ');
        return cap.contains(q) || name.contains(q) || tags.contains(q);
      }).toList();
    }
    if (widget.showVisualKindRow) {
      switch (_visualKind) {
        case _VisualKind.all:
          break;
        case _VisualKind.image:
          list = list
              .where((p) => p.images.isNotEmpty || p.handDrawThumbUrl.isNotEmpty)
              .toList();
          break;
        case _VisualKind.handDraw:
          list = list.where((p) => p.handDrawCardJson.isNotEmpty).toList();
          break;
        case _VisualKind.text:
          list = list
              .where((p) =>
                  p.images.isEmpty &&
                  p.handDrawCardJson.isEmpty &&
                  p.handDrawThumbUrl.isEmpty)
              .toList();
          break;
      }
    }
    return list;
  }

  void _openPostDetail(Post post) {
    openPostDetail<void>(context, post).then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: MoeLoading());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final list = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTextSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: MoeSearchBar(
              hintText: '搜索正文、昵称或话题',
              onSearch: (s) => setState(() => _searchQuery = s),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),
        if (widget.showVisualKindRow) _buildVisualRow(),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF7F7FD5),
            onRefresh: _load,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.35,
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
                                    fontSize: 17,
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
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
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
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                label: const Text('查看全文与评论'),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualRow() {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, _VisualKind k) {
      final sel = _visualKind == k;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => setState(() => _visualKind = k),
          selectedColor: scheme.primary.withOpacity(0.12),
          checkmarkColor: scheme.primary,
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        children: [
          chip('全部', _VisualKind.all),
          chip('带图', _VisualKind.image),
          chip('手绘', _VisualKind.handDraw),
          chip('文字', _VisualKind.text),
        ],
      ),
    );
  }
}
