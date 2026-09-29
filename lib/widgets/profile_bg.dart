import 'package:flutter/material.dart';

/// 个人主页顶部渐变。装饰圆保持静止，避免进页转场时每帧重绘。
class ProfileBg extends StatelessWidget {
  const ProfileBg({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
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
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          right: -48,
          top: -56,
          child: _BgOrb(diameter: 180, alpha: 0.10),
        ),
        Positioned(
          left: -72,
          bottom: 24,
          child: _BgOrb(diameter: 140, alpha: 0.06),
        ),
      ],
    );
  }
}

class _BgOrb extends StatelessWidget {
  const _BgOrb({required this.diameter, required this.alpha});

  final double diameter;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }
}
