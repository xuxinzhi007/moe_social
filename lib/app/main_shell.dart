import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/community/community_home_page.dart';
import '../pages/discover/discover_page.dart';
import '../pages/feed/home_page.dart';
import '../pages/profile/friends_page.dart';
import '../pages/profile/profile_page.dart';
import '../providers/main_nav_controller.dart';
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
    () => const FriendsPage(),
    () => const CommunityHomePage(),
    () => const DiscoverPage(),
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
          setState(() {
            _loadedPages[index] ??= _pageBuilders[index]();
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts_rounded),
            label: '同好与人脉',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: '兴趣社区',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: '探索',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
