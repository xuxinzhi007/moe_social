import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../constants/feature_flags.dart';
import '../../pages/life/life_world_page.dart';
import '../../services/game_service.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import 'agent_list_page.dart';
import 'ai_lorebooks_page.dart';
import 'ai_provider_profiles_page.dart';
import 'game_play_page.dart';

/// AI 伙伴入口：日常陪伴与互动故事共享一个产品入口。
class GameHubPage extends StatefulWidget {
  const GameHubPage({super.key});

  @override
  State<GameHubPage> createState() => _GameHubPageState();
}

class _GameHubPageState extends State<GameHubPage> {
  bool _isLoading = false;

  Future<void> _enterStory({bool forceNew = false}) async {
    if (!AuthService.isLoggedIn) {
      MoeToast.info(context, '请先登录后再进入互动故事');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final state = await GameService().initSession(forceNew: forceNew);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GamePlayPage(initialState: state)),
      );
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openConfigSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 创作设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '角色、世界设定和模型来源会影响互动故事。',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              _ConfigTile(
                icon: Icons.face_retouching_natural_rounded,
                title: '角色设定',
                subtitle: '管理角色人格与说话方式',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AgentListPage()),
                  );
                },
              ),
              _ConfigTile(
                icon: Icons.auto_stories_rounded,
                title: '世界设定',
                subtitle: '管理世界书和故事背景',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiLorebooksPage()),
                  );
                },
              ),
              _ConfigTile(
                icon: Icons.memory_rounded,
                title: '模型来源',
                subtitle: '选择生成故事使用的 AI 模型',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiProviderProfilesPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        title: const Text('AI 伙伴'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF312E2B),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'AI 创作设置',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openConfigSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const _WelcomeHeader(),
              const SizedBox(height: 20),
              if (FeatureFlags.showLifeEngine)
                _ExperienceCard(
                  eyebrow: 'DAILY COMPANION',
                  title: '陪伴日常',
                  description: '照顾你的 AI 伙伴，观察状态变化，积累共同经历。',
                  icon: '🐾',
                  colors: const [Color(0xFFFFE8BF), Color(0xFFFFF8EB)],
                  foreground: const Color(0xFF81551F),
                  actionLabel: '去见伙伴',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LifeWorldPage()),
                  ),
                ),
              const SizedBox(height: 14),
              _ExperienceCard(
                eyebrow: 'INTERACTIVE STORY',
                title: '互动故事',
                description: '输入行动，与角色共同推进一个会持续保存的文字故事。',
                icon: '📖',
                colors: const [Color(0xFFDCD8FF), Color(0xFFF3F1FF)],
                foreground: AiBrandTokens.primary,
                actionLabel: '继续故事',
                onTap: () => _enterStory(),
                secondaryLabel: '新故事',
                onSecondaryTap: () => _enterStory(forceNew: true),
              ),
              const SizedBox(height: 22),
              const _HowItConnects(),
            ],
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: MoeLoading()),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 8, 4, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '不只是聊天，\n一起生活和创造故事。',
            style: TextStyle(
              fontSize: 28,
              height: 1.22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF282522),
            ),
          ),
          SizedBox(height: 10),
          Text(
            '日常状态带来陪伴感，互动故事承载更深的角色关系。',
            style:
                TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF7B746E)),
          ),
        ],
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final String icon;
  final List<Color> colors;
  final Color foreground;
  final String actionLabel;
  final VoidCallback onTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

  const _ExperienceCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.foreground,
    required this.actionLabel,
    required this.onTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                        color: foreground.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 30)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: foreground.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: foreground,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (secondaryLabel != null && onSecondaryTap != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onSecondaryTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: BorderSide(color: foreground.withValues(alpha: 0.35)),
                    minimumSize: const Size(92, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItConnects extends StatelessWidget {
  const _HowItConnects();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_rounded, color: AiBrandTokens.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '两个体验如何结合？',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5),
                Text(
                  '先在陪伴日常里认识角色，再带着当前伙伴进入互动故事。后续可以把故事中的关系和记忆回写到伙伴状态。',
                  style: TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFF77706A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ConfigTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AiBrandTokens.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
