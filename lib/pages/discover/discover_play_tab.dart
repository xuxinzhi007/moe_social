import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../../utils/main_tab_navigation.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import 'widgets/explore_feature_card.dart';

/// 探索页 · AI 互动（社交增强，不含游戏入口）。
class DiscoverPlayTab extends StatelessWidget {
  const DiscoverPlayTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
      children: [
        Text(
          'AI 伙伴',
          style: TextStyle(
            fontSize: MoeTokens.textLg,
            fontWeight: FontWeight.w800,
            color: AiBrandTokens.titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '与智能体对话、获取灵感，用于丰富动态与私信互动。',
          style: TextStyle(
            fontSize: MoeTokens.textBase,
            height: 1.45,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        ExploreFeatureCard(
          variant: ExploreFeatureCardVariant.hero,
          title: 'AI 酒馆',
          subtitle: '角色、世界观与模型来源，服务社交场景下的对话互动',
          icon: Icons.auto_awesome_rounded,
          gradient: AiBrandTokens.heroGradient,
          onTap: () => openMainTab(context, 2),
        ),
      ],
    );
  }
}
