import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/post_service.dart';
import '../../widgets/moe_loading.dart';
import '../feed/comments_page.dart';

/// 社区 / 话题流进入的 **动态详情**：顶部完整 [PostCard]（手绘、多图、话题）与首页一致，底部评论区与发帖闭环复用 [CommentsPage]。
class CommunityPostDetailPage extends StatefulWidget {
  const CommunityPostDetailPage({
    super.key,
    required this.postId,
    this.initialPost,
  });

  final String postId;
  final Post? initialPost;

  @override
  State<CommunityPostDetailPage> createState() => _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  Post? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _loadPost();
  }

  String _err(Object e) {
    if (e is ApiException) return e.message;
    return '加载失败';
  }

  Future<void> _loadPost() async {
    if (_post == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final p = await PostService.getPostById(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = p ?? _post;
        _loading = false;
        if (_post == null) _error = '找不到该动态';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _err(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _post == null) {
      return const Scaffold(body: Center(child: MoeLoading()));
    }
    if (_error != null && _post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('动态')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadPost, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }
    final post = _post!;
    return CommentsPage(
      key: ValueKey('post_detail_${post.id}'),
      postId: post.id,
      embeddedPost: post,
      onRefreshPreamble: _loadPost,
    );
  }
}
