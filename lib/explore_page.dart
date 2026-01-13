import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'widgets/network_image.dart';
import 'widgets/avatar_image.dart';
import 'models/post.dart';
import 'services/post_service.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _StarNode {
  double x; // 0.0 - 1.0
  double y; // 0.0 - 1.0
  double vx;
  double vy;
  double size;
  Color color;
  Post post;
  
  _StarNode({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.post,
  });
}

class _ExplorePageState extends State<ExplorePage> with TickerProviderStateMixin {
  final List<_StarNode> _stars = [];
  final Random _random = Random();
  Timer? _physicsTimer;
  bool _isLoading = true;
  
  // 详情卡片相关
  Post? _selectedPost;
  late AnimationController _cardController;
  late Animation<double> _cardScaleAnimation;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cardScaleAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    );
    
    _loadData();
  }

  @override
  void dispose() {
    _physicsTimer?.cancel();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // 获取最新帖子作为星星
      final result = await PostService.getPosts(page: 1, pageSize: 15);
      final posts = result['posts'] as List<Post>;
      
      if (mounted) {
        setState(() {
          _stars.clear();
          for (var post in posts) {
            _stars.add(_createRandomStar(post));
          }
          _isLoading = false;
        });
        _startPhysicsLoop();
      }
    } catch (e) {
      print('Explore Load Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  _StarNode _createRandomStar(Post post) {
    // 随机颜色 (使用低饱和度、高亮度的星空色系)
    final colors = [
      const Color(0xFFE0BBE4), // 浅紫
      const Color(0xFF957DAD), // 深紫
      const Color(0xFFD291BC), // 玫红
      const Color(0xFFFEC8D8), // 浅粉
      const Color(0xFFFFDFD3), // 杏色
      const Color(0xFF81C7D4), // 浅蓝
    ];
    
    double size = 60 + _random.nextDouble() * 40; // 60 - 100

    return _StarNode(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      vx: (_random.nextDouble() - 0.5) * 0.002, // 极慢的漂移速度
      vy: (_random.nextDouble() - 0.5) * 0.002,
      size: size,
      color: colors[_random.nextInt(colors.length)],
      post: post,
    );
  }

  void _startPhysicsLoop() {
    _physicsTimer?.cancel();
    _physicsTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      
      // 如果有选中的卡片，暂停物理运动，或者减慢
      if (_selectedPost != null) return;

      setState(() {
        for (var star in _stars) {
          // 更新位置
          star.x += star.vx;
          star.y += star.vy;

          // 边界反弹 (无能量损耗，保持永动)
          if (star.x < 0) {
            star.x = 0;
            star.vx = -star.vx;
          } else if (star.x > 1.0 - (star.size / 400)) { // 粗略估算边界
             // 实际上我们在 LayoutBuilder 里会做精确计算，这里先做个简单的反弹逻辑
             // 为了防止卡在边缘，这里不做强修正，只反转速度
             star.vx = -star.vx;
          }

          if (star.y < 0) {
            star.y = 0;
            star.vy = -star.vy;
          } else if (star.y > 1.0) { // 这里简化处理
            star.vy = -star.vy;
          }
        }
      });
    });
  }

  void _onStarTap(_StarNode star) {
    setState(() {
      _selectedPost = star.post;
    });
    _cardController.forward(from: 0.0);
  }

  void _closeCard() {
    _cardController.reverse().then((_) {
      setState(() {
        _selectedPost = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 深邃星空背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E), // 深蓝夜空
                  Color(0xFF16213E),
                  Color(0xFF243447), // 稍微亮一点的蓝灰
                ],
              ),
            ),
          ),
          
          // 2. 装饰性背景星尘 (静态)
          ...List.generate(20, (index) {
             return Positioned(
               left: _random.nextDouble() * MediaQuery.of(context).size.width,
               top: _random.nextDouble() * MediaQuery.of(context).size.height,
               child: Container(
                 width: 2 + _random.nextDouble() * 3,
                 height: 2 + _random.nextDouble() * 3,
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.2 + _random.nextDouble() * 0.5),
                   shape: BoxShape.circle,
                   boxShadow: [
                     BoxShadow(color: Colors.white, blurRadius: 2 + _random.nextDouble() * 4)
                   ]
                 ),
               ),
             );
          }),

          // 3. 动态星球层
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white54))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: _stars.map((star) {
                    // 修正边界检测，防止飞出
                    if (star.x > 1.0 - star.size / constraints.maxWidth) {
                      star.x = 1.0 - star.size / constraints.maxWidth;
                      star.vx = -star.vx.abs();
                    }
                    if (star.y > 1.0 - star.size / constraints.maxHeight) {
                      star.y = 1.0 - star.size / constraints.maxHeight;
                      star.vy = -star.vy.abs();
                    }

                    return Positioned(
                      left: star.x * constraints.maxWidth,
                      top: star.y * constraints.maxHeight,
                      child: GestureDetector(
                        onTap: () => _onStarTap(star),
                        child: _buildPlanet(star),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          // 4. 详情卡片层 (Modal)
          if (_selectedPost != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeCard, // 点击空白处关闭
                child: Container(
                  color: Colors.black54, // 遮罩
                  child: Center(
                    child: ScaleTransition(
                      scale: _cardScaleAnimation,
                      child: GestureDetector(
                        onTap: () {}, // 拦截点击
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // User Info
                              Row(
                                children: [
                                  NetworkAvatarImage(imageUrl: _selectedPost!.userAvatar, radius: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedPost!.userName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const Text(
                                        '捕捉到一个心情瞬间',
                                        style: TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                                    onPressed: _closeCard,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Content
                              Text(
                                _selectedPost!.content,
                                style: const TextStyle(fontSize: 16, height: 1.5),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_selectedPost!.images.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: NetworkImageWidget(
                                      imageUrl: _selectedPost!.images.first,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final postId = _selectedPost!.id;
                                    _closeCard();
                                    Navigator.pushNamed(context, '/comments', arguments: postId);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7F7FD5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('去互动', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
          // Title
          Positioned(
            top: 50,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '情绪星海',
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 28, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2
                  ),
                ),
                Text(
                  'Explore the Mood Galaxy',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6), 
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanet(_StarNode star) {
    return Container(
      width: star.size,
      height: star.size,
      decoration: BoxDecoration(
        color: star.color.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: star.color.withOpacity(0.6),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 5,
            offset: const Offset(-5, -5), // 高光
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Opacity(
            opacity: 0.8,
            child: star.post.userAvatar.isNotEmpty 
              ? Image.network(
                  star.post.userAvatar, 
                  width: star.size, 
                  height: star.size, 
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.white54),
                )
              : const Icon(Icons.person, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}


