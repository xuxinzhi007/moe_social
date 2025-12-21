import 'package:flutter/material.dart';
import 'login_page.dart';
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
import 'models/post.dart';
import 'services/post_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moe Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
      initialRoute: '/login',
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

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final posts = await PostService.getPosts();
      setState(() {
        _posts = posts;
      });
    } catch (e) {
      print('Failed to fetch posts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      final updatedPost = await PostService.toggleLike(postId);
      setState(() {
        _posts = _posts.map((post) {
          if (post.id == postId) {
            return updatedPost;
          }
          return post;
        }).toList();
      });
    } catch (e) {
      print('Failed to toggle like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
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
      body: SingleChildScrollView(
        child: Column(
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
            // List Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '热门动态',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return _buildPostCard(post, index);
                    },
                  ),
          ],
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
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(post.userAvatar),
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
                  onPressed: () {
                    Navigator.pushNamed(context, '/comments', arguments: post.id);
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
