import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'services/achievement_hooks.dart';
import 'auth_service.dart';
import 'pages/auth/login_page.dart';
import 'pages/achievements/achievements_page.dart';
import 'services/api_service.dart';
import 'pages/auth/register_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/feed/create_post_page.dart';
import 'pages/feed/comments_page.dart';
import 'pages/feed/topic_posts_page.dart';
import 'models/post.dart';
import 'models/topic_tag.dart';
import 'pages/profile/edit_profile_page.dart';
import 'pages/commerce/vip_center_page.dart';
import 'pages/commerce/vip_purchase_page.dart';
import 'pages/commerce/vip_orders_page.dart';
import 'pages/commerce/order_center_page.dart';
import 'pages/commerce/vip_history_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'pages/auth/verify_code_page.dart';
import 'pages/auth/reset_password_page.dart';
import 'pages/notifications/notification_center_page.dart';
import 'pages/commerce/wallet_page.dart';
import 'pages/commerce/recharge_page.dart';
import 'pages/commerce/gacha_page.dart';
import 'pages/profile/user_profile_page.dart';
import 'pages/profile/user_qr_code_page.dart';
import 'pages/scan/scan_page.dart';
import 'widgets/app_message_widget.dart';
import 'widgets/notification_popup_host.dart';
import 'widgets/moe_bottom_bar.dart';
import 'services/notification_service.dart';
import 'services/remote_control_service.dart';
import 'services/presence_service.dart';
import 'services/chat_push_service.dart';
import 'services/push_notification_service.dart';
import 'services/startup_update_service.dart';
import 'pages/gallery/cloud_gallery_page.dart';
import 'pages/profile/friends_page.dart';
import 'pages/discover/discover_page.dart';
import 'pages/discover/match_page.dart';
import 'pages/chat/direct_chat_page.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/device_info_provider.dart';
import 'providers/loading_provider.dart';
import 'providers/checkin_provider.dart';
import 'providers/user_level_provider.dart';
import 'providers/game_provider.dart';
import 'pages/feed/home_page.dart';
import 'pages/community/community_home_page.dart';
import 'pages/community/community_post_detail_page.dart';
import 'utils/startup_manager.dart';
import 'utils/async_svg_manager.dart';
import 'widgets/splash_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    
    _setupErrorHandlers();

    runApp(const SplashScreenWrapper());
  }, (error, stack) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('Uncaught Error:');
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
    debugPrint('═══════════════════════════════════════');
  });
}

void _setupErrorHandlers() {
  int errorCount = 0;
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorString = details.exceptionAsString();
    if (errorString.contains('parentDataDirty')) {
      errorCount++;
      if (errorCount <= 3) {
        debugPrint('Flutter Error [${errorCount}]: $errorString');
      } else if (errorCount == 4) {
        debugPrint('... (重复错误已省略，修复后刷新即可)');
      }
      return;
    }
    errorCount = 0;
    debugPrint('═══════════════════════════════════════');
    debugPrint('Flutter Error:');
    debugPrint('Exception: $errorString');
    debugPrint('Stack: ${details.stack}');
    debugPrint('Library: ${details.library}');
    debugPrint('═══════════════════════════════════════');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    return Material(
      color: const Color(0xFFF5F7FA),
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
                  color: const Color(0xFF7F7FD5).withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: const Color(0xFF7F7FD5).withValues(alpha: 0.25)),
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
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('Platform Error:');
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
    debugPrint('═══════════════════════════════════════');
    return true;
  };
}

