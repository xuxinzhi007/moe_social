import 'package:flutter/material.dart';

import 'ai/agent_list_page.dart';
import 'game/game_lobby_page.dart';
import 'match_page.dart';

/// 社交扩展入口：弱化游戏/AI 的主 Tab 权重，集中放在「发现」。
/// 后续可在此接入兴趣匹配、话题广场等。
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('发现'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '扩展同好与玩法',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '主栏聚焦动态与好友；这里可以同好匹配、打开 AI 与小游戏等。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 20),
          _MatchEntryCard(scheme: scheme, primary: primary),
          const SizedBox(height: 20),
          Text(
            '玩法与工具',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 10),
          _DiscoverTile(
            icon: Icons.smart_toy_rounded,
            title: 'AI 助手',
            subtitle: '对话、创作与辅助功能',
            color: const Color(0xFFFFB347),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const AgentListPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _DiscoverTile(
            icon: Icons.sports_esports_rounded,
            title: '小游戏',
            subtitle: '轻量娱乐，不占主流程',
            color: const Color(0xFF95E1D3),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const GameLobbyPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _DiscoverTile(
            icon: Icons.notifications_outlined,
            title: '通知中心',
            subtitle: '点赞、评论与系统消息',
            color: primary,
            onTap: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
    );
  }
}

class _MatchEntryCard extends StatelessWidget {
  const _MatchEntryCard({
    required this.scheme,
    required this.primary,
  });

  final ColorScheme scheme;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (context) => const MatchPage()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withOpacity(0.14),
                scheme.tertiary.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withOpacity(0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, color: primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '同好匹配',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: scheme.outline),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '按话题标签从动态里找可能聊得来的人；不选标签也会从站内用户里推荐新面孔。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outline.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
