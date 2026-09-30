import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post_search_hit.dart';
import '../../services/post_service.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import 'community_search_chrome.dart';

/// 兴趣社区搜索：独立页，按正文、昵称或话题检索公开动态。
class CommunityPostSearchPage extends StatefulWidget {
  const CommunityPostSearchPage({super.key});

  @override
  State<CommunityPostSearchPage> createState() =>
      _CommunityPostSearchPageState();
}

class _CommunityPostSearchPageState extends State<CommunityPostSearchPage> {
  static const Duration _debounce = Duration(milliseconds: 320);

  final TextEditingController _query = TextEditingController();
  Timer? _debounceTimer;
  int _requestSeq = 0;
  List<PostSearchHit> _hits = const [];
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
        _hits = const [];
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
      final hits = await PostService.searchPosts(query: keyword);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _hits = hits;
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

  void _openHit(PostSearchHit hit) {
    if (hit.postId.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.pushNamed(
      context,
      '/post-detail',
      arguments: {'postId': hit.postId},
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
          hintText: '搜索正文、昵称或话题',
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
        title: '搜索广场动态',
        subtitle: '输入正文、昵称或话题',
      );
    }
    if (_loading && _hits.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_error != null && _hits.isEmpty) {
      return Center(
        child: MoeErrorState.fromError(
          _error,
          scene: MoeErrorScene.community,
          onRetry: () => _search(keyword),
        ),
      );
    }
    if (_hits.isEmpty) {
      return const CommunitySearchHint(
        icon: Icons.search_off_rounded,
        title: '没有匹配的动态',
        subtitle: '换个关键词试试',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      itemCount: _hits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final hit = _hits[index];
        return _SearchResultRow(hit: hit, onTap: () => _openHit(hit));
      },
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.hit, required this.onTap});

  final PostSearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = hit.snippet.trim().isEmpty ? '查看这条动态' : hit.snippet.trim();
    return Material(
      color: MoeTokens.surface1,
      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      child: InkWell(
        onTap: onTap,
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
                hit.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MoeTokens.titleText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MoeTokens.caption,
                  fontSize: MoeTokens.textSm,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${hit.likes} 赞 · ${hit.comments} 评论',
                style: const TextStyle(
                  color: MoeTokens.hintText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
