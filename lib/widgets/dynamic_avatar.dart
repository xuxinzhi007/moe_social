import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as math;
import 'avatar_image.dart';

/// 动态头像组件
/// 负责将普通头像包裹在特效框中
class DynamicAvatar extends StatefulWidget {
  final String avatarUrl;
  final double size;
  final String? frameId; // 传入头像框ID，如果为null则不显示框

  const DynamicAvatar({
    super.key, 
    required this.avatarUrl, 
    this.size = 60,
    this.frameId,
  });

  @override
  State<DynamicAvatar> createState() => _DynamicAvatarState();
}

class _DynamicAvatarState extends State<DynamicAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 定义一个无限循环的动画控制器，用于驱动特效
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 原始头像 (稍微缩小一点，给边框留位置)
          Padding(
            padding: const EdgeInsets.all(4.0), 
            child: NetworkAvatarImage(
              imageUrl: widget.avatarUrl,
              radius: widget.size / 2 - 4,
            ),
          ),

          // 2. 动态边框层
          if (widget.frameId != null)
            _buildFrameEffect(widget.frameId!),
        ],
      ),
    );
  }

  Widget _buildFrameEffect(String frameId) {
    // 优先处理 Lottie 动画 (约定以 frame_lottie_ 开头，或者特定 ID)
    if (frameId == 'frame_lottie_test' || frameId == 'frame_lottie_01') {
      return Transform.scale(
        scale: 1.4, // Lottie 动画通常需要比头像大一圈，根据实际素材调整
        child: Lottie.asset(
          'assets/frames/Avatar Frame.json',
          fit: BoxFit.contain,
        ),
      );
    }

    // 根据 ID 返回不同的特效 Widget
    // 实际项目中这里可以查表或者加载资源
    switch (frameId) {
      case 'frame_cyber_01':
        return _buildCyberFrame();
      case 'frame_sakura_01':
        return _buildSakuraFrame();
      default:
        return const SizedBox();
    }
  }

  // 示例特效1：赛博流光 (旋转的渐变圆环)
  Widget _buildCyberFrame() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Colors.transparent, 
                  Colors.cyanAccent, 
                  Colors.purpleAccent, 
                  Colors.transparent
                ],
                stops: [0.0, 0.5, 0.8, 1.0],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
          ),
        );
      },
    );
  }

  // 示例特效2：樱花 (简单的闪烁光圈，实际可以用图片)
  Widget _buildSakuraFrame() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.pinkAccent.withOpacity((math.sin(_controller.value * 2 * math.pi) + 1) / 2 * 0.5 + 0.2),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.3),
                blurRadius: 10 * ((math.sin(_controller.value * 2 * math.pi) + 1) / 2),
              )
            ]
          ),
        );
      },
    );
  }
}
