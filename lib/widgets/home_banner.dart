import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'daily_quote_widget.dart';

class HomeBanner extends StatefulWidget {
  const HomeBanner({super.key});

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 92, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7F7FD5),
            Color(0xFF86A8E7),
            Color(0xFF91EAE4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // 动态气泡 1
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                right: -20 + math.sin(_controller.value * 2 * math.pi) * 10,
                top: -20 + math.cos(_controller.value * 2 * math.pi) * 10,
                child: child!,
              );
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // 动态气泡 2
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                left: -30 + math.cos(_controller.value * 2 * math.pi) * 8,
                bottom: -30 + math.sin(_controller.value * 2 * math.pi) * 8,
                child: child!,
              );
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // 中心内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.explore_rounded,
                        size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '发现更可爱的世界',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black12,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: DailyQuoteWidget(embedded: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
