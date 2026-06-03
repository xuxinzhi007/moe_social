import 'package:flutter/material.dart';

import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/fade_in_up.dart';
import '../notifications/notification_center_page.dart';
import 'discover_match_tab.dart';
import 'discover_play_tab.dart';

/// 历史探索页：同好匹配与玩法入口（AI 酒馆、小游戏）。
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: moe.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeInUp(
              duration: MoeTokens.motionFadeDuration,
              child: _buildHeader(context, scheme),
            ),
            FadeInUp(
              duration: MoeTokens.motionFadeDuration,
              delay: MoeTokens.motionStaggerStep,
              child: _buildSegmented(context, scheme),
            ),
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

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
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
                    color: scheme.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '匹配同好，或试试酒馆与小游戏',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
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
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmented(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: MoeTheme.of(context).cardBackground,
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
            Tab(text: '同好'),
            Tab(text: '玩法'),
          ],
        ),
      ),
    );
  }
}
