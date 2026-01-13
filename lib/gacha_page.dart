import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';
import 'dart:async';
import 'widgets/avatar_image.dart';
import 'models/post.dart';
import 'services/post_service.dart';

class GachaPage extends StatefulWidget {
  const GachaPage({super.key});

  @override
  State<GachaPage> createState() => _GachaPageState();
}

class _GachaBall {
  double x; // 0.0 - 1.0 (相对位置)
  double y; // 0.0 - 1.0
  double vx; // 速度 X
  double vy; // 速度 Y
  Color color;
  double rotation;
  double rotateSpeed;
  double size;
  
  _GachaBall({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    required this.color,
    this.rotation = 0,
    this.rotateSpeed = 0,
    this.size = 36, // 稍微调小一点，避免太拥挤
  });
}

class _GachaPageState extends State<GachaPage> with TickerProviderStateMixin {
  late AnimationController _ballDropController;
  late Animation<double> _ballDropAnimation;

  Timer? _physicsTimer;
  final Random _random = Random();
  bool _isUpdating = false; // 防止重复更新

  bool _isPlaying = false;
  bool _showResult = false;
  Post? _gachaResult;
  Color _currentBallColor = Colors.blueAccent;

  final List<_GachaBall> _balls = [];
  final List<Color> _ballColors = [
    const Color(0xFFFF9A9E),
    const Color(0xFFFECFEF),
    const Color(0xFFA18CD1),
    const Color(0xFF84FAB0),
    const Color(0xFF8FD3F4),
  ];

  @override
  void initState() {
    super.initState();
    
    // 初始化小球 (位置在底部堆叠)
    for (int i = 0; i < 12; i++) {
      _balls.add(_GachaBall(
        x: 0.2 + _random.nextDouble() * 0.6,
        y: 0.8 + _random.nextDouble() * 0.1,
        vx: (_random.nextDouble() - 0.5) * 0.01,
        vy: 0,
        color: _ballColors[i % _ballColors.length],
        rotation: _random.nextDouble() * 2 * pi,
        rotateSpeed: (_random.nextDouble() - 0.5) * 0.1,
      ));
    }

    _ballDropController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _ballDropAnimation = CurvedAnimation(
      parent: _ballDropController,
      curve: Curves.bounceOut,
    );
  }

  @override
  void dispose() {
    _physicsTimer?.cancel();
    _ballDropController.dispose();
    super.dispose();
  }

  // 当页面变为不可见时停止物理循环
  @override
  void deactivate() {
    super.deactivate();
    _physicsTimer?.cancel();
    _isUpdating = false;
  }

