import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../widgets/moe_bottom_bar.dart';
import 'content_sharing_page.dart';
import 'interest_groups_page.dart';
import 'topic_discussions_page.dart';

/// 兴趣社区：与「首页」关系 — 首页是个人/关注信息流；此处是 **群组 + 话题帖子流 + 广场形态筛选**。
/// 「发现」负责 AI/小游戏/匹配等扩展能力，与社区入口在 [DiscoverPage] 中互相链出，避免重复堆叠。
class CommunityHomePage extends StatefulWidget {
  const CommunityHomePage({super.key});

  @override
  State<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends State<CommunityHomePage> {
  int _currentIndex = 0;

  late final List<Widget> _pages = const [
    InterestGroupsPage(),
    TopicDiscussionsPage(),
    ContentSharingPage(),
  ];

  String get _subtitle {
    switch (_currentIndex) {
      case 0:
        return '发现同好圈子，加入或创建群组';
      case 1:
        return '按话题浏览全站动态，与首页内容同源';
      case 2:
      default:
        return '逛广场：按形态筛选帖子';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scheme.surface,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.forum_rounded,
                      color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  '兴趣社区',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: scheme.onSurface,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 2),
              child: Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '与首页的关系',
            icon: Icon(Icons.dynamic_feed_rounded, color: scheme.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('首页是个人/关注信息流；社区是群组与话题广场。请用底栏「首页」返回动态。'),
                  duration: Duration(seconds: 4),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: '快捷操作',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onSelected: (v) {
              if (!AuthService.isLoggedIn) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先登录')),
                );
                return;
              }
              if (v == 'post') {
                Navigator.pushNamed(context, '/create-post');
              } else if (v == 'group') {
                setState(() => _currentIndex = 0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已切换到「兴趣群组」，请点右下角「新建群组」'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'post',
                child: ListTile(
                  leading: Icon(Icons.edit_note_rounded),
                  title: Text('发布动态'),
                  subtitle: Text('与首页发帖同一入口'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'group',
                child: ListTile(
                  leading: Icon(Icons.groups_2_outlined),
                  title: Text('去创建群组'),
                  subtitle: Text('将切换到群组页'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: MoeBottomBar(
        selectedIndex: _currentIndex,
        onItemSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2_rounded),
            label: '兴趣群组',
          ),
          NavigationDestination(
            icon: Icon(Icons.tag_outlined),
            selectedIcon: Icon(Icons.tag_rounded),
            label: '话题讨论',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: '内容广场',
          ),
        ],
      ),
    );
  }
}
