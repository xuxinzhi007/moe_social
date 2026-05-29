import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../models/community_group.dart';
import '../../services/api_service.dart';
import '../../utils/media_url.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/moe_toast.dart';

class InterestGroupsPage extends StatefulWidget {
  const InterestGroupsPage({super.key});

  @override
  State<InterestGroupsPage> createState() => InterestGroupsPageState();
}

class InterestGroupsPageState extends State<InterestGroupsPage> {
  final List<CommunityGroup> _groups = [];
  List<CommunityGroup> _myGroups = [];
  bool _loading = true;
  bool _loadingMyGroups = false;
  Object? _loadError;
  String _keyword = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String _formatError(Object e) {
    return MoeErrorCopy.toast(e, scene: MoeErrorScene.community);
  }

  Future<void> showCreateGroup() => _showCreateGroup();

  Future<void> _loadMyGroups() async {
    final uid = AuthService.currentUser;
    if (uid == null) {
      if (mounted) setState(() => _myGroups = []);
      return;
    }
    setState(() => _loadingMyGroups = true);
    try {
      final list = await ApiService.getUserCommunityGroups(userId: uid);
      if (!mounted) return;
      setState(() {
        _myGroups = list;
        _loadingMyGroups = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMyGroups = false);
    }
  }

  Future<void> _load({String? keyword}) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final uid = AuthService.currentUser;
      final res = await ApiService.getCommunityGroups(
        page: 1,
        pageSize: 40,
        keyword: keyword,
        userId: uid,
      );
      final raw = res['groups'] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        _groups
          ..clear()
          ..addAll(raw.map(CommunityGroup.fromApi));
        _loading = false;
      });
      unawaited(_loadMyGroups());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  void _scheduleSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _keyword = q.trim();
      _load(keyword: _keyword.isEmpty ? null : _keyword);
    });
  }

  void _openGroupDetail(CommunityGroup group) {
    Navigator.pushNamed(
      context,
      '/community/group',
      arguments: {'groupId': group.id, 'group': group},
    ).then((_) {
      if (mounted) _load(keyword: _keyword.isEmpty ? null : _keyword);
    });
  }

  Future<void> _toggleJoin(CommunityGroup g) async {
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
      await _load(keyword: _keyword.isEmpty ? null : _keyword);
    } catch (e) {
      if (mounted) MoeToast.error(context, _formatError(e));
    }
  }

  Future<void> _showCreateGroup() async {
    final uid = AuthService.currentUser;
    if (uid == null) {
      MoeToast.error(context, '请先登录');
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateInterestGroupSheet(
        userId: uid,
        formatError: _formatError,
      ),
    );
    if (ok == true && mounted) {
      MoeToast.success(context, '创建成功');
      await _load(keyword: _keyword.isEmpty ? null : _keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocking = _loading && _groups.isEmpty && _loadError == null;
    final showListProgress = _loading && _groups.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_myGroups.isNotEmpty || _loadingMyGroups)
            _buildMyGroupsRow(scheme),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: MoeSearchBar(
              hintText: '搜索群组名称或简介',
              onSearch: _scheduleSearch,
              onClear: () {
                _keyword = '';
                _load();
              },
            ),
          ),
          if (showListProgress)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF7F7FD5),
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: _loadError != null
                ? Center(
                    child: MoeErrorState.fromError(
                      _loadError,
                      scene: MoeErrorScene.community,
                      variant: MoeErrorVariant.plain,
                      onRetry: () => _load(),
                    ),
                  )
                : blocking
                    ? const Center(child: MoeLoading())
                    : RefreshIndicator(
                        color: const Color(0xFF7F7FD5),
                        onRefresh: () =>
                            _load(keyword: _keyword.isEmpty ? null : _keyword),
                        child: _groups.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.3,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.group_add_rounded,
                                              size: 56,
                                              color: Colors.grey.shade400),
                                          const SizedBox(height: 12),
                                          const Text(
                                            '还没有群组',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 17,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '试试换个关键词，或新建一个兴趣群组',
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          FilledButton.icon(
                                            onPressed: _showCreateGroup,
                                            icon: const Icon(Icons.add_rounded),
                                            label: const Text('新建群组'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                itemCount: _groups.length + 1,
                                itemBuilder: (context, i) {
                                  if (i == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '发现圈子',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    );
                                  }
                                  final group = _groups[i - 1];
                                  return _GroupCard(
                                    group: group,
                                    onTap: () => _openGroupDetail(group),
                                    onJoin: () => _toggleJoin(group),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyGroupsRow(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            '我的圈子',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (_loadingMyGroups && _myGroups.isEmpty)
          const SizedBox(
            height: 88,
            child: Center(child: MoeLoading()),
          )
        else
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _myGroups.length,
              itemBuilder: (context, i) {
                final g = _myGroups[i];
                final cover = resolveMediaUrl(g.coverImage);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => _openGroupDetail(g),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 36,
                              width: double.infinity,
                              child: cover.isNotEmpty
                                  ? Image.network(cover, fit: BoxFit.cover)
                                  : ColoredBox(
                                      color:
                                          scheme.primary.withValues(alpha: 0.1),
                                      child: Icon(Icons.groups_2_rounded,
                                          color: scheme.primary, size: 20),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CreateInterestGroupSheet extends StatefulWidget {
  const _CreateInterestGroupSheet({
    required this.userId,
    required this.formatError,
  });

  final String userId;
  final String Function(Object e) formatError;

  @override
  State<_CreateInterestGroupSheet> createState() =>
      _CreateInterestGroupSheetState();
}

class _CreateInterestGroupSheetState extends State<_CreateInterestGroupSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _isPublic = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final n = _nameCtrl.text.trim();
    if (n.isEmpty) {
      MoeToast.show(context, '请填写群组名称');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.createCommunityGroup(
        userId: widget.userId,
        name: n,
        description: _descCtrl.text.trim(),
        isPublic: _isPublic,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) MoeToast.error(context, widget.formatError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '新建兴趣群组',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '创建后可邀请同好加入，在群内讨论与发帖。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '群组名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '简介',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('公开群组'),
                subtitle: const Text('关闭则仅邀请可见（依后端策略）'),
                value: _isPublic,
                onChanged:
                    _submitting ? null : (v) => setState(() => _isPublic = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('创建'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onTap,
    required this.onJoin,
  });

  final CommunityGroup group;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = resolveMediaUrl(group.coverImage);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: cover.isNotEmpty
                        ? Image.network(
                            cover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: scheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: scheme.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            color: scheme.primary.withValues(alpha: 0.08),
                            alignment: Alignment.center,
                            child: Icon(Icons.groups_2_rounded,
                                size: 48, color: scheme.primary),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              onJoin();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: group.isJoined
                                  ? scheme.surfaceContainerHighest
                                  : scheme.primary.withValues(alpha: 0.12),
                              foregroundColor: group.isJoined
                                  ? scheme.onSurfaceVariant
                                  : scheme.primary,
                            ),
                            child: Text(group.isJoined ? '已加入' : '加入'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        group.description.isEmpty ? '暂无简介' : group.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ...group.tags.map(
                            (t) => Chip(
                              label: Text(t),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          Chip(
                            avatar: const Icon(Icons.people_outline, size: 18),
                            label: Text('${group.memberCount} 成员'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
