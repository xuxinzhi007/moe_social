import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';

class AuthBackground extends StatefulWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
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
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 420;
    final orbScale = compact ? 0.72 : 1.0;
    final color1 = const Color(0xFFE0C3FC).withValues(alpha: 0.34);
    final color2 = const Color(0xFF8EC5FC).withValues(alpha: 0.28);
    final color3 = const Color(0xFF91EAE4).withValues(alpha: 0.28);

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFFCFF),
                  Color(0xFFF7F9FD),
                  MoeTokens.pageBackground,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox.expand(),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      top: -90 + math.sin(_controller.value * math.pi) * 24,
                      left: -60 + math.cos(_controller.value * math.pi) * 22,
                      child: _GradientOrb(
                        size: 360 * orbScale,
                        colors: [color1, Colors.transparent],
                      ),
                    ),
                    Positioned(
                      top: size.height * 0.18 +
                          math.cos(_controller.value * math.pi) * 26,
                      right: -110 + math.sin(_controller.value * math.pi) * 18,
                      child: _GradientOrb(
                        size: 280 * orbScale,
                        colors: [color2, Colors.transparent],
                        radius: 0.62,
                      ),
                    ),
                    Positioned(
                      bottom:
                          -70 + math.sin(_controller.value * 2 * math.pi) * 24,
                      left: -40 + math.cos(_controller.value * 2 * math.pi) * 16,
                      child: _GradientOrb(
                        size: 320 * orbScale,
                        colors: [color3, Colors.transparent],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(child: widget.child),
        ],
      ),
    );
  }
}

class _GradientOrb extends StatelessWidget {
  const _GradientOrb({
    required this.size,
    required this.colors,
    this.radius = 0.72,
  });

  final double size;
  final List<Color> colors;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          radius: radius,
        ),
      ),
    );
  }
}
