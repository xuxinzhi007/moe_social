import 'package:flutter/material.dart';
import '../../widgets/moe_bottom_bar.dart';
import 'interest_groups_page.dart';
import 'topic_discussions_page.dart';
import 'content_sharing_page.dart';

class CommunityHomePage extends StatefulWidget {
  const CommunityHomePage({super.key});

  @override
  State<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends State<CommunityHomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const InterestGroupsPage(),
    const TopicDiscussionsPage(),
    const ContentSharingPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _pages[_currentIndex],
      bottomNavigationBar: MoeBottomBar(
        selectedIndex: _currentIndex,
        onItemSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.group_rounded),
            selectedIcon: Icon(Icons.group_rounded),
            label: '兴趣群组',
          ),
          NavigationDestination(
            icon: Icon(Icons.topic_rounded),
            selectedIcon: Icon(Icons.topic_rounded),
            label: '话题讨论',
          ),
          NavigationDestination(
            icon: Icon(Icons.share_rounded),
            selectedIcon: Icon(Icons.share_rounded),
            label: '内容分享',
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_rounded,
              color: scheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '兴趣社区',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            // 实现搜索功能
          },
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: () {
            // 实现创建功能
          },
        ),
      ],
    );
  }
}
