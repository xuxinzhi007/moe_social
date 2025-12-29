import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'widgets/fade_in_up.dart';
import 'widgets/avatar_image.dart';
import 'models/post.dart';
import 'services/post_service.dart'; // 暂时借用 PostService 获取数据

class GachaPage extends StatefulWidget {
  const GachaPage({super.key});

  @override
  State<GachaPage> createState() => _GachaPageState();
}

class _GachaPageState extends State<GachaPage> with TickerProviderStateMixin {
  // 动画控制器
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  late AnimationController _ballDropController;
  late Animation<double> _ballDropAnimation;

  // 状态
  bool _isPlaying = false;
  bool _showResult = false;
  Post? _gachaResult;
  Color _currentBallColor = Colors.blueAccent;

  // 扭蛋球颜色池
  final List<Color> _ballColors = [
    const Color(0xFFFF9A9E), // 樱花粉
    const Color(0xFFFECFEF), // 浅粉
    const Color(0xFFA18CD1), // 薰衣草
    const Color(0xFF84FAB0), // 薄荷
    const Color(0xFF8FD3F4), // 天空
  ];

  @override
  void initState() {
    super.initState();
    
    // 震动动画：机器摇晃
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // 掉落动画：球从出口滚出
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
    _shakeController.dispose();
    _ballDropController.dispose();
    super.dispose();
  }

  // 开始抽扭蛋
  void _startGacha() async {
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
      _showResult = false;
      _currentBallColor = _ballColors[Random().nextInt(_ballColors.length)];
    });

    // 1. 播放震动动画
    await _shakeController.forward();
    _shakeController.reverse();

    // 2. 模拟网络请求 (获取随机内容)
    // 实际项目中这里调用 ApiService.drawGacha()
    await _fetchRandomPost();

    // 3. 播放掉落动画
    await _ballDropController.forward();

    // 4. 短暂停顿后打开
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _showResult = true;
      });
      _showResultDialog();
    }

    // 重置动画状态
    _ballDropController.reset();
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _fetchRandomPost() async {
    try {
      // 临时逻辑：获取第一页帖子，然后随机选一个
      // 后续应替换为后端专门的随机接口
      final posts = await PostService.getPosts(page: 1, pageSize: 20);
      if (posts.isNotEmpty) {
        setState(() {
          _gachaResult = posts[Random().nextInt(posts.length)];
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
                    // 顶部彩带装饰
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
                    
                    // 用户信息
                    Row(
                      children: [
                        NetworkAvatarImage(
                          imageUrl: _gachaResult!.userAvatar,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Column(
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 内容
                    Text(
                      _gachaResult!.content,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      textAlign: TextAlign.center,
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
                    
                    // 按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: const Text('收下', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // 这里可以跳转到回复页面
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentBallColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: const Text('回复'),
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
      backgroundColor: const Color(0xFFFDFBF7), // 温暖的米色背景
      appBar: AppBar(
        title: const Text('心情扭蛋机', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 背景装饰
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
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 主体内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // 扭蛋机主体
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value * sin(DateTime.now().millisecondsSinceEpoch), 0),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 机器外壳
                      Container(
                        width: 280,
                        height: 400,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB7C5), // 萌粉色
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
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(100), // 半圆
                                border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                              ),
                              child: Stack(
                                children: [
                                  // 里面的球 (静态装饰)
                                  for (int i = 0; i < 8; i++)
                                    Positioned(
                                      top: 40.0 + Random().nextInt(100),
                                      left: 20.0 + Random().nextInt(180),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _ballColors[i % _ballColors.length],
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 5,
                                              offset: const Offset(2, 2),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // 操作区
                            const Spacer(),
                            Container(
                              width: 180,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(60), bottom: Radius.circular(20)),
                                border: Border.all(color: Colors.pink[100]!, width: 2),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.touch_app_rounded, color: Colors.pinkAccent, size: 30),
                                    const SizedBox(height: 8),
                                    Text(
                                      '点击抽取',
                                      style: TextStyle(
                                        color: Colors.pink[300],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                      // 出货口动画球
                      Positioned(
                        bottom: 40,
                        child: AnimatedBuilder(
                          animation: _ballDropAnimation,
                          builder: (context, child) {
                            // 简单的掉落位移
                            double yOffset = 100 * _ballDropAnimation.value;
                            double scale = _ballDropAnimation.value;
                            return Opacity(
                              opacity: _ballDropAnimation.value,
                              child: Transform.translate(
                                offset: Offset(0, yOffset),
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _currentBallColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: _currentBallColor.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // 按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: SizedBox(
                    width: 200,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isPlaying ? null : _startGacha,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7F7FD5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFF7F7FD5).withOpacity(0.5),
                      ),
                      child: _isPlaying
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.casino_rounded, size: 28),
                                SizedBox(width: 12),
                                Text(
                                  '投入一枚硬币',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

