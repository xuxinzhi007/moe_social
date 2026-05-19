import 'package:flutter/material.dart';

import '../../widgets/ai/ai_brand_tokens.dart';
import '../ai/agent_list_page.dart';
import '../game/game_lobby_page.dart';
import 'widgets/explore_feature_card.dart';

/// 探索页 · 玩法：AI 酒馆、小游戏等扩展能力。
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
          '沉浸玩法',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AiBrandTokens.titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '角色对话、世界观与模型来源集中在酒馆；小游戏适合轻松一局。',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        ExploreFeatureCard(
          variant: ExploreFeatureCardVariant.hero,
          title: 'AI 酒馆',
          subtitle: '把角色、世界观、模型来源放进同一个酒馆入口',
          icon: Icons.auto_awesome_rounded,
          gradient: AiBrandTokens.heroGradient,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AgentListPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        ExploreFeatureCard(
          title: '小游戏',
          subtitle: '扫雷等多人在线小游戏',
          icon: Icons.sports_esports_rounded,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF43C6AC), Color(0xFF191654)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GameLobbyPage()),
            );
          },
        ),
      ],
    );
  }
}
