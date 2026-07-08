import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/ai/ai_brand_tokens.dart';

/// 探索页「玩法」分区入口卡片。
enum ExploreFeatureCardVariant { hero, compact }

class ExploreFeatureCard extends StatelessWidget {
  const ExploreFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.variant = ExploreFeatureCardVariant.compact,
    this.gradient = AiBrandTokens.heroGradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final ExploreFeatureCardVariant variant;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final isHero = variant == ExploreFeatureCardVariant.hero;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(isHero ? 24 : 20),
        child: Ink(
          height: isHero ? 148 : 88,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(isHero ? 24 : 20),
            boxShadow: [
              BoxShadow(
                color: AiBrandTokens.primary.withValues(alpha: 0.22),
                blurRadius: isHero ? 24 : 14,
                offset: Offset(0, isHero ? 10 : 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                top: -12,
                child: Container(
                  width: isHero ? 100 : 72,
                  height: isHero ? 100 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isHero ? 20 : 16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isHero ? 12 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(isHero ? 16 : 14),
                      ),
                      child: Icon(icon,
                          color: Colors.white, size: isHero ? 28 : 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isHero ? 20 : 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: isHero ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: isHero ? 13 : 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
