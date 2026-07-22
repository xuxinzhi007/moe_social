import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../pages/ai/game_hub_page.dart';
import '../pages/chat/message_center_page.dart';
import '../pages/feed/home_page.dart';
import '../pages/profile/profile_page.dart';
import '../providers/main_nav_controller.dart';
import '../providers/notification_provider.dart';
import '../services/chat_push_service.dart';
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
    () => const MessageCenterPage(),
    () => const GameHubPage(),
    () => const ProfilePage(),
  ];
  late final List<Widget?> _loadedPages =
      List<Widget?>.filled(_pageBuilders.length, null, growable: false);

  @override
  void initState() {
    super.initState();
    _mainNav = context.read<MainNavController>();
    _mainNav.addListener(_onMainNavRequested);
    _loadedPages[_selectedIndex] = _pageBuilders[_selectedIndex]();
    // 首帧渲染后渐进式预加载其他 Tab 页，避免首次切换时卡顿
    _schedulePreload();
  }

  /// 在空闲帧依次构建其余页面，每帧只构建一个，避免阻塞 UI。
  void _schedulePreload() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadNext(index: 1);
    });
  }

  void _preloadNext({required int index}) {
    if (!mounted) return;
    if (index >= _pageBuilders.length) return;
    // 用 Scheduler 在下一帧空闲时构建，不阻塞当前帧
    SchedulerBinding.instance.scheduleTask(
      () {
        if (!mounted) return;
        if (_loadedPages[index] == null) {
          setState(() {
            _loadedPages[index] = _pageBuilders[index]();
          });
        }
        _preloadNext(index: index + 1);
      },
      Priority.animation - 10, // 低于动画优先级，不影响滚动/切换动效
    );
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
