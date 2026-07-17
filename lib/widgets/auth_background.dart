import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_motion.dart';

/// 认证页面统一背景 — 多层渐变 + 浮动光斑 + 顶部光晕。
///
/// 支持 reduce-motion：动画关闭时仅展示静态渐变。
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
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = moeReduceMotion(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 420;
    final orbScale = compact ? 0.68 : 1.0;

    // 4 色光斑 — 紫、蓝、青、粉（萌系）
    final orbColors = [
      const Color(0xFFE0C3FC).withValues(alpha: 0.38),
      const Color(0xFF8EC5FC).withValues(alpha: 0.30),
      const Color(0xFF91EAE4).withValues(alpha: 0.30),
      const Color(0xFFFFB6C1).withValues(alpha: 0.26), // 粉色 — 萌感
    ];

    return Scaffold(
      backgroundColor: MoeTokens.surface0,
      body: Stack(
        children: [
          // ── 多层背景渐变（带微紫调）────────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFFCFF),
                  Color(0xFFF5F0FF), // 微紫
                  Color(0xFFF0F2FF),
                  Color(0xFFF5F7FA),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.3, 0.65, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),

          // ── 顶部光晕条（模拟光源）──────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MoeTokens.primary.withValues(alpha: 0.06),
                      MoeTokens.secondary.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // ── 浮动光斑（Lissajous 曲线运动）────────────────────
          IgnorePointer(
            child: reduceMotion
                ? const SizedBox.shrink()
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = _controller.value * math.pi * 2;
                      return Stack(
                        children: [
                          // Orb 1 — 左上紫
                          Positioned(
                            top: -80 + _lissajousY(t, 1.0, 0.7, 28),
                            left: -50 + _lissajousX(t, 1.0, 1.3, 22),
                            child: _GradientOrb(
                              size: 380 * orbScale,
                              colors: [orbColors[0], Colors.transparent],
                            ),
                          ),
                          // Orb 2 — 右上蓝
                          Positioned(
                            top: size.height * 0.15 +
                                _lissajousY(t, 0.8, 1.1, 26),
                            right: -100 + _lissajousX(t, 1.2, 0.9, 18),
                            child: _GradientOrb(
                              size: 300 * orbScale,
                              colors: [orbColors[1], Colors.transparent],
                              radius: 0.62,
                            ),
                          ),
                          // Orb 3 — 左下青
                          Positioned(
                            bottom: -60 + _lissajousY(t, 1.3, 0.6, 24),
                            left: -30 + _lissajousX(t, 0.7, 1.4, 16),
                            child: _GradientOrb(
                              size: 340 * orbScale,
                              colors: [orbColors[2], Colors.transparent],
                            ),
                          ),
                          // Orb 4 — 右中粉（萌系）
                          Positioned(
                            top: size.height * 0.55 +
                                _lissajousY(t, 0.9, 1.2, 20),
                            right: -60 + _lissajousX(t, 1.1, 0.8, 14),
                            child: _GradientOrb(
                              size: 260 * orbScale,
                              colors: [orbColors[3], Colors.transparent],
                              radius: 0.58,
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

  /// Lissajous X 轴位移：x = A * sin(a*t + δ)
  double _lissajousX(double t, double a, double b, double amplitude) {
    return math.sin(a * t) * amplitude + math.cos(b * t) * amplitude * 0.4;
  }

  /// Lissajous Y 轴位移：y = A * sin(b*t)
  double _lissajousY(double t, double a, double b, double amplitude) {
    return math.sin(a * t) * amplitude * 0.6 + math.cos(b * t) * amplitude * 0.5;
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
