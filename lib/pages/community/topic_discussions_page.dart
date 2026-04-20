import 'package:flutter/material.dart';
import '../../models/topic_tag.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/moe_toast.dart';

class TopicDiscussion {
  final String id;
  final TopicTag topic;
  final String title;
  final String content;
  final String authorName;
  final String authorAvatar;
  final int commentCount;
  final int likeCount;
  final DateTime createdAt;
  final bool isLiked;

  const TopicDiscussion({
    required this.id,
    required this.topic,
    required this.title,
    required this.content,
    required this.authorName,
    required this.authorAvatar,
    required this.commentCount,
    required this.likeCount,
    required this.createdAt,
    required this.isLiked,
  });
}

class TopicDiscussionsPage extends StatefulWidget {
  const TopicDiscussionsPage({super.key});

  @override
  State<TopicDiscussionsPage> createState() => _TopicDiscussionsPageState();
}

class _TopicDiscussionsPageState extends State<TopicDiscussionsPage> {
  List<TopicDiscussion> _discussions = [
    TopicDiscussion(
      id: '1',
      topic: TopicTag.officialTags[0], // 日常生活
      title: '分享一下你们最近的生活状态',
      content: '最近工作压力有点大，想听听大家都是怎么调节的。平时喜欢做些什么来放松自己呢？',
      authorName: '小明',
      authorAvatar: 'https://picsum.photos/100/100?random=20',
      commentCount: 45,
      likeCount: 128,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isLiked: false,
    ),
    TopicDiscussion(
      id: '2',
      topic: TopicTag.officialTags[2], // 美食分享
      title: '推荐一道你最拿手的家常菜',
      content: '最近想尝试一些新的家常菜，大家有什么推荐吗？最好是简单易做的那种。',
      authorName: '小红',
      authorAvatar: 'https://picsum.photos/100/100?random=21',
      commentCount: 67,
      likeCount: 234,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isLiked: true,
    ),
    TopicDiscussion(
      id: '3',
      topic: TopicTag.officialTags[3], // 旅行记录
      title: '今年最想去的旅行目的地',
      content: '疫情过后，大家最想去哪里旅行？我想去云南，听说那里的风景特别美。',
      authorName: '小李',
      authorAvatar: 'https://picsum.photos/100/100?random=22',
      commentCount: 89,
      likeCount: 345,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isLiked: false,
    ),
    TopicDiscussion(
      id: '4',
      topic: TopicTag.officialTags[5], // 学习笔记
      title: '分享一下你们的学习方法',
      content: '最近在准备考试，感觉效率不高，大家有什么好的学习方法推荐吗？',
      authorName: '小张',
      authorAvatar: 'https://picsum.photos/100/100?random=23',
      commentCount: 34,
      likeCount: 98,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isLiked: true,
    ),
  ];

  List<TopicDiscussion> _filteredDiscussions = [];
  String _searchQuery = '';
  TopicTag? _selectedTopic;

  @override
  void initState() {
    super.initState();
    _filteredDiscussions = _discussions;
  }

  void _filterDiscussions(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _selectTopic(TopicTag? topic) {
    setState(() {
      _selectedTopic = topic;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredDiscussions = _discussions.where((discussion) {
      final matchesSearch = _searchQuery.isEmpty ||
          discussion.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          discussion.content.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTopic = _selectedTopic == null || discussion.topic.id == _selectedTopic!.id;
      return matchesSearch && matchesTopic;
    }).toList();
  }

  void _toggleLike(TopicDiscussion discussion) {
    setState(() {
      final index = _discussions.indexOf(discussion);
      if (index != -1) {
        _discussions[index] = TopicDiscussion(
          id: discussion.id,
          topic: discussion.topic,
          title: discussion.title,
          content: discussion.content,
          authorName: discussion.authorName,
          authorAvatar: discussion.authorAvatar,
          commentCount: discussion.commentCount,
          likeCount: discussion.isLiked ? discussion.likeCount - 1 : discussion.likeCount + 1,
          createdAt: discussion.createdAt,
          isLiked: !discussion.isLiked,
        );
        _applyFilters();
      }
    });
    MoeToast.success(
      context,
      discussion.isLiked ? '已取消点赞' : '点赞成功',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTopicFilter(),
          Expanded(
            child: _filteredDiscussions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredDiscussions.length,
                    itemBuilder: (context, index) {
                      return _buildDiscussionCard(_filteredDiscussions[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 实现创建话题功能
        },
        backgroundColor: const Color(0xFFAB47BC),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MoeSearchBar(
        hintText: '搜索话题讨论',
        onSearch: _filterDiscussions,
        onClear: () => _filterDiscussions(''),
      ),
    );
  }

  Widget _buildTopicFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: TopicTag.officialTags.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('全部'),
                selected: _selectedTopic == null,
                onSelected: (_) => _selectTopic(null),
                selectedColor: const Color(0xFFAB47BC).withOpacity(0.1),
                checkmarkColor: const Color(0xFFAB47BC),
              ),
            );
          }
          final topic = TopicTag.officialTags[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('#${topic.name}'),
              selected: _selectedTopic?.id == topic.id,
              onSelected: (_) => _selectTopic(topic),
              selectedColor: topic.color.withOpacity(0.1),
              checkmarkColor: topic.color,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscussionCard(TopicDiscussion discussion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(discussion.authorAvatar),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      discussion.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatTime(discussion.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text('#${discussion.topic.name}'),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: discussion.topic.color,
                ),
                backgroundColor: discussion.topic.color.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            discussion.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            discussion.content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _toggleLike(discussion),
                    icon: Icon(
                      discussion.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: discussion.isLiked ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                  ),
                  Text(
                    '${discussion.likeCount}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      // 跳转到评论页面
                    },
                    icon: const Icon(
                      Icons.comment_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                  Text(
                    '${discussion.commentCount}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  // 分享功能
                },
                icon: const Icon(
                  Icons.share_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFAB47BC).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.topic_rounded,
              size: 64,
              color: Color(0xFFAB47BC),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '没有找到相关讨论',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试使用其他关键词搜索或创建新的讨论',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}
