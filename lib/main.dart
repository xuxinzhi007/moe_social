import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import 'app/app_routes.dart';
import 'services/achievement_hooks.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'services/behavior_analytics_service.dart';
import 'utils/behavior_route_observer.dart';
import 'utils/console_output_filter.dart';
import 'utils/crash_report_buffer.dart';
import 'utils/config.dart' as moe_launch_config;
import 'widgets/app_message_widget.dart';
import 'widgets/floating_virtual_avatar_host.dart';
import 'widgets/notification_popup_host.dart';
import 'services/notification_service.dart';
import 'services/remote_control_service.dart';
import 'services/presence_service.dart';
import 'services/chat_push_service.dart';
import 'services/push_notification_service.dart';
import 'services/daily_growth_service.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/device_info_provider.dart';
import 'providers/loading_provider.dart';
import 'providers/checkin_provider.dart';
import 'providers/user_level_provider.dart';
import 'providers/virtual_avatar_provider.dart';
import 'providers/main_nav_controller.dart';
import 'providers/life_provider.dart';
import 'providers/pet_provider.dart';
import 'providers/companion_presence_provider.dart';
import 'utils/startup_manager.dart';
import 'utils/webview_platform_init.dart';
import 'widgets/splash_screen.dart';
import 'theme/moe_tokens.dart';

String _platformLabel() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

void main() {
  // ensureInitialized 与 runApp 必须在同一 Zone（与 runZonedGuarded 一致），否则 Web 上会报 Zone mismatch。
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    ensureWebViewPlatformInitialized();
    _setupErrorHandlers();
    runApp(const SplashScreenWrapper());
  }, (error, stack) {
    CrashReportBuffer.record(error, stack, source: 'zone');
  }, zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      if (shouldSuppressConsoleLine(line)) return;
      parent.print(zone, line);
    },
  ));
}

void _setupErrorHandlers() {
  int errorCount = 0;
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorString = details.exceptionAsString();
    if (errorString.contains('parentDataDirty')) {
      errorCount++;
      debugPrint('Flutter Error [$errorCount]: $errorString');
      debugPrint('Stack: ${details.stack}');
      if (errorCount == 4) {
        debugPrint('... (重复 parentDataDirty 错误已省略，请完全重启 App 后重试)');
      }
      // 勿 presentError：会在 semantics 阶段再次触发布局，导致每帧崩溃与白屏。
      return;
    }
    errorCount = 0;
    CrashReportBuffer.record(
      details.exception,
      details.stack,
      source: 'flutter:${details.library ?? "ui"}',
    );
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    final raw = details.exceptionAsString();
    final brief = raw.length > 320 ? '${raw.substring(0, 320)}…' : raw;
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
              border: Border.all(
                  color: const Color(0xFF7F7FD5).withValues(alpha: 0.25)),
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
                  brief,
                  style: const TextStyle(color: Colors.black87, height: 1.3),
                ),
                const SizedBox(height: 10),
                Text(
                  '提示：若刚热重载(R)后出现，请先关掉所有底部弹窗，再浏览器硬刷新或重新 flutter run。\n'
                  '常见原因：弹窗里的输入框 controller 已释放、或动画组件热重载未重建。',
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

  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReportBuffer.record(error, stack, source: 'platform');
    return true;
  };
}

class SplashScreenWrapper extends StatelessWidget {
  const SplashScreenWrapper({super.key});

  static Duration get _splashMinDuration {
    if (kIsWeb || kDebugMode) {
      return const Duration(milliseconds: 300);
    }
    return const Duration(milliseconds: 600);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moe Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: MoeTokens.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: MoeTokens.pageBackground,
      ),
      home: SplashScreen(
        onInit: _initializeApp,
        onComplete: (context) => const MyApp(),
        minDuration: _splashMinDuration,
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
    ]);

    await startupManager.run();

    if (AuthService.isLoggedIn) {
      PresenceService.start();
      ChatPushService.start();
      CompanionPresenceProvider.instance.start();
      BehaviorAnalyticsService.instance.start();
      final uid = AuthService.currentUser;
      if (uid != null) {
        unawaited(AchievementHooks.ensureReady(uid));
      }
    }

    ChatPushService.initialize(AuthService.navigatorKey);

    debugPrint('🚀 App starting...');
    debugPrint('📱 Platform: ${_platformLabel()}');
    debugPrint('🧭 API Environment: ${ApiService.runtimeEnvironment} '
        '(isProduction=${moe_launch_config.AppConfig.isProduction})');
    debugPrint('🌐 API Base URL: ${ApiService.baseUrl}');
    debugPrint('🔐 User logged in: ${AuthService.isLoggedIn}');
    if (kIsWeb && kDebugMode) {
      debugPrint(
        '💡 Web 调试：F5=整页重载；看 REST 请用终端 Console 搜「✓ GET」；'
        'Network 面板选 Fetch/XHR。改 UI 建议 flutter run -d macos/android。',
      );
    }
  }
}

ThemeProvider? _globalThemeProvider;
NotificationProvider? _globalNotificationProvider;
DeviceInfoProvider? _globalDeviceInfoProvider;
LoadingProvider? _globalLoadingProvider;
VirtualAvatarProvider? _globalVirtualAvatarProvider;

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
      // 版本检查改到主界面 MainPage 就绪后，避免抢登录/闪屏注意力。
      if (AuthService.isLoggedIn) {
        DailyGrowthService.instance.scheduleAutoCheckInAfterLogin();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = _globalThemeProvider ?? ThemeProvider();
    final notificationProvider =
        _globalNotificationProvider ?? NotificationProvider()
          ..init();
    final deviceInfoProvider = _globalDeviceInfoProvider ?? DeviceInfoProvider()
      ..init();
    final loadingProvider = _globalLoadingProvider ?? LoadingProvider();
    final virtualAvatarProvider =
        _globalVirtualAvatarProvider ?? VirtualAvatarProvider()
          ..init();

    _globalNotificationProvider = notificationProvider;
    _globalDeviceInfoProvider = deviceInfoProvider;
    _globalLoadingProvider = loadingProvider;
    _globalVirtualAvatarProvider = virtualAvatarProvider;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: notificationProvider),
        ChangeNotifierProvider.value(value: deviceInfoProvider),
        ChangeNotifierProvider.value(value: loadingProvider),
        ChangeNotifierProvider.value(value: virtualAvatarProvider),
        ChangeNotifierProvider(create: (_) => CheckInProvider()),
        ChangeNotifierProvider(create: (_) => UserLevelProvider()),
        ChangeNotifierProvider(create: (_) => MainNavController()),
        ChangeNotifierProvider(create: (_) => LifeProvider()),
        ChangeNotifierProvider(create: (_) => PetProvider()),
        ChangeNotifierProvider.value(
          value: CompanionPresenceProvider.instance,
        ),
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
              child: FloatingVirtualAvatarHost(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
        routes: buildAppRoutes(),
        navigatorObservers: [behaviorRouteObserver],
      ),
    );
  }
}
