import 'package:flutter/material.dart';
import 'dart:math' as math;

class AuthBackground extends StatefulWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Moe 配色 - 更柔和的梦幻渐变
    final color1 = const Color(0xFFE0C3FC).withOpacity(0.4); // 浅紫
    final color2 = const Color(0xFF8EC5FC).withOpacity(0.4); // 浅蓝
    final color3 = const Color(0xFF91EAE4).withOpacity(0.4); // 薄荷

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. 基础渐变层
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFDFBFD), Color(0xFFF4F7F9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 2. 动态流动极光 (使用 AnimatedBuilder + CustomPaint 实现流体效果会比较重，这里用位置动画模拟)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  // 左上角流体
                  Positioned(
                    top: -100 + math.sin(_controller.value * math.pi) * 30,
                    left: -50 + math.cos(_controller.value * math.pi) * 30,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [color1, Colors.transparent],
                          radius: 0.7,
                        ),
                      ),
                    ),
                  ),
                  // 右中流体
                  Positioned(
                    top: 200 + math.cos(_controller.value * math.pi) * 40,
                    right: -100 + math.sin(_controller.value * math.pi) * 20,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [color2, Colors.transparent],
                          radius: 0.6,
                        ),
                      ),
                    ),
                  ),
                  // 左下角流体
                  Positioned(
                    bottom: -50 + math.sin(_controller.value * 2 * math.pi) * 30,
                    left: -50 + math.cos(_controller.value * 2 * math.pi) * 20,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [color3, Colors.transparent],
                          radius: 0.7,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. 玻璃拟态遮罩 (可选，增加模糊感让背景更朦胧)
          // BackdropFilter(
          //   filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          //   child: Container(color: Colors.transparent),
          // ),

          // 4. 内容层
          SafeArea(child: widget.child),
        ],
      ),
    );
  }
}
