import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth_service.dart';
import '../../models/community_group.dart';
import '../../services/community_service.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import 'community_search_chrome.dart';

/// 圈子搜索。输入框和空态与讨论搜索共用 [CommunitySearchField]。
class InterestGroupSearchPage extends StatefulWidget {
  const InterestGroupSearchPage({super.key});

  @override
  State<InterestGroupSearchPage> createState() =>
      _InterestGroupSearchPageState();
}

class _InterestGroupSearchPageState extends State<InterestGroupSearchPage> {
  static const Duration _debounce = Duration(milliseconds: 320);

  final TextEditingController _query = TextEditingController();
  Timer? _debounceTimer;
  int _requestSeq = 0;
  List<CommunityGroup> _groups = const [];
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounceTimer?.cancel();
    final keyword = _query.text.trim();
    if (keyword.isEmpty) {
      _requestSeq++;
      setState(() {
        _groups = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {});
    _debounceTimer = Timer(_debounce, () => _search(keyword));
  }

  Future<void> _search(String keyword) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await CommunityService.getCommunityGroups(
        page: 1,
        pageSize: 40,
        keyword: keyword,
        userId: AuthService.currentUser,
      );
      if (!mounted || seq != _requestSeq) return;
      final raw = res['groups'] as List<Map<String, dynamic>>;
      setState(() {
        _groups = raw.map(CommunityGroup.fromApi).toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _openGroup(CommunityGroup group) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(
      context,
      '/community/group',
      arguments: {'groupId': group.id, 'group': group},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: MoeTokens.surface1,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: CommunitySearchField(
          controller: _query,
          hintText: '搜索群组名称或简介',
          onSubmitted: (value) {
            _debounceTimer?.cancel();
            final keyword = value.trim();
            if (keyword.isEmpty) return;
            _search(keyword);
          },
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              tooltip: '清除',
              onPressed: _query.clear,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final keyword = _query.text.trim();
    if (keyword.isEmpty) {
      return const CommunitySearchHint(
        icon: Icons.travel_explore_rounded,
        title: '搜索圈子',
        subtitle: '输入群组名称或简介',
      );
    }
    if (_loading && _groups.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_error != null && _groups.isEmpty) {
      return Center(
        child: MoeErrorState.fromError(
          _error,
          scene: MoeErrorScene.community,
          onRetry: () => _search(keyword),
        ),
      );
    }
    if (_groups.isEmpty) {
      return const CommunitySearchHint(
        icon: Icons.search_off_rounded,
        title: '没有匹配的圈子',
        subtitle: '换个关键词试试',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final group = _groups[index];
        final caption = group.description.trim().isEmpty
            ? '${group.memberCount} 人'
            : group.description.trim();
        return Material(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          child: InkWell(
            onTap: () => _openGroup(group),
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                border: Border.all(color: MoeTokens.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MoeTokens.titleText,
                      fontSize: MoeTokens.textBase,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MoeTokens.hintText,
                      fontSize: MoeTokens.textSm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
