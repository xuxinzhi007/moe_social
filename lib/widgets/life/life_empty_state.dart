import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';

/// 数字生命世界空状态引导组件。
/// 新用户首次进入时展示功能引导，帮助用户了解世界玩法。
class LifeEmptyState extends StatefulWidget {
  final VoidCallback onDismissed;

  const LifeEmptyState({super.key, required this.onDismissed});

  @override
  State<LifeEmptyState> createState() => _LifeEmptyStateState();
}

class _LifeEmptyStateState extends State<LifeEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MoeTokens.motionFadeDuration,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: MoeTokens.space2xl,
            vertical: MoeTokens.space3xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 世界图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: MoeTokens.heroGradient,
                  shape: BoxShape.circle,
                  boxShadow: MoeTokens.shadowMd(),
                ),
                child: const Icon(
                  Icons.public,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: MoeTokens.spaceXl),
              // 标题
              const Text(
                '这是你的数字生命世界',
                style: TextStyle(
                  fontSize: MoeTokens.textXl,
                  fontWeight: MoeTokens.fontWeightTitle,
                  color: MoeTokens.titleText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              const Text(
                '了解以下功能，开始你的旅程',
                style: TextStyle(
                  fontSize: MoeTokens.textBase,
                  color: MoeTokens.hintText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MoeTokens.space2xl),
              // 引导卡片
              _GuideCard(
                emoji: '🌍',
                title: '观察世界',
                description: '生命会在世界中自由移动和互动',
                delay: 0,
              ),
              const SizedBox(height: MoeTokens.spaceMd),
              _GuideCard(
                emoji: '👆',
                title: '点击互动',
                description: '点击实体可以喂食、抚摸，照顾它们',
                delay: 1,
              ),
              const SizedBox(height: MoeTokens.spaceMd),
              _GuideCard(
                emoji: '✨',
                title: '发现惊喜',
                description: '每个生命都有独特个性，一切皆有可能',
                delay: 2,
              ),
              const SizedBox(height: MoeTokens.space3xl),
              // 确认按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: widget.onDismissed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MoeTokens.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(MoeTokens.radiusButton),
                    ),
                    elevation: 0,
                    shadowColor: MoeTokens.primary.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    '我知道了',
                    style: TextStyle(
                      fontSize: MoeTokens.textMd,
                      fontWeight: MoeTokens.fontWeightSubtitle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个引导卡片
class _GuideCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final int delay;

  const _GuideCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        children: [
          // Emoji 图标容器
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: MoeTokens.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          // 文案
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: MoeTokens.textMd,
                    fontWeight: MoeTokens.fontWeightSubtitle,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceXs),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: MoeTokens.textSm,
                    color: MoeTokens.hintText,
                    height: 1.4,
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
