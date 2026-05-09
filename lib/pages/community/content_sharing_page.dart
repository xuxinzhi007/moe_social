import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../widgets/moe_toast.dart';
import 'community_posts_feed.dart';

/// 内容广场：全站帖子流 + 形态筛选，与首页推荐形成互补（此处偏「逛广场」）。
class ContentSharingPage extends StatelessWidget {
  const ContentSharingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: const CommunityPostsFeed(
        topicTagId: null,
        showTextSearch: true,
        showVisualKindRow: true,
        emptyTitle: '暂无内容',
        emptySubtitle: '下拉刷新试试，或去发一条动态',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!AuthService.isLoggedIn) {
            MoeToast.error(context, '请先登录后再发帖');
            return;
          }
          Navigator.pushNamed(context, '/create-post');
        },
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('发动态'),
        backgroundColor: const Color(0xFF66BB6A),
        foregroundColor: Colors.white,
      ),
    );
  }
}
