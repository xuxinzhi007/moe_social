import 'package:flutter/material.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/moe_toast.dart';

class InterestGroup {
  final String id;
  final String name;
  final String description;
  final String coverImage;
  final int memberCount;
  final int postCount;
  final bool isJoined;
  final List<String> tags;

  const InterestGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImage,
    required this.memberCount,
    required this.postCount,
    required this.isJoined,
    required this.tags,
  });
}

class InterestGroupsPage extends StatefulWidget {
  const InterestGroupsPage({super.key});

  @override
  State<InterestGroupsPage> createState() => _InterestGroupsPageState();
}

class _InterestGroupsPageState extends State<InterestGroupsPage> {
  List<InterestGroup> _groups = [
    InterestGroup(
      id: '1',
      name: '摄影爱好者',
      description: '分享摄影技巧和作品，交流拍摄心得',
      coverImage: 'https://picsum.photos/800/450?random=10',
      memberCount: 1245,
      postCount: 3567,
      isJoined: true,
      tags: ['摄影', '艺术', '户外'],
    ),
    InterestGroup(
      id: '2',
      name: '美食分享',
      description: '分享美食制作方法和餐厅推荐',
      coverImage: 'https://picsum.photos/800/450?random=11',
      memberCount: 2341,
      postCount: 5678,
      isJoined: false,
      tags: ['美食', '烹饪', '餐厅'],
    ),
    InterestGroup(
      id: '3',
      name: '旅行日记',
      description: '分享旅行经历和攻略，寻找旅行伙伴',
      coverImage: 'https://picsum.photos/800/450?random=12',
      memberCount: 1890,
      postCount: 4321,
      isJoined: false,
      tags: ['旅行', '攻略', '分享'],
    ),
    InterestGroup(
      id: '4',
      name: '读书俱乐部',
      description: '分享读书心得，讨论书中的精彩内容',
      coverImage: 'https://picsum.photos/800/450?random=13',
      memberCount: 987,
      postCount: 2345,
      isJoined: true,
      tags: ['读书', '文学', '讨论'],
    ),
    InterestGroup(
      id: '5',
      name: '健身达人',
      description: '分享健身技巧，互相鼓励，共同进步',
      coverImage: 'https://picsum.photos/800/450?random=14',
      memberCount: 1567,
      postCount: 3456,
      isJoined: false,
      tags: ['健身', '运动', '健康'],
    ),
  ];

  List<InterestGroup> _filteredGroups = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredGroups = _groups;
  }

  void _filterGroups(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredGroups = _groups;
      } else {
        _filteredGroups = _groups.where((group) =>
          group.name.toLowerCase().contains(query.toLowerCase()) ||
          group.description.toLowerCase().contains(query.toLowerCase()) ||
          group.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()))
        ).toList();
      }
    });
  }

  void _toggleJoinGroup(InterestGroup group) {
    setState(() {
      final index = _groups.indexOf(group);
      if (index != -1) {
        _groups[index] = InterestGroup(
          id: group.id,
          name: group.name,
          description: group.description,
          coverImage: group.coverImage,
          memberCount: group.isJoined ? group.memberCount - 1 : group.memberCount + 1,
          postCount: group.postCount,
          isJoined: !group.isJoined,
          tags: group.tags,
        );
        _filteredGroups = _searchQuery.isEmpty ? _groups : _groups.where((g) =>
          g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()))
        ).toList();
      }
    });
    MoeToast.success(
      context,
      group.isJoined ? '已退出群组' : '已加入群组',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _filteredGroups.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredGroups.length,
                    itemBuilder: (context, index) {
                      return _buildGroupCard(_filteredGroups[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 实现创建群组功能
        },
        backgroundColor: const Color(0xFF42A5F5),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MoeSearchBar(
        hintText: '搜索兴趣群组',
        onSearch: _filterGroups,
        onClear: () => _filterGroups(''),
      ),
    );
  }

  Widget _buildGroupCard(InterestGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              group.coverImage,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _toggleJoinGroup(group),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: group.isJoined ? Colors.grey[200] : const Color(0xFF42A5F5),
                        foregroundColor: group.isJoined ? Colors.grey[700] : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      ),
                      child: Text(group.isJoined ? '已加入' : '加入'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  group.description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: group.tags.map((tag) => Chip(
                    label: Text(tag),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor: Colors.grey[100],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} 成员',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Row(
                      children: [
                        const Icon(Icons.post_add_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${group.postCount} 帖子',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
              color: const Color(0xFF42A5F5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_rounded,
              size: 64,
              color: Color(0xFF42A5F5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '没有找到相关群组',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试使用其他关键词搜索',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
