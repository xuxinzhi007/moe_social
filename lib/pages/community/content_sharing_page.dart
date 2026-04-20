import 'package:flutter/material.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/moe_toast.dart';

class SharedContent {
  final String id;
  final String type;
  final String title;
  final String? imageUrl;
  final String? videoUrl;
  final String content;
  final String authorName;
  final String authorAvatar;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime createdAt;
  final bool isLiked;
  final List<String> tags;

  const SharedContent({
    required this.id,
    required this.type,
    required this.title,
    this.imageUrl,
    this.videoUrl,
    required this.content,
    required this.authorName,
    required this.authorAvatar,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.createdAt,
    required this.isLiked,
    required this.tags,
  });
}

class ContentSharingPage extends StatefulWidget {
  const ContentSharingPage({super.key});

  @override
  State<ContentSharingPage> createState() => _ContentSharingPageState();
}

class _ContentSharingPageState extends State<ContentSharingPage> {
  List<SharedContent> _contents = [
    SharedContent(
      id: '1',
      type: 'image',
      title: '今天拍的 sunset',
      imageUrl: 'https://picsum.photos/800/450',
      content: '分享一张今天拍的日落照片，希望大家喜欢！',
      authorName: '摄影师小王',
      authorAvatar: 'https://picsum.photos/100/100?random=1',
      likeCount: 234,
      commentCount: 45,
      shareCount: 12,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isLiked: false,
      tags: ['摄影', '日落', '风景'],
    ),
    SharedContent(
      id: '2',
      type: 'text',
      title: '分享一个学习方法',
      content: '最近发现了一个非常有效的学习方法，就是番茄工作法。每天坚持使用，学习效率提高了很多。具体做法是：25分钟学习，5分钟休息，重复4次后休息15分钟。推荐给大家！',
      authorName: '学习达人',
      authorAvatar: 'https://picsum.photos/100/100?random=2',
      likeCount: 156,
      commentCount: 32,
      shareCount: 8,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      isLiked: true,
      tags: ['学习', '方法', '效率'],
    ),
    SharedContent(
      id: '3',
      type: 'video',
      title: '自制美食视频',
      videoUrl: 'https://example.com/video.mp4',
      content: '今天给大家分享一个简单好吃的家常菜做法，喜欢的朋友可以试试！',
      authorName: '美食博主',
      authorAvatar: 'https://picsum.photos/100/100?random=3',
      likeCount: 345,
      commentCount: 67,
      shareCount: 23,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isLiked: false,
      tags: ['美食', '烹饪', '视频'],
    ),
    SharedContent(
      id: '4',
      type: 'image',
      title: '旅行中的意外发现',
      imageUrl: 'https://picsum.photos/800/450?random=4',
      content: '在旅行中偶然发现的一个小众景点，人少景美，推荐给喜欢旅行的朋友！',
      authorName: '旅行爱好者',
      authorAvatar: 'https://picsum.photos/100/100?random=5',
      likeCount: 189,
      commentCount: 28,
      shareCount: 15,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isLiked: true,
      tags: ['旅行', '景点', '分享'],
    ),
  ];

  List<SharedContent> _filteredContents = [];
  String _searchQuery = '';
  String _contentType = 'all';

  @override
  void initState() {
    super.initState();
    _filteredContents = _contents;
  }

  void _filterContents(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _selectContentType(String type) {
    setState(() {
      _contentType = type;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredContents = _contents.where((content) {
      final matchesSearch = _searchQuery.isEmpty ||
          content.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          content.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          content.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesType = _contentType == 'all' || content.type == _contentType;
      return matchesSearch && matchesType;
    }).toList();
  }

  void _toggleLike(SharedContent content) {
    setState(() {
      final index = _contents.indexOf(content);
      if (index != -1) {
        _contents[index] = SharedContent(
          id: content.id,
          type: content.type,
          title: content.title,
          imageUrl: content.imageUrl,
          videoUrl: content.videoUrl,
          content: content.content,
          authorName: content.authorName,
          authorAvatar: content.authorAvatar,
          likeCount: content.isLiked ? content.likeCount - 1 : content.likeCount + 1,
          commentCount: content.commentCount,
          shareCount: content.shareCount,
          createdAt: content.createdAt,
          isLiked: !content.isLiked,
          tags: content.tags,
        );
        _applyFilters();
      }
    });
    MoeToast.success(
      context,
      content.isLiked ? '已取消点赞' : '点赞成功',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          _buildContentTypeFilter(),
          Expanded(
            child: _filteredContents.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredContents.length,
                    itemBuilder: (context, index) {
                      return _buildContentCard(_filteredContents[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 实现创建内容功能
        },
        backgroundColor: const Color(0xFF66BB6A),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MoeSearchBar(
        hintText: '搜索内容',
        onSearch: _filterContents,
        onClear: () => _filterContents(''),
      ),
    );
  }

  Widget _buildContentTypeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          final types = [
            {'id': 'all', 'label': '全部', 'icon': Icons.grid_view_rounded},
            {'id': 'image', 'label': '图片', 'icon': Icons.image_rounded},
            {'id': 'video', 'label': '视频', 'icon': Icons.video_camera_front_rounded},
            {'id': 'text', 'label': '文字', 'icon': Icons.text_snippet_rounded},
          ];
          final type = types[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(type['icon'] as IconData, size: 16),
              label: Text(type['label'] as String),
              selected: _contentType == type['id'],
              onSelected: (_) => _selectContentType(type['id'] as String),
              selectedColor: const Color(0xFF66BB6A).withOpacity(0.1),
              checkmarkColor: const Color(0xFF66BB6A),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentCard(SharedContent content) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  content.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (content.videoUrl != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.grey[200],
              ),
              child: const Center(
                child: Icon(Icons.play_circle_rounded, size: 64, color: Colors.grey),
              ),
            ),
          Container(
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
                          image: NetworkImage(content.authorAvatar),
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
                            content.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatTime(content.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  content.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: content.tags.map((tag) => Chip(
                    label: Text('#$tag'),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor: Colors.grey[100],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _toggleLike(content),
                          icon: Icon(
                            content.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: content.isLiked ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                        ),
                        Text(
                          '${content.likeCount}',
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
                          '${content.commentCount}',
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
                            // 分享功能
                          },
                          icon: const Icon(
                            Icons.share_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                        Text(
                          '${content.shareCount}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
              color: const Color(0xFF66BB6A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.share_rounded,
              size: 64,
              color: Color(0xFF66BB6A),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '没有找到相关内容',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试使用其他关键词搜索或分享新的内容',
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
