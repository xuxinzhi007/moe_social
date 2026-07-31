import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'deferred_route.dart';
import '../pages/feed/home_page.dart';
import '../pages/ai/companion_hub_page.dart' deferred as companion_hub;
import '../pages/chat/message_center_page.dart' deferred as message_center;
import '../pages/profile/profile_page.dart' deferred as profile;
import '../providers/main_nav_controller.dart';
import '../providers/notification_provider.dart';
import '../services/chat_push_service.dart';
import '../services/startup_update_service.dart';
import '../widgets/moe_bottom_bar.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  late final MainNavController _mainNav;
  late final List<Widget Function()> _pageBuilders = [
    () => const HomePage(),
    () => DeferredRoute(
          loadLibrary: message_center.loadLibrary,
          builder: () => message_center.MessageCenterPage(),
          message: '正在加载消息…',
        ),
    () => DeferredRoute(
          loadLibrary: companion_hub.loadLibrary,
          builder: () => companion_hub.CompanionHubPage(),
          message: '正在加载 AI 伙伴…',
        ),
    () => DeferredRoute(
          loadLibrary: profile.loadLibrary,
          builder: () => profile.ProfilePage(),
          message: '正在加载我的页面…',
        ),
  ];
  late final List<Widget?> _loadedPages =
      List<Widget?>.filled(_pageBuilders.length, null, growable: false);

  @override
  void initState() {
    super.initState();
    _mainNav = context.read<MainNavController>();
    _mainNav.addListener(_onMainNavRequested);
    _loadedPages[_selectedIndex] = _pageBuilders[_selectedIndex]();
    // 主界面就绪后再静默检查更新（软更新可稍后；强制更新会拦截）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        unawaited(StartupUpdateService.tryLaunchUpdateCheck());
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ChatPushService.setGlobalContext(context);
  }

  @override
  void dispose() {
    _mainNav.removeListener(_onMainNavRequested);
    ChatPushService.clearGlobalContext();
    super.dispose();
  }

  void _onMainNavRequested() {
    final idx = _mainNav.consumeTabRequest();
    if (!mounted || idx == null) return;
    if (idx < 0 || idx >= _pageBuilders.length) return;
    setState(() {
      _loadedPages[idx] ??= _pageBuilders[idx]();
      _selectedIndex = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          _pageBuilders.length,
          (index) => _loadedPages[index] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: MoeBottomBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (int index) {
          if (index == _selectedIndex) return; // 重复点击不重建
          setState(() {
            _loadedPages[index] ??= _pageBuilders[index]();
            _selectedIndex = index;
          });
        },
        badgeCounts: [
          0,
          notificationProvider.directMessageUnreadCount,
          0,
          0,
        ],
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: '好友',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'AI伙伴',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
