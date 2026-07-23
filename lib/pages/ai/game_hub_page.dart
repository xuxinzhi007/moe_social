import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/feature_flags.dart';
import '../../providers/life_provider.dart';
import '../../services/companion_chat_launcher.dart';
import '../../services/companion_context.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/moe_toast.dart';
import 'agent_list_page.dart';
import 'ai_lorebooks_page.dart';
import 'ai_provider_profiles_page.dart';
import 'game_play_page.dart';
import '../../services/game_service.dart';
import '../../auth_service.dart';
import '../../pages/life/life_world_page.dart';
import '../../widgets/moe_loading.dart';

/// AI 伙伴主页 —— 社交 App 里的「AI 朋友」入口。
///
/// 定位：像微信里有一个永远在线的好朋友，你可以和它聊天，
/// 它有自己的情绪和生活，偶尔会更新「动态」。
class GameHubPage extends StatefulWidget {
  const GameHubPage({super.key});

  @override
  State<GameHubPage> createState() => _GameHubPageState();
}

class _GameHubPageState extends State<GameHubPage> {
  late final LifeProvider _provider;
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<LifeProvider>();
    _provider.startListening();
  }

  // ── 操作 ─────────────────────────────────────────────────────────────

  Future<void> _openChat() async {
    if (_isChatLoading) return;
    setState(() => _isChatLoading = true);
    try {
      await CompanionChatLauncher.openChat(context);
    } catch (e) {
      if (mounted) {
        MoeToast.error(
            context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  Future<void> _openStory() async {
    if (!AuthService.isLoggedIn) {
      MoeToast.info(context, '请先登录后再进入互动故事');
      return;
    }
    setState(() => _isChatLoading = true);
    try {
      final state = await GameService().initSession(forceNew: false);
      if (!mounted) return;
      final entity =
          _provider.entities.isNotEmpty ? _provider.entities.first : null;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayPage(
            initialState: state,
            companionName: entity?.name,
            companionEmoji: entity?.emoji,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        MoeToast.error(
            context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
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
                'AI 伙伴设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '角色设定、世界设定和模型来源。',
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
                    MaterialPageRoute(
                        builder: (_) => const AgentListPage()),
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
                    MaterialPageRoute(
                        builder: (_) => const AiLorebooksPage()),
                  );
                },
              ),
              _ConfigTile(
                icon: Icons.memory_rounded,
                title: '模型来源',
                subtitle: '选择 AI 模型服务（本地 / 云端）',
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

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: const Text('AI 伙伴'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AiBrandTokens.titleColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openConfigSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          Selector<LifeProvider, _HubData>(
            selector: (_, p) => _HubData.fromProvider(p),
            builder: (context, data, _) {
              final ctx = data.companionCtx;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (!FeatureFlags.showLifeEngine || !ctx.hasCompanion) ...[
                    // ── 无伙伴 ──
                    _NoCompanionCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LifeWorldPage(),
                        ),
                      ),
                    ),
                  ] else ...[
                    // ── 伙伴头部 ──
                    _CompanionHeroCard(ctx: ctx),
                    const SizedBox(height: 16),

                    // ── 最近动态 ──
                    if (ctx.moments.isNotEmpty) ...[
                      _MomentsCard(moments: ctx.moments),
                      const SizedBox(height: 20),
                    ],

                    // ── 主 CTA：开始聊天 ──
                    _ChatEntryButton(
                      companionName: ctx.name,
                      isLoading: _isChatLoading,
                      onTap: _openChat,
                    ),
                    const SizedBox(height: 24),

                    // ── 次级入口 ──
                    _SecondaryActions(
                      onDetail: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LifeWorldPage(),
                        ),
                      ),
                      onStory: _openStory,
                    ),
                  ],
                ],
              );
            },
          ),
          if (_isChatLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x40FFFFFF),
                child: Center(child: MoeLoading()),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Selector 数据类 ─────────────────────────────────────────────────────────

class _HubData {
  final CompanionContext companionCtx;
  final bool isInitialized;

  const _HubData({
    required this.companionCtx,
    required this.isInitialized,
  });

  factory _HubData.fromProvider(LifeProvider p) {
    return _HubData(
      companionCtx: CompanionContext.fromProvider(p),
      isInitialized: p.isInitialized,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _HubData &&
        isInitialized == other.isInitialized &&
        companionCtx.hasCompanion == other.companionCtx.hasCompanion &&
        companionCtx.name == other.companionCtx.name &&
        companionCtx.emoji == other.companionCtx.emoji &&
        companionCtx.moodLabel == other.companionCtx.moodLabel &&
        companionCtx.moments.length == other.companionCtx.moments.length;
  }

  @override
  int get hashCode => Object.hash(
        isInitialized,
        companionCtx.hasCompanion,
        companionCtx.name,
        companionCtx.moments.length,
      );
}

// ── 伙伴头部卡片（社交风格）────────────────────────────────────────────────

class _CompanionHeroCard extends StatelessWidget {
  final CompanionContext ctx;

  const _CompanionHeroCard({required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE7F6), Color(0xFFF3E5F5), Color(0xFFFCE4EC)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0x128A2387),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头像
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(ctx.emoji, style: const TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 16),

          // 名字
          Text(
            ctx.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AiBrandTokens.titleColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // 在做什么
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '正在${ctx.activityLabel}',
              style: TextStyle(
                fontSize: 12,
                color: AiBrandTokens.primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 心情一句话
          Text(
            '"${ctx.moodLabel}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF5D4E6E),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 最近动态（朋友圈风格）────────────────────────────────────────────────

class _MomentsCard extends StatelessWidget {
  final List<CompanionMoment> moments;

  const _MomentsCard({required this.moments});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AiBrandTokens.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                '最近动态',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AiBrandTokens.titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...moments.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          AiBrandTokens.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(m.icon,
                        style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.text,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: AiBrandTokens.titleColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          m.timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 聊天入口按钮（主 CTA）───────────────────────────────────────────────

class _ChatEntryButton extends StatelessWidget {
  final String companionName;
  final bool isLoading;
  final VoidCallback onTap;

  const _ChatEntryButton({
    required this.companionName,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.chat_bubble_rounded, size: 20),
      label: Text(
        companionName.isNotEmpty ? '和 $companionName 聊天' : '开始聊天',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AiBrandTokens.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        shadowColor: AiBrandTokens.primary.withValues(alpha: 0.4),
      ),
    );
  }
}

// ── 次级操作（详情 + 互动故事）──────────────────────────────────────────

class _SecondaryActions extends StatelessWidget {
  final VoidCallback onDetail;
  final VoidCallback onStory;

  const _SecondaryActions({
    required this.onDetail,
    required this.onStory,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: onDetail,
          icon: const Icon(Icons.info_outline_rounded, size: 16),
          label: const Text('伙伴详情'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
        Container(
          width: 1,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.grey.shade300,
        ),
        TextButton.icon(
          onPressed: onStory,
          icon: const Icon(Icons.auto_stories_outlined, size: 16),
          label: const Text('互动故事'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ── 无伙伴降级态 ───────────────────────────────────────────────────────

class _NoCompanionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NoCompanionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEDE7F6), Color(0xFFF3E5F5)],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: const Text('👋', style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 20),
          const Text(
            '你的 AI 伙伴还没有创建',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AiBrandTokens.titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '创建一个 AI 朋友，随时陪你聊天、分享日常。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('创建伙伴'),
            style: FilledButton.styleFrom(
              backgroundColor: AiBrandTokens.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 配置项 ─────────────────────────────────────────────────────────────

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
