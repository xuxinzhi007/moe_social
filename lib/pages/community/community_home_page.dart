import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../widgets/moe_bottom_bar.dart';
import '../../widgets/moe_toast.dart';
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

  Widget _buildHeaderActionShell({
    required Widget child,
    required ColorScheme scheme,
  }) {
    return Container(
      height: 34,
      width: 34,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
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
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.forum_rounded,
                      color: scheme.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  '兴趣社区',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: scheme.onSurface,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                _subtitle,
                key: ValueKey<String>(_subtitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.95),
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _buildHeaderActionShell(
            scheme: scheme,
            child: IconButton(
              tooltip: '与首页的关系',
              icon: Icon(
                Icons.tips_and_updates_rounded,
                color: scheme.primary.withValues(alpha: 0.9),
                size: 18,
              ),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              onPressed: () {
                MoeToast.info(
                  context,
                  '首页是个人/关注信息流；社区是群组与话题广场。请用底栏「首页」返回动态。',
                );
              },
            ),
          ),
          _buildHeaderActionShell(
            scheme: scheme,
            child: PopupMenuButton<String>(
              tooltip: '快捷操作',
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.add_rounded,
                color: scheme.primary.withValues(alpha: 0.9),
                size: 20,
              ),
              onSelected: (v) {
                if (!AuthService.isLoggedIn) {
                  MoeToast.error(context, '请先登录');
                  return;
                }
                if (v == 'post') {
                  Navigator.pushNamed(context, '/create-post');
                } else if (v == 'group') {
                  setState(() => _currentIndex = 0);
                  MoeToast.success(
                    context,
                    '已切换到「兴趣群组」，请点右下角「新建群组」',
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
          ),
          const SizedBox(width: 8),
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
