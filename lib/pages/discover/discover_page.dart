import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/main_nav_controller.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../notifications/notification_center_page.dart';
import 'discover_match_tab.dart';
import 'discover_play_tab.dart';

/// 底栏「探索」：同好匹配与玩法入口（AI 酒馆、小游戏）。
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late final MainNavController _mainNav;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _mainNav = context.read<MainNavController>();
    _mainNav.addListener(_onMainNavRequested);
    _applyExploreSubTab(_mainNav.consumeExploreSubTab());
  }

  @override
  void dispose() {
    _mainNav.removeListener(_onMainNavRequested);
    _tabController.dispose();
    super.dispose();
  }

  void _onMainNavRequested() {
    _applyExploreSubTab(_mainNav.consumeExploreSubTab());
  }

  void _applyExploreSubTab(int? subTab) {
    if (!mounted || subTab == null) return;
    if (subTab < 0 || subTab >= _tabController.length) return;
    if (_tabController.index == subTab) return;
    _tabController.animateTo(subTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiBrandTokens.chatBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildSegmented(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  DiscoverMatchTab(),
                  DiscoverPlayTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '探索',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AiBrandTokens.titleColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '匹配同好，或试试酒馆与小游戏',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '通知',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationCenterPage(),
              ),
            ),
            icon: Icon(
              Icons.notifications_outlined,
              color: AiBrandTokens.titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmented() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
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
            color: AiBrandTokens.primary.withValues(alpha: 0.12),
          ),
          labelColor: AiBrandTokens.primary,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: '同好'),
            Tab(text: '玩法'),
          ],
        ),
      ),
    );
  }
}
