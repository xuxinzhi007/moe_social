import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'deferred_route.dart';
import '../pages/feed/home_page.dart';
import '../pages/ai/companion_hub_page.dart' deferred as companion_hub;
import '../pages/chat/message_center_page.dart' deferred as message_center;
import '../pages/community/community_home_page.dart' deferred as community_home;
import '../pages/profile/profile_page.dart' deferred as profile;
import '../providers/companion_presence_provider.dart';
import '../providers/main_nav_controller.dart';
import '../providers/notification_provider.dart';
import '../services/chat_push_service.dart';
import '../services/startup_update_service.dart';
import '../theme/moe_tokens.dart';
import '../widgets/ai/companion_attention_sheet.dart';
import '../widgets/moe_bottom_bar.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  late final MainNavController _mainNav;
  late final CompanionPresenceProvider _presence;
  bool _companionNudgeShown = false;
  bool _companionNudgeOpen = false;
  Timer? _companionNudgeTimer;
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
          loadLibrary: community_home.loadLibrary,
          builder: () => community_home.CommunityHomePage(),
          message: '正在加载兴趣社区…',
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
    _presence = CompanionPresenceProvider.instance;
    _presence.addListener(_onCompanionPresenceChanged);
    _loadedPages[_selectedIndex] = _pageBuilders[_selectedIndex]();
    _presence.start();
    _presence.setViewingCompanion(_selectedIndex == 2);
    // 主界面就绪后再静默检查更新（软更新可稍后；强制更新会拦截）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleCompanionAttentionSheet();
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
    _companionNudgeTimer?.cancel();
    _presence.removeListener(_onCompanionPresenceChanged);
    _mainNav.removeListener(_onMainNavRequested);
    ChatPushService.clearGlobalContext();
    super.dispose();
  }

  void _onCompanionPresenceChanged() {
    if (!_presence.hasAttention) {
      _companionNudgeShown = false;
      return;
    }
    _scheduleCompanionAttentionSheet();
  }

  void _scheduleCompanionAttentionSheet() {
    if (!mounted ||
        _selectedIndex != 0 ||
        !_presence.hasAttention ||
        _companionNudgeShown ||
        _companionNudgeOpen) {
      return;
    }
    _companionNudgeTimer?.cancel();
    _companionNudgeTimer = Timer(MoeTokens.motionSlow, () {
      unawaited(_showCompanionAttentionSheet());
    });
  }

  Future<void> _showCompanionAttentionSheet() async {
    if (!mounted ||
        _selectedIndex != 0 ||
        !_presence.hasAttention ||
        _companionNudgeShown ||
        _companionNudgeOpen) {
      return;
    }
    _companionNudgeShown = true;
    _companionNudgeOpen = true;
    final greeting = _presence.greeting.trim().isNotEmpty
        ? _presence.greeting.trim()
        : _presence.moodThought.trim();
    final goSee = await CompanionAttentionSheet.show(
      context,
      greeting: greeting,
    );
    _companionNudgeOpen = false;
    if (!mounted) return;
    if (goSee == true) {
      _selectTab(2);
    }
  }

  void _onMainNavRequested() {
    final idx = _mainNav.consumeTabRequest();
    if (!mounted || idx == null) return;
    if (idx < 0 || idx >= _pageBuilders.length) return;
    setState(() {
      _loadedPages[idx] ??= _pageBuilders[idx]();
      _selectedIndex = idx;
    });
    _presence.setViewingCompanion(idx == 2);
    if (idx == 0) _scheduleCompanionAttentionSheet();
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _loadedPages[index] ??= _pageBuilders[index]();
      _selectedIndex = index;
    });
    _presence.setViewingCompanion(index == 2);
    if (index == 0) _scheduleCompanionAttentionSheet();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final companionAttention =
        context.watch<CompanionPresenceProvider>().attentionCount;
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
        onItemSelected: _selectTab,
        badgeCounts: [
          0,
          notificationProvider.directMessageUnreadCount,
          // 在 AI 伙伴 Tab 内用 Hub 横幅提示，底栏角标隐藏避免重复。
          _selectedIndex == 2 ? 0 : companionAttention,
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
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: '社区',
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
