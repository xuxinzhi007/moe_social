import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/moe_toast.dart';
import '../../utils/media_url.dart';

class InterestGroup {
  InterestGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImage,
    required this.memberCount,
    required this.isJoined,
    required this.isPublic,
    required this.tags,
  });

  final String id;
  final String name;
  final String description;
  final String coverImage;
  final int memberCount;
  final bool isJoined;
  final bool isPublic;
  final List<String> tags;

  factory InterestGroup.fromApi(Map<String, dynamic> m) {
    final cover = (m['cover'] ?? m['avatar'] ?? '').toString();
    return InterestGroup(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      coverImage: cover,
      memberCount: (m['member_count'] is int)
          ? m['member_count'] as int
          : int.tryParse('${m['member_count'] ?? 0}') ?? 0,
      isJoined: m['is_joined'] == true,
      isPublic: m['is_public'] != false,
      tags: <String>[m['is_public'] == false ? '私密' : '公开'],
    );
  }
}

class InterestGroupsPage extends StatefulWidget {
  const InterestGroupsPage({super.key});

  @override
  State<InterestGroupsPage> createState() => _InterestGroupsPageState();
}

class _InterestGroupsPageState extends State<InterestGroupsPage> {
  final List<InterestGroup> _groups = [];
  bool _loading = true;
  String? _error;
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

  String _err(Object e) {
    if (e is ApiException) return e.message;
    return '加载失败';
  }

  Future<void> _load({String? keyword}) async {
    setState(() {
      _loading = true;
      _error = null;
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
          ..addAll(raw.map(InterestGroup.fromApi));
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

  void _scheduleSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _keyword = q.trim();
      _load(keyword: _keyword.isEmpty ? null : _keyword);
    });
  }

  Future<void> _toggleJoin(InterestGroup g) async {
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
      if (mounted) MoeToast.error(context, _err(e));
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
        formatError: _err,
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
    final blocking = _loading && _groups.isEmpty && _error == null;
    final showListProgress = _loading && _groups.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerLowest,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_2_outlined,
                                  size: 48, color: scheme.outline),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                  onPressed: () => _load(),
                                  child: const Text('重试')),
                            ],
                          ),
                        ),
                      )
                    : blocking
                        ? const Center(child: MoeLoading())
                        : RefreshIndicator(
                            color: const Color(0xFF7F7FD5),
                            onRefresh: () => _load(
                                keyword:
                                    _keyword.isEmpty ? null : _keyword),
                            child: _groups.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height: MediaQuery.sizeOf(context)
                                                .height *
                                            0.35,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.group_add_rounded,
                                                  size: 56,
                                                  color:
                                                      Colors.grey.shade400),
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
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 88),
                                    itemCount: _groups.length,
                                    itemBuilder: (context, i) => _GroupCard(
                                      group: _groups[i],
                                      onJoin: () => _toggleJoin(_groups[i]),
                                    ),
                                  ),
                          ),
              ),
            ],
          ),
          if (!blocking)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _showCreateGroup,
                icon: const Icon(Icons.add_rounded),
                label: const Text('新建群组'),
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

/// 控制器生命周期与底部路由一致，在关闭动画结束并从树移除后再 [dispose]，避免
/// `TextEditingController was used after being disposed`（与 [AnimatedPadding] 等并存时常见）。
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
      if (mounted) {
        MoeToast.error(context, widget.formatError(e));
      }
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
                '创建后可在服务端管理成员与帖子（与动态发帖不同）。',
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
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _isPublic = v),
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
  const _GroupCard({required this.group, required this.onJoin});

  final InterestGroup group;
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
        child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
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
                            color: scheme.primary.withOpacity(0.08),
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
                            onPressed: onJoin,
                            style: FilledButton.styleFrom(
                              backgroundColor: group.isJoined
                                  ? scheme.surfaceContainerHighest
                                  : scheme.primary.withOpacity(0.12),
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
    );
  }
}
