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
import 'wallet_page.dart';
import 'recharge_page.dart';
import 'explore_page.dart';
import 'gacha_page.dart';
import 'models/post.dart';
import 'services/post_service.dart';
import 'user_profile_page.dart';
import 'widgets/avatar_image.dart';
import 'widgets/network_image.dart';
import 'widgets/post_skeleton.dart';
import 'widgets/fade_in_up.dart';
import 'utils/error_handler.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';

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
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: notificationProvider),
        ],
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
    GachaPage(), // 扭蛋机回归
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
    // 如果正在刷新、正在加载更多或没有更多数据，则不执行
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    
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
          itemCount: _isLoading && _posts.isEmpty 
              ? 6 // 显示骨架屏
              : _posts.length + 2, // +1 for header, +1 for loading more
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
            
            final postIndex = index - 1;
            if (postIndex < _posts.length) {
              // Post Item
              final post = _posts[postIndex];
              return FadeInUp(
                delay: Duration(milliseconds: 30 * (postIndex % 5)),
                child: _buildPostCard(post, postIndex),
              );
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
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.grey[300], size: 40),
                        const SizedBox(height: 8),
                        Text(
                          '已经到底啦 ~',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0, // 去除默认阴影，使用边框或自定义阴影
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[100]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                          width: 2
                        ),
                      ),
                      child: NetworkAvatarImage(
                        imageUrl: post.userAvatar,
                        radius: 22,
                        placeholderIcon: Icons.person,
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
            Text(
              post.content,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 12),

            // 帖子图片
            if (post.images.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: post.images.length,
                  itemBuilder: (context, imgIndex) {
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 200,
                      child: GestureDetector(
                        onTap: () {},
                        child: Hero(
                          tag: 'post_img_${post.id}_$imgIndex',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: NetworkImageWidget(
                              imageUrl: post.images[imgIndex],
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600], size: 22),
            const SizedBox(width: 6),
            Text(
              count?.toString() ?? label ?? '',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
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
