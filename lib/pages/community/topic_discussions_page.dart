import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../models/topic_tag.dart';
import '../../widgets/moe_toast.dart';
import 'community_posts_feed.dart';

/// 话题讨论：与首页动态同一数据源（[ApiService.getPosts]），按官方话题筛选；发动态与首页闭环一致。
class TopicDiscussionsPage extends StatefulWidget {
  const TopicDiscussionsPage({super.key});

  @override
  State<TopicDiscussionsPage> createState() => _TopicDiscussionsPageState();
}

class _TopicDiscussionsPageState extends State<TopicDiscussionsPage> {
  TopicTag? _selectedTopic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Column(
        children: [
          _buildTopicChips(scheme),
          Expanded(
            child: CommunityPostsFeed(
              key: ValueKey<String?>(_selectedTopic?.id),
              topicTagId: _selectedTopic?.id,
              showTextSearch: true,
              emptyTitle: '暂无相关讨论',
              emptySubtitle: _selectedTopic == null
                  ? '下拉刷新，或去首页看看最新动态'
                  : '该话题下还没有帖子，做第一个发帖的人吧',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!AuthService.isLoggedIn) {
            MoeToast.error(context, '请先登录后再发帖');
            return;
          }
          Navigator.pushNamed(context, '/create-post');
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('发帖'),
        backgroundColor: const Color(0xFFAB47BC),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTopicChips(ColorScheme scheme) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        itemCount: TopicTag.officialTags.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final sel = _selectedTopic == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('全部'),
                selected: sel,
                onSelected: (_) => setState(() => _selectedTopic = null),
                selectedColor: scheme.primary.withOpacity(0.14),
                checkmarkColor: scheme.primary,
              ),
            );
          }
          final topic = TopicTag.officialTags[index - 1];
          final sel = _selectedTopic?.id == topic.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('#${topic.name}'),
              selected: sel,
              onSelected: (_) => setState(() => _selectedTopic = topic),
              selectedColor: topic.color.withOpacity(0.14),
              checkmarkColor: topic.color,
            ),
          );
        },
      ),
    );
  }
}
