import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProfileBg extends StatefulWidget {
  const ProfileBg({super.key});

  @override
  State<ProfileBg> createState() => _ProfileBgState();
}

class _ProfileBgState extends State<ProfileBg> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 渐变背景
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF7F7FD5),
                Color(0xFF86A8E7),
                Color(0xFF91EAE4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
        ),
        
        // 动态装饰圆 1 (右上)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              right: -40 + math.sin(_controller.value * math.pi) * 15,
              top: -40 + math.cos(_controller.value * math.pi) * 15,
              child: child!,
            );
          },
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // 动态装饰圆 2 (左下)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              left: -60 + math.cos(_controller.value * math.pi) * 20,
              bottom: 40 + math.sin(_controller.value * math.pi) * 20, // 稍微靠上一点，因为 ProfileHeader 有弧度
              child: child!,
            );
          },
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
