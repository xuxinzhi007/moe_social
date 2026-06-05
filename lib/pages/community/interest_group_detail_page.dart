import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../models/community_group.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../utils/media_url.dart';
import '../../utils/post_navigation.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/post_card.dart';
import '../feed/create_post_page.dart';

/// 兴趣群组详情：封面、成员、群帖流；未加入时可预览公开群信息。
class InterestGroupDetailPage extends StatefulWidget {
  const InterestGroupDetailPage({
    super.key,
    required this.groupId,
    this.initialGroup,
  });

  final String groupId;
  final CommunityGroup? initialGroup;

  @override
  State<InterestGroupDetailPage> createState() =>
      _InterestGroupDetailPageState();
}

class _InterestGroupDetailPageState extends State<InterestGroupDetailPage>
    with SingleTickerProviderStateMixin {
  CommunityGroup? _group;
  List<GroupPostEntry> _posts = [];
  List<GroupMember> _members = [];
  bool _loading = true;
  bool _loadingPosts = false;
  bool _loadingMembers = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _err(Object e) {
    if (e is ApiException) {
      final msg = e.message.trim();
      if (msg.length > 120) {
        return '${msg.substring(0, 120)}…';
      }
      return msg.isEmpty ? '加载失败' : msg;
    }
    if (kDebugMode) {
      return '加载失败：$e';
    }
    return '加载失败，请稍后重试';
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = AuthService.currentUser;
      final group = await ApiService.getCommunityGroup(
        groupId: widget.groupId,
        userId: uid,
      );
      if (!mounted) return;
      setState(() {
        _group = group;
        _loading = false;
      });
      unawaited(_loadPosts());
      unawaited(_loadMembers());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _err(e);
      });
    }
  }

  Future<void> _loadPosts({bool silent = false}) async {
    setState(() => _loadingPosts = true);
    try {
      final uid = AuthService.currentUser;
      final res = await ApiService.getGroupPosts(
        groupId: widget.groupId,
        userId: uid,
        pageSize: 30,
      );
      if (!mounted) return;
      setState(() {
        _posts = res['posts'] as List<GroupPostEntry>;
        _loadingPosts = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPosts = false);
        if (!silent) {
          MoeToast.error(context, _err(e));
        } else if (kDebugMode) {
          debugPrint('群帖刷新失败（静默）: $e');
        }
      }
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final res = await ApiService.getGroupMembers(
        groupId: widget.groupId,
        pageSize: 50,
      );
      if (!mounted) return;
      setState(() {
        _members = res['members'] as List<GroupMember>;
        _loadingMembers = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _toggleJoin() async {
    final g = _group;
    if (g == null) return;
    final uid = AuthService.currentUser;
    if (uid == null) {
      MoeToast.error(context, '请先登录');
      return;
    }
    try {
      if (g.isJoined) {
        await ApiService.leaveCommunityGroup(groupId: g.id, userId: uid);
        if (mounted) MoeToast.success(context, '已退出群组');
      } else {
        await ApiService.joinCommunityGroup(groupId: g.id, userId: uid);
        if (mounted) MoeToast.success(context, '已加入群组');
      }
      await _loadAll();
    } catch (e) {
      if (mounted) MoeToast.error(context, _err(e));
    }
  }

  Future<void> _postToGroup() async {
    final uid = AuthService.currentUser;
    if (uid == null) {
      MoeToast.error(context, '请先登录');
      return;
    }
    CommunityGroup g;
    try {
      g = await ApiService.getCommunityGroup(
        groupId: widget.groupId,
        userId: uid,
      );
      if (!mounted) return;
      setState(() => _group = g);
    } catch (e) {
      if (mounted) MoeToast.error(context, _err(e));
      return;
    }
    if (!g.isJoined) {
      MoeToast.info(context, '请先加入群组再发帖');
      return;
    }
    final created = await Navigator.push<Post>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(groupId: g.id),
      ),
    );
    if (created != null && mounted) {
      setState(() {
        _posts = [
          GroupPostEntry(
            id: '',
            groupId: g.id,
            postId: created.id,
            post: created,
          ),
          ..._posts.where((e) => e.postId != created.id),
        ];
      });
      unawaited(_loadPosts(silent: true));
    }
  }

  void _openPostDetail(Post post) {
    openPostDetail(context, post).then((_) {
      if (mounted) _loadPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _group == null) {
      return const Scaffold(body: Center(child: MoeLoading()));
    }
    if (_error != null && _group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('群组')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadAll, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }

    final g = _group!;
    final scheme = Theme.of(context).colorScheme;
    final cover = resolveMediaUrl(g.coverImage);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: cover.isNotEmpty
                  ? Image.network(cover, fit: BoxFit.cover)
                  : ColoredBox(
                      color: scheme.primary.withValues(alpha: 0.12),
                      child: Icon(Icons.groups_2_rounded,
                          size: 64, color: scheme.primary),
                    ),
            ),
          ),
          SliverToBoxAdapter(child: _buildHeaderInfo(g, scheme)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '动态'),
                  Tab(text: '成员'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(scheme),
            _buildMembersTab(scheme),
          ],
        ),
      ),
      floatingActionButton: g.isJoined
          ? FloatingActionButton.extended(
              onPressed: _postToGroup,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('发到本群'),
            )
          : null,
    );
  }

  Widget _buildHeaderInfo(CommunityGroup g, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      g.description.isEmpty ? '暂无简介' : g.description,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _toggleJoin,
                child: Text(g.isJoined ? '已加入' : '加入'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.people_outline, size: 18),
                label: Text('${g.memberCount} 成员'),
                visualDensity: VisualDensity.compact,
              ),
              if (g.creatorName.isNotEmpty)
                Chip(
                  label: Text('创建者 ${g.creatorName}'),
                  visualDensity: VisualDensity.compact,
                ),
              Chip(
                label: Text(g.isPublic ? '公开' : '私密'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(ColorScheme scheme) {
    if (_loadingPosts && _posts.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 48, color: scheme.outline),
              const SizedBox(height: 12),
              const Text(
                '群内还没有动态',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _group?.isJoined == true ? '做第一个在本群发帖的人吧' : '加入群组后可查看与发布讨论',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        itemCount: _posts.length,
        itemBuilder: (context, i) {
          final post = _posts[i].post;
          return PostCard(
            post: post,
            heroTagPrefix: 'gpost_${widget.groupId}_',
            onComment: () => _openPostDetail(post),
            onLike: () {
              if (mounted) _loadPosts();
            },
          );
        },
      ),
    );
  }

  Widget _buildMembersTab(ColorScheme scheme) {
    if (_loadingMembers && _members.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_members.isEmpty) {
      return Center(
        child: Text('暂无成员', style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = _members[i];
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                NetworkAvatarImage(
                  imageUrl: m.userAvatar,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (m.role.isNotEmpty && m.role != 'member')
                  Chip(
                    label: Text(m.role),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
