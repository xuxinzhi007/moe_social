import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'edit_profile_page.dart';
import 'vip_center_page.dart';
import 'vip_purchase_page.dart';
import 'vip_orders_page.dart';
import 'vip_history_page.dart';
import 'forgot_password_page.dart';
import 'verify_code_page.dart';
import 'reset_password_page.dart';
import 'notification_center_page.dart';
import 'models/post.dart';
import 'services/post_service.dart';
import 'widgets/avatar_image.dart';
import 'utils/error_handler.dart';
import 'providers/theme_provider.dart';

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
    
    // 捕获Flutter框架错误
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // 输出详细错误信息
      print('═══════════════════════════════════════');
      print('Flutter Error:');
      print('Exception: ${details.exception}');
      print('Stack: ${details.stack}');
      print('Library: ${details.library}');
      print('═══════════════════════════════════════');
    };
    
    // 捕获异步错误
    PlatformDispatcher.instance.onError = (error, stack) {
      print('═══════════════════════════════════════');
      print('Platform Error:');
      print('Error: $error');
      print('Stack: $stack');
      print('═══════════════════════════════════════');
      return true;
    };
    
    print('🚀 App starting...');
    // Web平台不支持Platform.operatingSystem，使用kIsWeb判断
    if (kIsWeb) {
      print('📱 Platform: web');
    } else {
      print('📱 Platform: ${Platform.operatingSystem}');
    }
    print('🌐 API Base URL: ${ApiService.baseUrl}');
    print('🔐 User logged in: ${AuthService.isLoggedIn}');
    
    runApp(
      ChangeNotifierProvider.value(
        value: themeProvider,
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    print('═══════════════════════════════════════');
    print('Uncaught Error:');
    print('Error: $error');
    print('Stack: $stack');
    print('═══════════════════════════════════════');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
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
    const HomePage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '个人中心',
          ),
        ],
      ),
    );
  }
}

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
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    
    try {
      final posts = await PostService.getPosts(page: 1, pageSize: _pageSize);
      setState(() {
        _posts = posts;
        _hasMore = posts.length == _pageSize;
      });
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
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final nextPage = _currentPage + 1;
      final morePosts = await PostService.getPosts(page: nextPage, pageSize: _pageSize);
      
      setState(() {
        _posts.addAll(morePosts);
        _currentPage = nextPage;
        _hasMore = morePosts.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
        // 请求失败时，停止尝试加载更多，避免无限请求
        _hasMore = false;
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
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
      final updatedPost = await PostService.toggleLike(postId, userId);
      setState(() {
        _posts = _posts.map((post) {
          if (post.id == postId) {
            return updatedPost;
          }
          return post;
        }).toList();
      });
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
        title: const Text('发现'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              // 添加未读通知标记
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/create-post');
          if (result == true) {
            _fetchPosts();
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPosts,
        child: ListView.builder(
          itemCount: _posts.length + 2, // +1 for header, +1 for loading more
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
                      gradient: LinearGradient(
                        colors: [Colors.blueAccent, Colors.blue[300]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rocket_launch, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            '欢迎使用 Moe Social',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Quick Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickAction(Icons.grid_view_rounded, '全部分类'),
                        _buildQuickAction(Icons.star_rounded, '热门推荐'),
                        _buildQuickAction(Icons.history_rounded, '最近浏览'),
                        _buildQuickAction(Icons.download_for_offline_rounded, '离线内容'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // List Section Title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '热门动态',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }
            
            final postIndex = index - 1;
            if (postIndex < _posts.length) {
              // Post Item
              final post = _posts[postIndex];
              return _buildPostCard(post, postIndex);
            } else {
              // Loading More or End of List
              if (_isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (_hasMore) {
                // Trigger load more when user scrolls to the end
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadMorePosts();
                });
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else {
                // End of List
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '没有更多帖子了',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Colors.blueAccent),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildPostCard(Post post, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Row(
              children: [
                NetworkAvatarImage(
                  imageUrl: post.userAvatar,
                  radius: 24,
                  placeholderIcon: Icons.person,
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
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 帖子内容
            Text(post.content),
            const SizedBox(height: 12),

            // 帖子图片
            if (post.images.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.images.length,
                  itemBuilder: (context, imgIndex) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(post.images[imgIndex]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),

            // 帖子互动
            Row(
              children: [
                IconButton(
                  onPressed: () => _toggleLike(post.id),
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : Colors.grey,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likes}',
                  style: TextStyle(
                    color: post.isLiked ? Colors.red : Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () async {
                    // 跳转到评论页面，返回时刷新帖子列表
                    await Navigator.pushNamed(context, '/comments', arguments: post.id);
                    // 返回后刷新帖子列表，更新评论数
                    _fetchPosts();
                  },
                  icon: const Icon(Icons.comment_outlined, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.comments}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text(
                  '分享',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
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
}
