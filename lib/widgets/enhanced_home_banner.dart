import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'daily_quote_widget.dart';

class EnhancedHomeBanner extends StatefulWidget {
  const EnhancedHomeBanner({super.key});

  @override
  State<EnhancedHomeBanner> createState() => _EnhancedHomeBannerState();
}

class _EnhancedHomeBannerState extends State<EnhancedHomeBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _bannerItems = [
    {
      'icon': Icons.explore_rounded,
      'title': '发现更可爱的世界',
      'subtitle': '分享生活，发现美好',
      'gradient': [const Color(0xFF7F7FD5), const Color(0xFF86A8E7), const Color(0xFF91EAE4)],
    },
    {
      'icon': Icons.favorite_rounded,
      'title': '关注感兴趣的人',
      'subtitle': '不错过任何精彩瞬间',
      'gradient': [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E), const Color(0xFFFFB4B4)],
    },
    {
      'icon': Icons.chat_bubble_rounded,
      'title': '加入热门话题',
      'subtitle': '与志同道合的朋友交流',
      'gradient': [const Color(0xFF4ECDC4), const Color(0xFF6EE7DE), const Color(0xFF8FF2EA)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // 自动轮播
    Future.delayed(const Duration(seconds: 5), _autoPlay);
  }

  void _autoPlay() {
    if (mounted) {
      final nextPage = (_currentPage + 1) % _bannerItems.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      Future.delayed(const Duration(seconds: 5), _autoPlay);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 92, 16, 12),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 页面视图
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _bannerItems.length,
              itemBuilder: (context, index) {
                return _buildBannerPage(_bannerItems[index]);
              },
            ),

            // 指示器
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _bannerItems.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // 左右切换按钮
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () {
                    if (_currentPage > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  icon: Icon(
                    Icons.chevron_left,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () {
                    if (_currentPage < _bannerItems.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  icon: Icon(
                    Icons.chevron_right,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerPage(Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item['gradient'],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // 动态气泡
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

          // 内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                    child: Icon(
                      item['icon'],
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
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
                const SizedBox(height: 4),
                Text(
                  item['subtitle'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
