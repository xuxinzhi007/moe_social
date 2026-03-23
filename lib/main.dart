import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'auth_service.dart';
import 'login_page.dart';
import 'services/api_service.dart';
import 'register_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'create_post_page.dart';
import 'comments_page.dart';
import 'topic_posts_page.dart';
import 'models/topic_tag.dart';
import 'edit_profile_page.dart';
import 'vip_center_page.dart';
import 'vip_purchase_page.dart';
import 'vip_orders_page.dart';
import 'vip_history_page.dart';
import 'forgot_password_page.dart';
import 'verify_code_page.dart';
import 'reset_password_page.dart';
import 'notification_center_page.dart';
import 'wallet_page.dart';
import 'recharge_page.dart';
import 'gacha_page.dart';
import 'pages/game/game_lobby_page.dart';
import 'user_profile_page.dart';
import 'widgets/app_message_widget.dart';
import 'widgets/moe_bottom_bar.dart';
import 'services/notification_service.dart';
import 'services/remote_control_service.dart';
import 'services/presence_service.dart';
import 'services/chat_push_service.dart';
import 'services/accessibility_overlay_service.dart';
import 'gallery/cloud_gallery_page.dart';
import 'pages/ai/agent_list_page.dart';
import 'friends_page.dart';
import 'direct_chat_page.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/device_info_provider.dart';
import 'providers/loading_provider.dart';
import 'providers/checkin_provider.dart';
import 'providers/user_level_provider.dart';
import 'providers/game_provider.dart';
import 'pages/home_page.dart';

void main() async {
  // 使用runZonedGuarded捕获所有未捕获的错误
  runZonedGuarded(() async {
    // 确保Flutter绑定已初始化（必须在zone内部）
    WidgetsFlutterBinding.ensureInitialized();

    // 初始化认证服务，从持久化存储加载登录状态
    await AuthService.init();
    // 登录态已恢复后，立即启动 WebSocket（在线/私信）
    if (AuthService.isLoggedIn) {
      PresenceService.start();
      ChatPushService.start();
    }
    
    // 初始化无障碍悬浮窗监听
    AccessibilityOverlayService.init();

    // 创建主题提供者
    final themeProvider = ThemeProvider();
    await themeProvider.init();

    // 创建通知提供者
    final notificationProvider = NotificationProvider();
    notificationProvider.init(); // 启动轮询

    // 创建设备信息提供者
    final deviceInfoProvider = DeviceInfoProvider();
    deviceInfoProvider.init(); // 启动设备信息同步

    // 创建加载状态提供者
    final loadingProvider = LoadingProvider();

    await NotificationService.initLocalNotifications();
    await RemoteControlService.init();

    // 捕获Flutter框架错误
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // 输出详细错误信息
      debugPrint('═══════════════════════════════════════');
      debugPrint('Flutter Error:');
      debugPrint('Exception: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
      debugPrint('Library: ${details.library}');
      debugPrint('═══════════════════════════════════════');
    };

    // 避免“白屏”：当 widget build/layout 抛错时，用一个可见的错误卡片替代
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // 保持控制台输出，便于复制排查
      FlutterError.presentError(details);

      return Material(
        color: const Color(0xFFF5F7FA), // Moe 背景色
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7F7FD5).withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                    color: const Color(0xFF7F7FD5).withOpacity(0.25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '页面渲染出错啦 (；´д｀)ゞ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7F7FD5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    details.exceptionAsString(),
                    style: const TextStyle(color: Colors.black87, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '提示：这通常不是接口数据问题，而是布局约束导致的 RenderBox 未完成 layout。\n请把控制台里最早出现的那条异常（不是后面一堆 hasSize 重复）截图发我。',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    // 捕获异步错误
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('Platform Error:');
      debugPrint('Error: $error');
      debugPrint('Stack: $stack');
      debugPrint('═══════════════════════════════════════');
      return true;
    };

    debugPrint('🚀 App starting...');
    // Web平台不支持Platform.operatingSystem，使用kIsWeb判断
    if (kIsWeb) {
      debugPrint('📱 Platform: web');
    } else {
      debugPrint('📱 Platform: ${Platform.operatingSystem}');
    }
    debugPrint('🌐 API Base URL: ${ApiService.baseUrl}');
    debugPrint('🔐 User logged in: ${AuthService.isLoggedIn}');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: notificationProvider),
          ChangeNotifierProvider.value(value: deviceInfoProvider),
          ChangeNotifierProvider.value(value: loadingProvider),
          ChangeNotifierProvider(create: (_) => CheckInProvider()),
          ChangeNotifierProvider(create: (_) => UserLevelProvider()),
          ChangeNotifierProvider(create: (_) => GameProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('Uncaught Error:');
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
    debugPrint('═══════════════════════════════════════');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Moe Social',
      navigatorKey: AuthService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      initialRoute: AuthService.isLoggedIn ? '/home' : '/login',
      builder: (context, child) {
        return AppMessageWidget(child: child ?? Container());
      },
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const MainPage(),
        '/profile': (context) => const ProfilePage(),
        '/settings': (context) => const SettingsPage(),
        '/create-post': (context) => const CreatePostPage(),
        '/comments': (context) => CommentsPage(
              postId: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/edit-profile': (context) => EditProfilePage(
              user: ModalRoute.of(context)!.settings.arguments as dynamic,
            ),
        '/vip-center': (context) => const VipCenterPage(),
        '/vip-purchase': (context) => const VipPurchasePage(),
        '/vip-orders': (context) => const VipOrdersPage(),
        '/vip-history': (context) => const VipHistoryPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/verify-code': (context) => VerifyCodePage(
              email: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/reset-password': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return ResetPasswordPage(
            email: args['email'] as String,
            code: args['code'] as String,
          );
        },
        '/notifications': (context) => const NotificationCenterPage(),
        '/wallet': (context) => const WalletPage(),
        '/recharge': (context) => const RechargePage(),
        '/gacha': (context) => GachaPage(), // 注册扭蛋页路由
        '/user-profile': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! Map<String, dynamic>) {
            // 如果参数丢失（例如Web端刷新），重定向回首页或显示错误页
            return const Scaffold(
              body: Center(child: Text('页面参数丢失，请返回首页重新进入')),
            );
          }
          return UserProfilePage(
            userId: args['userId'] as String,
            userName: args['userName'] as String?,
            userAvatar: args['userAvatar'] as String?,
            heroTag: args['heroTag'] as String?,
          );
        },
        '/cloud-gallery': (context) => const CloudGalleryPage(),
        '/topic-posts': (context) {
          final tag = ModalRoute.of(context)!.settings.arguments as TopicTag;
          return TopicPostsPage(topicTag: tag);
        },
        '/friends': (context) => const FriendsPage(),
        '/direct-chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! Map<String, dynamic>) {
            return const Scaffold(
              body: Center(child: Text('页面参数丢失，请返回重试')),
            );
          }
          return DirectChatPage(
            userId: args['userId'] as String,
            username: args['username'] as String,
            avatar: args['avatar'] as String,
          );
        },
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  late final List<Widget Function()> _pageBuilders = [
    () => HomePage(),
    () => FriendsPage(),
    () => AgentListPage(),
    () => const GameLobbyPage(),
    () => ProfilePage(),
  ];
  late final List<Widget?> _loadedPages =
      List<Widget?>.filled(_pageBuilders.length, null, growable: false);

  @override
  void initState() {
    super.initState();
    _loadedPages[_selectedIndex] = _pageBuilders[_selectedIndex]();
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
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '好友',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports_rounded),
            label: '娱乐',
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
