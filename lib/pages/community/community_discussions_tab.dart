import 'package:flutter/material.dart';

import '../../models/topic_tag.dart';
import 'community_posts_feed.dart';

/// 讨论 Tab：话题 Chip + 形态筛选 + 广场帖子流（与首页分工：此处偏「逛广场」）。
class CommunityDiscussionsTab extends StatefulWidget {
  const CommunityDiscussionsTab({super.key});

  @override
  State<CommunityDiscussionsTab> createState() =>
      _CommunityDiscussionsTabState();
}

class _CommunityDiscussionsTabState extends State<CommunityDiscussionsTab> {
  TopicTag? _selectedTopic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      child: Column(
        children: [
          _buildTopicChips(scheme),
          Expanded(
            child: CommunityPostsFeed(
              key: ValueKey<String?>(_selectedTopic?.id),
              topicTagId: _selectedTopic?.id,
              showTextSearch: true,
              showVisualKindRow: true,
              emptyTitle: '广场还没有内容',
              emptySubtitle: '选一个话题标签，或发第一条动态',
            ),
          ),
        ],
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
                selectedColor: scheme.primary.withValues(alpha: 0.14),
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
              selectedColor: topic.color.withValues(alpha: 0.14),
              checkmarkColor: topic.color,
            ),
          );
        },
      ),
    );
  }
}
