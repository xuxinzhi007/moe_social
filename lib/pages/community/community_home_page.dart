import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../widgets/moe_toast.dart';
import 'community_discussions_tab.dart';
import 'interest_groups_page.dart';

/// 兴趣社区：圈子 + 讨论广场；与首页分工 — 首页偏关注/算法流，此处偏群组与同好内容发现。
class CommunityHomePage extends StatefulWidget {
  const CommunityHomePage({super.key});

  @override
  State<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends State<CommunityHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<InterestGroupsPageState> _groupsKey =
      GlobalKey<InterestGroupsPageState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _subtitle {
    switch (_tabController.index) {
      case 0:
        return '发现同好圈子，加入一起讨论';
      case 1:
      default:
        return '按话题逛广场，发现新内容';
    }
  }

  void _onFabPressed() {
    if (!AuthService.isLoggedIn) {
      MoeToast.error(context, '请先登录');
      return;
    }
    if (_tabController.index == 0) {
      _groupsKey.currentState?.showCreateGroup();
    } else {
      Navigator.pushNamed(context, '/create-post');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onCirclesTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(scheme),
            _buildSegmented(scheme),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  InterestGroupsPage(key: _groupsKey),
                  const CommunityDiscussionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFabPressed,
        icon: Icon(onCirclesTab ? Icons.add_rounded : Icons.edit_rounded),
        label: Text(onCirclesTab ? '新建群组' : '发帖'),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '兴趣社区',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _subtitle,
              key: ValueKey<String>(_subtitle),
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmented(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: scheme.primary.withValues(alpha: 0.12),
          ),
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: '圈子'),
            Tab(text: '讨论'),
          ],
        ),
      ),
    );
  }
}
