import 'package:flutter/material.dart';

import '../../../theme/moe_tokens.dart';
import '../../../widgets/ai/ai_brand_tokens.dart';

/// 酒馆首页顶部 Hero，与探索页「AI 酒馆」入口视觉一致。
class TavernHeroCard extends StatelessWidget {
  const TavernHeroCard({
    super.key,
    required this.agentCount,
    required this.providerCount,
    required this.onOpenProvidersTab,
  });

  final int agentCount;
  final int providerCount;
  final VoidCallback onOpenProvidersTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(MoeTokens.spaceLg, MoeTokens.spaceLg, MoeTokens.spaceLg, MoeTokens.spaceSm),
      decoration: BoxDecoration(
        gradient: AiBrandTokens.heroGradient,
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
        boxShadow: [
          BoxShadow(
            color: AiBrandTokens.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MoeTokens.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(MoeTokens.spaceMd),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: onOpenProvidersTab,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('模型来源'),
                    ),
                  ],
                ),
                const SizedBox(height: MoeTokens.spaceLg),
                const Text(
                  '把角色、世界观、模型来源放进同一个酒馆入口。',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MoeTokens.textXl,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceSm),
                Text(
                  '支持自定义 API、中转站、服务器模型，以及可套用的角色模板。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: MoeTokens.textBase,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceMd),
                Wrap(
                  spacing: MoeTokens.spaceSm,
                  runSpacing: MoeTokens.spaceSm,
                  children: [
                    _chip('角色 $agentCount', Icons.person_outline_rounded),
                    _chip('Provider $providerCount', Icons.hub_outlined),
                    _chip('世界书', Icons.menu_book_outlined),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceMd, vertical: MoeTokens.spaceSm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: MoeTokens.textBase, color: Colors.white),
          const SizedBox(width: MoeTokens.spaceXs),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: MoeTokens.textXs,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
