import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io' show Platform;
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
import 'models/post.dart';
import 'services/post_service.dart';
import 'user_profile_page.dart';
import 'following_page.dart';
import 'followers_page.dart';
import 'widgets/avatar_image.dart';
import 'widgets/network_image.dart';
import 'widgets/post_skeleton.dart';
import 'widgets/fade_in_up.dart';
import 'widgets/topic_tag_selector.dart';
import 'utils/error_handler.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'services/remote_control_service.dart';
import 'avatar_editor_page.dart';
import 'gallery/cloud_gallery_page.dart';
import 'emoji/emoji_store_page.dart';
import 'ollama_chat_page.dart';
import 'friends_page.dart';
import 'direct_chat_page.dart';

void main() async {
  // 使用runZonedGuarded捕获所有未捕获的错误
  runZonedGuarded(() async {
    // 确保Flutter绑定已初始化（必须在zone内部）
    WidgetsFlutterBinding.ensureInitialized();
    
    // 初始化认证服务，从持久化存储加载登录状态
    await AuthService.init();
    
    // 创建主题提供者
    final themeProvider = ThemeProvider();
    await themeProvider.init();
    
    // 创建通知提供者
    final notificationProvider = NotificationProvider();
    notificationProvider.init(); // 启动轮询
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
    // 这对定位 RenderBox was not laid out 类问题非常关键（否则 Web 上很像没报错的白屏）
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
                border: Border.all(color: const Color(0xFF7F7FD5).withOpacity(0.25)),
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
    
    return FutureBuilder(
      future: AuthService.init(), // 每次构建时都尝试恢复登录状态
      builder: (context, snapshot) {
        // 构建应用，无论登录状态是否恢复完成
        return MaterialApp(
          title: 'Moe Social',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          initialRoute: AuthService.isLoggedIn ? '/home' : '/login',
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
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
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
            '/avatar-editor': (context) => const AvatarEditorPage(),
            '/emoji-store': (context) => const EmojiStorePage(),
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

  final List<Widget> _pages = [
    HomePage(),
    ChatTabPage(),
    GachaPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: Theme.of(context).primaryColor.withOpacity(0.2),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
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
              label: '聊天',
            ),
            NavigationDestination(
              icon: Icon(Icons.casino_outlined),
              selectedIcon: Icon(Icons.casino_rounded),
              label: '扭蛋',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}

class ChatTabPage extends StatelessWidget {
  const ChatTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('聊天'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '好友'),
              Tab(text: 'AI聊天'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FriendsPage(),
            OllamaChatPage(),
          ],
        ),
      ),
    );
  }
}

// ... existing HomePage code ...
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalPosts = 0;
  static const int _pageSize = 10;

  // 添加滚动控制器和加载触发标志
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingTriggered = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchPosts();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动监听器
  void _scrollListener() {
    // 检查是否有滚动位置信息
    if (!_scrollController.hasClients) return;
    
    // 如果正在加载或没有更多数据，直接返回
    if (_isLoading || _isLoadingMore || !_hasMore || _isLoadingTriggered) {
      return;
    }
    
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    
    // 当滚动到距底部300像素时触发加载，或者已经滚动到底部
    final threshold = maxScroll > 0 ? maxScroll - 300 : 0;
    final isNearBottom = currentScroll >= threshold || 
                        (maxScroll > 0 && currentScroll >= maxScroll - 50);
    
    if (isNearBottom) {
      debugPrint('🔄 触发加载更多');
      debugPrint('   当前滚动位置: $currentScroll');
      debugPrint('   最大滚动位置: $maxScroll');
      debugPrint('   阈值: $threshold');
      debugPrint('   _hasMore: $_hasMore');
      debugPrint('   _isLoading: $_isLoading');
      debugPrint('   _isLoadingMore: $_isLoadingMore');
      debugPrint('   _isLoadingTriggered: $_isLoadingTriggered');
      debugPrint('   当前页码: $_currentPage');
      debugPrint('   已加载帖子数: ${_posts.length}');
      
      // 立即设置标志，防止重复触发
      _isLoadingTriggered = true;
      
      // 异步调用，但不等待完成就返回，避免阻塞滚动
      _loadMorePosts();
    }
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    
    try {
      final result = await PostService.getPosts(page: 1, pageSize: _pageSize);
      final posts = result['posts'] as List<Post>;
      final total = result['total'] as int;
      
      // 从本地存储获取点赞状态
      if (AuthService.isLoggedIn) {
        final postIds = posts.map((post) => post.id).toList();
        final likeStatuses = await AuthService.getLikeStatuses(postIds);
        
        // 更新帖子的点赞状态
        for (int i = 0; i < posts.length; i++) {
          final post = posts[i];
          final isLiked = likeStatuses[post.id] ?? false;
          posts[i] = post.copyWith(isLiked: isLiked);
        }
      }
      
      debugPrint('📥 从后端获取的数据：');
      debugPrint('   总帖子数：$total');
      debugPrint('   第一页帖子数：${posts.length}');
      debugPrint('   帖子ID列表：${posts.map((post) => post.id).toList()}');
      
      setState(() {
        _posts = posts;
        _totalPosts = total;
        _currentPage = 1; // 确保页码正确
        // 修复_hasMore判断逻辑：如果已加载数据小于总数，则还有更多
        _hasMore = posts.length < total;
      });
      
      debugPrint('📝 设置后的状态：');
      debugPrint('   _posts长度：${_posts.length}');
      debugPrint('   _totalPosts：$_totalPosts');
      debugPrint('   _currentPage：$_currentPage');
      debugPrint('   _hasMore：$_hasMore');
      debugPrint('   判断逻辑：${_posts.length} < ${_totalPosts} = ${_hasMore}');
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    // 如果正在刷新、正在加载更多或没有更多数据，则不执行
    if (_isLoading || _isLoadingMore || !_hasMore) {
      debugPrint('⚠️ 阻止重复加载：_isLoading=$_isLoading, _isLoadingMore=$_isLoadingMore, _hasMore=$_hasMore');
      return;
    }
    
    // 立即设置加载状态，防止并发调用
    setState(() {
      _isLoadingMore = true;
    });
    
    debugPrint('📥 开始加载更多帖子');
    debugPrint('   当前页码：$_currentPage');
    debugPrint('   已加载帖子数：${_posts.length}');
    debugPrint('   总帖子数：$_totalPosts');
    debugPrint('   下一页码：${_currentPage + 1}');
    debugPrint('   _hasMore：$_hasMore');
    
    try {
      final nextPage = _currentPage + 1;
      debugPrint('📡 请求第 $nextPage 页数据...');
      
      final result = await PostService.getPosts(page: nextPage, pageSize: _pageSize);
      final morePosts = result['posts'] as List<Post>;
      final total = result['total'] as int;
      
      // 从本地存储获取点赞状态
      if (AuthService.isLoggedIn) {
        final postIds = morePosts.map((post) => post.id).toList();
        final likeStatuses = await AuthService.getLikeStatuses(postIds);
        
        // 更新帖子的点赞状态
        for (int i = 0; i < morePosts.length; i++) {
          final post = morePosts[i];
          final isLiked = likeStatuses[post.id] ?? false;
          morePosts[i] = post.copyWith(isLiked: isLiked);
        }
      }
      
      debugPrint('📥 加载更多帖子成功：');
      debugPrint('   请求页码：$nextPage');
      debugPrint('   返回的帖子数：${morePosts.length}');
      debugPrint('   帖子ID列表：${morePosts.map((post) => post.id).toList()}');
      debugPrint('   总帖子数：$total');
      
      // 如果返回的数据为空，说明没有更多数据了
      if (morePosts.isEmpty) {
        debugPrint('⚠️ 返回的数据为空，说明没有更多数据了');
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }
      
      setState(() {
        _posts.addAll(morePosts);
        _currentPage = nextPage;
        _totalPosts = total;
        // 修复_hasMore判断逻辑：如果已加载数据小于总数，则还有更多
        _hasMore = _posts.length < total;
      });
      
      debugPrint('📝 设置后的状态：');
      debugPrint('   _posts长度：${_posts.length}');
      debugPrint('   _currentPage：$_currentPage');
      debugPrint('   _totalPosts：$_totalPosts');
      debugPrint('   _hasMore：$_hasMore');
      debugPrint('   判断逻辑：${_posts.length} < ${_totalPosts} = ${_hasMore}');
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
        // 请求失败时，停止尝试加载更多，避免无限请求
        setState(() {
          _hasMore = false;
        });
      }
      debugPrint('❌ 加载更多帖子失败：$e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
      // 重置触发标志，允许下次触发
      _isLoadingTriggered = false;
    }
  }

  Future<void> _toggleLike(String postId) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) {
        ErrorHandler.showError(context, '请先登录');
      }
      return;
    }
    
    try {
      final originalPost = _posts.firstWhere((post) => post.id == postId);
      final updatedPost = await PostService.toggleLike(postId, userId);
      
      // 保留原来的话题标签信息，避免点赞后话题标签消失
      final postWithTags = updatedPost.copyWith(
        topicTags: originalPost.topicTags,
      );
      
      setState(() {
        _posts = _posts.map((post) {
          if (post.id == postId) {
            return postWithTags;
          }
          return post;
        }).toList();
      });
      
      // 保存点赞状态到本地存储
      await AuthService.saveLikeStatus(postId, postWithTags.isLiked);
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Moe Social',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              // 未读通知标记
              Consumer<NotificationProvider>(
                builder: (context, provider, child) {
                  if (provider.unreadCount == 0) return const SizedBox.shrink();
                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                      child: provider.unreadCount > 99 
                          ? const Text('99+', style: TextStyle(color: Colors.white, fontSize: 8))
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/create-post');
          if (result == true) {
            _fetchPosts();
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPosts,
        color: Theme.of(context).primaryColor,
        child: ListView.builder(
          controller: _scrollController, // 添加滚动控制器
          itemCount: _isLoading && _posts.isEmpty
              ? 7 // 显示骨架屏 (header + 6个骨架屏)
              : _posts.isEmpty
                  ? 2 // header + 空状态
                  : _posts.length + 2, // +1 for header, +1 for bottom indicator
          itemBuilder: (context, index) {
            if (index == 0) {
              // Header Section
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Section
                  Container(
                    margin: const EdgeInsets.all(16),
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7F7FD5), // 薰衣草紫
                          Color(0xFF86A8E7), // 天空蓝
                          Color(0xFF91EAE4), // 薄荷绿
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7F7FD5).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // 装饰圆圈
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          left: -30,
                          bottom: -30,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // 内容
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.explore_rounded, size: 40, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '发现更可爱的世界',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickAction(
                          Icons.category_rounded, 
                          '分区', 
                          Colors.pink[50]!, 
                          Colors.pinkAccent,
                          onTap: () {},
                        ),
                        _buildQuickAction(
                          Icons.whatshot_rounded, 
                          '热门', 
                          Colors.orange[50]!, 
                          Colors.orange,
                          onTap: () {},
                        ),
                        _buildQuickAction(
                          Icons.new_releases_rounded, 
                          '最新', 
                          Colors.blue[50]!, 
                          Colors.blueAccent,
                          onTap: () {},
                        ),
                        _buildQuickAction(
                          Icons.star_rounded, 
                          '关注', 
                          Colors.purple[50]!, 
                          Colors.purpleAccent,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // List Section Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '热门动态',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }
            
            // 如果正在加载且没有数据，显示骨架屏
            if (_isLoading && _posts.isEmpty) {
               return const PostSkeleton();
            }
            
            // 如果加载完成但列表为空，显示空状态（只在第一个item显示）
            if (!_isLoading && _posts.isEmpty && index == 1) {
              return _buildEmptyState();
            }
            
            final postIndex = index - 1;
            if (postIndex < _posts.length) {
              // Post Item
              final post = _posts[postIndex];
              return FadeInUp(
                delay: Duration(milliseconds: 30 * (postIndex % 5)),
                child: _buildPostCard(post, postIndex),
              );
            } else {
              // 底部指示器 - 简化逻辑，移除自动触发
              return _buildBottomIndicator();
            }
          },
        ),
      ),
    );
  }

  // 构建空状态
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7F7FD5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 64,
              color: Color(0xFF7F7FD5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '还没有动态呢 ~',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发布第一条动态，开启萌系社交之旅吧！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/create-post');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('发布动态'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F7FD5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 5,
              shadowColor: const Color(0xFF7F7FD5).withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  // 构建底部加载指示器
  Widget _buildBottomIndicator() {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F7FD5)),
              ),
              const SizedBox(height: 12),
              Text(
                '加载中...',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    } else if (!_hasMore && _posts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: Colors.grey[400], size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                '已经到底啦 ~',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_hasMore) {
      // 有更多数据但不在加载中，显示可点击的加载提示
      return Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () {
            if (!_isLoading && !_isLoadingMore && _hasMore) {
              _loadMorePosts();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF7F7FD5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  color: const Color(0xFF7F7FD5),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '点击加载更多',
                  style: TextStyle(
                    color: const Color(0xFF7F7FD5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildQuickAction(IconData icon, String label, Color bgColor, Color iconColor, {required VoidCallback onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label, 
          style: const TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.w500,
            color: Colors.black87
          )
        ),
      ],
    );
  }

  Widget _buildPostCard(Post post, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final heroTag = 'avatar_${post.id}';
                    Navigator.pushNamed(
                      context, 
                      '/user-profile', 
                      arguments: {
                        'userId': post.userId,
                        'userName': post.userName,
                        'userAvatar': post.userAvatar,
                        'heroTag': heroTag,
                      }
                    );
                  },
                  child: Hero(
                    tag: 'avatar_${post.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7F7FD5).withOpacity(0.3),
                            const Color(0xFF86A8E7).withOpacity(0.3),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7F7FD5).withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: NetworkAvatarImage(
                          imageUrl: post.userAvatar,
                          radius: 22,
                          placeholderIcon: Icons.person,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 帖子内容
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _renderContentWithEmojis(post.content),
            ),


            // 话题标签
            if (post.topicTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: post.topicTags.map((tag) => TopicTagDisplay(
                  tag: tag,
                  fontSize: 12,
                  showUsageCount: false,
                  onTap: () {
                    // 跳转到话题动态列表页面
                    Navigator.pushNamed(
                      context,
                      '/topic-posts',
                      arguments: tag,
                    );
                  },
                )).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // 帖子图片
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 4),
              post.images.length == 1
                  ? GestureDetector(
                      onTap: () {},
                      child: Hero(
                        tag: 'post_img_${post.id}_0',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: NetworkImageWidget(
                              imageUrl: post.images[0],
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: post.images.length,
                        itemBuilder: (context, imgIndex) {
                          return Container(
                            margin: EdgeInsets.only(
                              right: imgIndex < post.images.length - 1 ? 12 : 0,
                            ),
                            child: GestureDetector(
                              onTap: () {},
                              child: Hero(
                                tag: 'post_img_${post.id}_$imgIndex',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: NetworkImageWidget(
                                      imageUrl: post.images[imgIndex],
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],
            
            const SizedBox(height: 20),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey[200]!,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 帖子互动
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                LikeButton(
                  isLiked: post.isLiked,
                  likeCount: post.likes,
                  onTap: () => _toggleLike(post.id),
                ),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: post.comments,
                  onTap: () async {
                    await Navigator.pushNamed(context, '/comments', arguments: post.id);
                    _fetchPosts();
                  }
                ),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  label: '分享',
                  onTap: () {}
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon, 
    int? count, 
    String? label,
    required VoidCallback onTap
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.grey[600], size: 20),
              if (count != null || label != null) ...[
                const SizedBox(width: 6),
                Text(
                  count?.toString() ?? label ?? '',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
  
  /// 将文本内容中的表情占位符转换为富文本，显示实际的表情图片
  Widget _renderContentWithEmojis(String content) {
    // 表情占位符正则表达式：[emoji:url]格式
    final emojiRegex = RegExp(r'\[emoji:(.*?)\]');
    final matches = emojiRegex.allMatches(content);
    
    if (matches.isEmpty) {
      // 如果没有表情占位符，直接返回普通文本
      return Text(
        content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      );
    }
    
    // 构建富文本
    final List<InlineSpan> spans = [];
    int lastIndex = 0;
    
    for (final match in matches) {
      // 添加匹配之前的普通文本
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ));
      }
      
      // 获取表情URL
      final emojiUrl = match.group(1) ?? '';
      
      // 添加表情图片
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Image.network(
            emojiUrl,
            width: 24,
            height: 24,
            fit: BoxFit.cover,
          ),
        ),
      ));
      
      lastIndex = match.end;
    }
    
    // 添加剩余的普通文本
    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(
        children: spans,
      ),
    );
  }
}

// 带有弹性动画的点赞按钮
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback onTap;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50), // 放大
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50), // 恢复
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != _isLiked) {
      _isLiked = widget.isLiked;
      if (_isLiked) {
        _controller.forward().then((_) => _controller.reset());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.onTap();
        if (!widget.isLiked) {
          _controller.forward().then((_) => _controller.reset());
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: widget.isLiked ? Colors.pinkAccent : Colors.grey[600],
                size: 22,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.likeCount}',
              style: TextStyle(
                color: widget.isLiked ? Colors.pinkAccent : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