class SplashScreenWrapper extends StatelessWidget {
  const SplashScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moe Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: SplashScreen(
        onInit: _initializeApp,
        onComplete: (context) => const MyApp(),
        minDuration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _initializeApp() async {
    final startupManager = StartupManager();

    startupManager.addTasks([
      StartupTask(
        name: 'API Config',
        task: () => ApiService.initRemoteProductionBaseUrl(),
        critical: true,
      ),
      StartupTask(
        name: 'Auth Service',
        task: () => AuthService.init(),
        critical: true,
      ),
      StartupTask(
        name: 'Theme Provider',
        task: () async {
          final themeProvider = ThemeProvider();
          await themeProvider.init();
          _globalThemeProvider = themeProvider;
        },
        critical: true,
      ),
      StartupTask(
        name: 'Local Notifications',
        task: () => NotificationService.initLocalNotifications(),
        critical: false,
      ),
      StartupTask(
        name: 'Remote Control',
        task: () => RemoteControlService.init(),
        critical: false,
      ),
      StartupTask(
        name: 'Push Notifications',
        task: () async {
          if (!kIsWeb) {
            await PushNotificationService.initialize(AuthService.navigatorKey);
          }
        },
        critical: false,
      ),
      StartupTask(
        name: 'SVG Resources',
        task: () => AsyncSvgManager().preloadAll(),
        critical: false,
      ),
    ]);

    await startupManager.run();

    if (AuthService.isLoggedIn) {
      PresenceService.start();
      ChatPushService.start();
      final uid = AuthService.currentUser;
      if (uid != null) {
        unawaited(AchievementHooks.ensureReady(uid));
      }
    }

    ChatPushService.initialize(AuthService.navigatorKey);

    debugPrint('🚀 App starting...');
    debugPrint('📱 Platform: ${kIsWeb ? "web" : Platform.operatingSystem}');
    debugPrint('🌐 API Base URL: ${ApiService.baseUrl}');
    debugPrint('🔐 User logged in: ${AuthService.isLoggedIn}');
  }
}

ThemeProvider? _globalThemeProvider;
NotificationProvider? _globalNotificationProvider;
DeviceInfoProvider? _globalDeviceInfoProvider;
LoadingProvider? _globalLoadingProvider;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        unawaited(StartupUpdateService.tryLaunchUpdateCheck());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = _globalThemeProvider ?? ThemeProvider();
    final notificationProvider = _globalNotificationProvider ?? NotificationProvider()..init();
    final deviceInfoProvider = _globalDeviceInfoProvider ?? DeviceInfoProvider()..init();
    final loadingProvider = _globalLoadingProvider ?? LoadingProvider();

    _globalNotificationProvider = notificationProvider;
    _globalDeviceInfoProvider = deviceInfoProvider;
    _globalLoadingProvider = loadingProvider;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: notificationProvider),
        ChangeNotifierProvider.value(value: deviceInfoProvider),
        ChangeNotifierProvider.value(value: loadingProvider),
        ChangeNotifierProvider(create: (_) => CheckInProvider()),
        ChangeNotifierProvider(create: (_) => UserLevelProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp(
        title: 'Moe Social',
        navigatorKey: AuthService.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: themeProvider.currentTheme,
        initialRoute: AuthService.isLoggedIn ? '/home' : '/login',
        builder: (context, child) {
          return AppMessageWidget(
            child: NotificationPopupHost(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        routes: {
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/home': (context) => const MainPage(),
          '/profile': (context) => const ProfilePage(),
          '/achievements': (context) => const AchievementsPage(),
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
          '/orders': (context) => const OrderCenterPage(),
          '/vip-history': (context) => const VipHistoryPage(),
          '/forgot-password': (context) => const ForgotPasswordPage(),
          '/verify-code': (context) => VerifyCodePage(
                email: ModalRoute.of(context)!.settings.arguments as String,
              ),
          '/reset-password': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return ResetPasswordPage(
              email: args['email'] as String,
              code: args['code'] as String,
            );
          },
          '/notifications': (context) => const NotificationCenterPage(),
          '/wallet': (context) => const WalletPage(),
          '/recharge': (context) => const RechargePage(),
          '/gacha': (context) => const GachaPage(),
          '/user-profile': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is! Map<String, dynamic>) {
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
          '/community': (context) => const CommunityHomePage(),
          '/post-detail': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is! Map) {
              return const Scaffold(body: Center(child: Text('缺少动态参数')));
            }
            final postId = args['postId'] as String?;
            if (postId == null || postId.isEmpty) {
              return const Scaffold(body: Center(child: Text('无效的动态 ID')));
            }
            final initial = args['post'] is Post ? args['post'] as Post : null;
            return CommunityPostDetailPage(postId: postId, initialPost: initial);
          },
          '/match': (context) => const MatchPage(),
          '/direct-chat': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is! Map<String, dynamic>) {
              return const Scaffold(body: Center(child: Text('页面参数丢失，请返回重试')));
            }
            return DirectChatPage(
              userId: args['userId'] as String,
              username: args['username'] as String,
              avatar: args['avatar'] as String,
            );
          },
          '/scan': (context) => const ScanPage(),
          '/user-qr-code': (context) => const UserQrCodePage(),
          '/interaction': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            var tab = 0;
            if (args is Map && args['tab'] is int) {
              tab = (args['tab'] as int).clamp(0, 1);
            }
            return FriendsPage(initialHubTabIndex: tab);
          },
        },
      ),
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
    _loadedPages[_selectedIndex] = _pageBuilders[_selectedIndex]();
  }

  @override
  Widget build(BuildContext context) {
    ChatPushService.setGlobalContext(context);

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
            label: '联系人',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: '社区',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: '发现',
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