    // 物理引擎核心循环
  void _startPhysicsLoop() {
    _physicsTimer?.cancel();
    // 60FPS 左右
    _physicsTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // 更新物理状态（不触发 setState）
      // 使用变量副本或同步锁逻辑来避免并发修改问题（虽然Dart是单线程，但逻辑上要清晰）
      // 这里没有直接修改 _balls 列表长度，只是修改元素属性，是安全的

      for (var ball in _balls) {
        if (_isPlaying) {
          // --- 搅动模式 (强风乱飞) ---
          
          // 1. 施加力
          // 向上浮力 (抗重力)
          ball.vy -= 0.002; 
          // 随机扰动 (模拟气流湍流)
          ball.vx += (_random.nextDouble() - 0.5) * 0.005;
          ball.vy += (_random.nextDouble() - 0.5) * 0.005;

          // 限制最大速度 (防止穿墙)
          ball.vx = ball.vx.clamp(-0.03, 0.03);
          ball.vy = ball.vy.clamp(-0.03, 0.03);

          // 2. 更新位置
          ball.x += ball.vx;
          ball.y += ball.vy;
          ball.rotation += ball.vx * 10; // 旋转随速度变化

          // 3. 边界反弹 (Box Collision)
          // 考虑球体大小，假设容器大概 200x200，球36，占比约 0.18
          double ballRatio = 0.18; 
          
          // 左右墙壁
          if (ball.x < 0) {
            ball.x = 0;
            ball.vx = -ball.vx * 0.8; // 反弹并损耗能量
          } else if (ball.x > 1.0 - ballRatio) {
            ball.x = 1.0 - ballRatio;
            ball.vx = -ball.vx * 0.8;
          }

          // 上下墙壁
          if (ball.y < 0) {
            ball.y = 0;
            ball.vy = -ball.vy * 0.8;
          } else if (ball.y > 1.0 - ballRatio) {
            ball.y = 1.0 - ballRatio;
            ball.vy = -ball.vy * 0.8;
          }

        } else {
          // --- 沉降模式 (重力恢复) ---
          
          // 1. 施加重力
          ball.vy += 0.002;
          // 空气阻力
          ball.vx *= 0.98;
          
          // 2. 更新位置
          ball.x += ball.vx;
          ball.y += ball.vy;
          ball.rotation += ball.vx * 5;

          double ballRatio = 0.18; 
          
          // 底部碰撞
          if (ball.y > 1.0 - ballRatio) {
            ball.y = 1.0 - ballRatio;
            // 落地反弹 (能量损失大，甚至不反弹直接停)
            ball.vy = -ball.vy * 0.5; 
            // 地面摩擦力
            ball.vx *= 0.9;
          }
          
          // 左右墙壁限制
          if (ball.x < 0) { ball.x = 0; ball.vx = -ball.vx * 0.5; }
          if (ball.x > 1.0 - ballRatio) { ball.x = 1.0 - ballRatio; ball.vx = -ball.vx * 0.5; }
        }
      }
      
      // 使用 SchedulerBinding 确保在帧结束后更新，避免布局冲突
      if (!_isUpdating) {
        _isUpdating = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _isUpdating = false;
          if (mounted) {
            setState(() {
              // setState 触发重建，但物理状态已经在上面更新了
            });
          }
        });
      }
    });
  }

  void _startGacha() async {
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
      _showResult = false;
      _currentBallColor = _balls[_random.nextInt(_balls.length)].color;
    });

    // 1. 启动物理循环
    _startPhysicsLoop();

    // 2. 模拟请求
    await _fetchRandomPost();

    // 持续搅动 2.5秒
    await Future.delayed(const Duration(milliseconds: 2500));

    // 3. 停止搅动，球自然落下
    setState(() {
      _isPlaying = false;
    });
    
    // 4. 出货动画
    await _ballDropController.forward();

    // 5. 显示结果
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _showResult = true;
      });
      _showResultDialog();
    }

    _ballDropController.reset();
  }

  Future<void> _fetchRandomPost() async {
    try {
      final result = await PostService.getPosts(page: 1, pageSize: 20);
      final posts = result['posts'] as List<Post>;
      if (posts.isNotEmpty) {
        setState(() {
          _gachaResult = posts[_random.nextInt(posts.length)];
        });
      }
    } catch (e) {
      print('Gacha Error: $e');
    }
  }

  void _showResultDialog() {
    if (_gachaResult == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _currentBallColor.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _currentBallColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome_rounded, color: _currentBallColor, size: 30),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        NetworkAvatarImage(
                          imageUrl: _gachaResult!.userAvatar,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _gachaResult!.userName,
                                style: const TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                '来自于远方的扭蛋',
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Text(
                          _gachaResult!.content,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (_gachaResult!.images.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _gachaResult!.images.first,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 150,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('收下', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/comments', arguments: _gachaResult!.id);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentBallColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('回复Ta'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: const Text('心情扭蛋机', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand, // 填满屏幕
        children: [
          // 装饰背景
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.pink[50],
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // 机器主体 (居中)
          Center(
            child: GestureDetector(
              onTap: _isPlaying ? null : _startGacha,
              child: Container(
                width: 280,
                height: 400,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB7C5), Color(0xFFFFA5B5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Column(
                  children: [
                    // 玻璃罩
                    Container(
                      margin: const EdgeInsets.all(20),
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(-5, -5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
                              return const SizedBox.shrink();
                            }
                            return Stack(
                              children: [
                                // 动态小球
                                for (var ball in _balls)
                                  Positioned(
                                    left: ball.x * constraints.maxWidth, 
                                    top: ball.y * constraints.maxHeight,
                                    child: Transform.rotate(
                                      angle: ball.rotation,
                                      child: Container(
                                        width: ball.size,
                                        height: ball.size,
                                        decoration: BoxDecoration(
                                          color: ball.color,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 2,
                                              offset: const Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                            // 装饰性机械结构 (仅在运行时旋转)
                            Container(
                              height: 120,
                              alignment: Alignment.center,
                              child: _isPlaying 
                                  ? TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: 8 * pi),
                                      duration: const Duration(seconds: 2),
                                      builder: (context, value, child) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Transform.rotate(
                                              angle: value,
                                              child: Icon(Icons.settings_rounded, color: Colors.white.withOpacity(0.9), size: 48),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Gachaing...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.stars_rounded, color: Colors.white.withOpacity(0.6), size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Moe Social',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            fontFamily: 'Courier', // 机械感字体
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          
          // 投币按钮 (固定在底部)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 220,
                height: 64,
                child: ElevatedButton(
                  onPressed: _isPlaying ? null : _startGacha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7F7FD5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF7F7FD5).withOpacity(0.5),
                  ),
                  child: _isPlaying
                      ? const Text('扭蛋中...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.monetization_on_rounded, size: 28, color: Colors.amberAccent),
                            SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('投入硬币', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('今日剩余: 3次', style: TextStyle(fontSize: 10, color: Colors.white70)),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          // 出货口动画球 (放在最顶层，绝对定位)
          // 目标：停在齿轮位置 (机器下半部分)
          Align(
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _ballDropAnimation,
              builder: (context, child) {
                // 初始位置：玻璃罩底部 (50) -> 结束位置：齿轮区域 (130)
                // 使用非线性插值模拟弹跳
                double value = _ballDropAnimation.value;
                double yOffset = 50 + (80 * value); 
                double scale = 0.5 + (1.0 * value); // 从小变大
                
                // 旋转动画 (滚出来)
                double rotation = value * 2 * pi;

                if (value == 0) return const SizedBox.shrink();

                return Transform.translate(
                  offset: Offset(0, yOffset),
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 80, // 变大一点，更有满足感
                        height: 80,
                        decoration: BoxDecoration(
                          color: _currentBallColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: _currentBallColor.withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        // 加个问号或者礼物图标
                        child: Icon(Icons.question_mark_rounded, color: Colors.white.withOpacity(0.8), size: 40),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
