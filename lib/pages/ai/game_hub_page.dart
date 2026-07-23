import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../pages/life/life_world_page.dart';
import '../../services/companion_chat_launcher.dart';
import '../../services/companion_service.dart';
import '../../services/game_service.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import 'game_play_page.dart';

/// AI 伙伴主页 - 独立 AI 账户中心。
class GameHubPage extends StatefulWidget {
  const GameHubPage({super.key});

  @override
  State<GameHubPage> createState() => _GameHubPageState();
}

class _GameHubPageState extends State<GameHubPage> {
  bool _isLoading = true;
  bool _isChatLoading = false;
  bool _isSavingProfile = false;

  String? _loadError;
  CompanionProfileData _profile = const CompanionProfileData();
  CompanionStateData _state = const CompanionStateData();
  List<CompanionMemoryData> _memories = const [];
  List<CompanionChatLogData> _chatHistory = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadDashboard());
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final snapshot = await CompanionService().getSnapshot();
      List<CompanionMemoryData> memories = const [];
      List<CompanionChatLogData> history = const [];

      try {
        memories = await CompanionService().listMemories(limit: 6);
      } catch (_) {}

      try {
        history = await CompanionService().listChatHistory(limit: 8);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _profile = snapshot.profile;
        _state = snapshot.state;
        _memories = memories;
        _chatHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openChat() async {
    if (_isChatLoading) return;
    setState(() => _isChatLoading = true);
    try {
      await CompanionChatLauncher.openChat(context);
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  Future<void> _openLifeWorld() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LifeWorldPage()),
    );
    if (mounted) unawaited(_loadDashboard());
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
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayPage(
            initialState: state,
            companionName: _profile.name.isNotEmpty ? _profile.name : 'AI 伙伴',
            companionEmoji: _profile.emoji,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  Future<void> _editProfile() async {
    final saved = await _showProfileEditor();
    if (saved == null) return;
    if (!mounted) return;

    setState(() => _isSavingProfile = true);
    try {
      final result = await CompanionService().updateProfile(saved);
      if (!mounted) return;
      setState(() {
        _profile = result;
      });
      MoeToast.success(context, 'AI 账户已更新');
      await _loadDashboard();
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<CompanionProfileData?> _showProfileEditor() async {
    final current = _profile;
    final nameController = TextEditingController(text: current.name);
    final emojiController = TextEditingController(text: current.emoji);
    final personaController = TextEditingController(text: current.persona);
    final agentIdController = TextEditingController(text: current.agentId);
    final traitsController = TextEditingController(
      text: current.personalityTraits.join('，'),
    );
    final systemPromptController = TextEditingController(
      text: current.systemPromptOverride,
    );
    var greetingStyle = current.greetingStyle.isNotEmpty
        ? current.greetingStyle
        : 'warm';

    try {
      return await showModalBottomSheet<CompanionProfileData>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AiBrandTokens.pageBackground,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '编辑 AI 账户',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AiBrandTokens.titleColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ProfileField(
                          controller: nameController,
                          label: '名称',
                          hint: '例如：阿悠',
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: emojiController,
                          label: '表情',
                          hint: '例如：🐾',
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: personaController,
                          label: '人设',
                          hint: '一句话描述 AI 的角色和气质',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: agentIdController,
                          label: 'Agent ID',
                          hint: '对接 OpenClaw / 后端 AI 的账号标识',
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: traitsController,
                          label: '性格标签',
                          hint: '用逗号分隔，例如：温暖, 好奇, 幽默',
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: systemPromptController,
                          label: '系统提示词覆盖',
                          hint: '可选，留空则使用默认设置',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: greetingStyle,
                          decoration: _profileFieldDecoration('问候风格'),
                          items: const [
                            DropdownMenuItem(value: 'warm', child: Text('温暖')),
                            DropdownMenuItem(value: 'playful', child: Text('俏皮')),
                            DropdownMenuItem(value: 'calm', child: Text('沉静')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => greetingStyle = value);
                          },
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () {
                            final traits = traitsController.text
                                .split(RegExp(r'[，,;\n]'))
                                .map((item) => item.trim())
                                .where((item) => item.isNotEmpty)
                                .toList(growable: false);
                            Navigator.pop(
                              sheetContext,
                              current.copyWith(
                                name: nameController.text.trim(),
                                emoji: emojiController.text.trim(),
                                persona: personaController.text.trim(),
                                agentId: agentIdController.text.trim(),
                                personalityTraits: traits,
                                greetingStyle: greetingStyle,
                                systemPromptOverride:
                                    systemPromptController.text.trim(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('保存账户'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AiBrandTokens.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      emojiController.dispose();
      personaController.dispose();
      agentIdController.dispose();
      traitsController.dispose();
      systemPromptController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: const Text('AI 账户'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AiBrandTokens.titleColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadDashboard,
          ),
          IconButton(
            tooltip: '管理绑定',
            icon: const Icon(Icons.link_rounded),
            onPressed: _openLifeWorld,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loadError != null)
            _FallbackCard(
              errorText: _loadError!,
              onRetry: _loadDashboard,
            )
          else if (_isLoading)
            const Center(child: MoeLoading())
          else
            RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _HeroCard(
                    profile: _profile,
                    state: _state,
                    onChat: _openChat,
                    onEdit: _editProfile,
                    onStory: _openStory,
                    onBind: _openLifeWorld,
                  ),
                  const SizedBox(height: 16),
                  _StateCard(profile: _profile, state: _state),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: '最近记忆',
                    icon: Icons.psychology_alt_rounded,
                    emptyText: '还没有记忆',
                    child: Column(
                      children: _memories.isEmpty
                          ? const []
                          : _memories
                              .map((item) => _MemoryTile(memory: item))
                              .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: '最近聊天',
                    icon: Icons.chat_bubble_outline_rounded,
                    emptyText: '还没有聊天记录',
                    child: Column(
                      children: _chatHistory.isEmpty
                          ? const []
                          : _chatHistory
                              .map((item) => _ChatLogTile(log: item))
                              .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          if (_isChatLoading || _isSavingProfile)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22FFFFFF),
                child: Center(child: MoeLoading()),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.profile,
    required this.state,
    required this.onChat,
    required this.onEdit,
    required this.onStory,
    required this.onBind,
  });

  final CompanionProfileData profile;
  final CompanionStateData state;
  final VoidCallback onChat;
  final VoidCallback onEdit;
  final VoidCallback onStory;
  final VoidCallback onBind;

  @override
  Widget build(BuildContext context) {
    final name = profile.name.trim().isNotEmpty ? profile.name.trim() : 'AI 伙伴';
    final persona = profile.persona.trim().isNotEmpty
        ? profile.persona.trim()
        : '独立 AI 账户，记忆、状态和聊天都在这里。';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFE7FF), Color(0xFFFBE8F0), Color(0xFFF8F3E7)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Text(
                  profile.emoji.trim().isNotEmpty ? profile.emoji.trim() : '🐾',
                  style: const TextStyle(fontSize: 38),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AiBrandTokens.titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      persona,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF5D4E6E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
          children: [
              _MiniChip('关系', 'Lv.${profile.relationshipLevel}'),
              _MiniChip('亲密', '${profile.intimacyScore.round()}%'),
              _MiniChip('问候', profile.greetingStyle),
              _MiniChip('Agent', profile.agentId.isNotEmpty ? profile.agentId : '默认'),
              _MiniChip(
                '绑定',
                profile.lifeEntityId > 0 ? '已绑定' : '未绑定',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('开始聊天'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AiBrandTokens.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('编辑资料'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AiBrandTokens.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onBind,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('管理绑定'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onStory,
                  icon: const Icon(Icons.auto_stories_rounded),
                  label: const Text('互动故事'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.profile, required this.state});

  final CompanionProfileData profile;
  final CompanionStateData state;

  String _percent(double value) => '${(value * 100).clamp(0, 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '当前状态',
      icon: Icons.auto_awesome_rounded,
      emptyText: '当前没有状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.moodThought.trim().isNotEmpty) ...[
            Text(
              state.moodThought.trim(),
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AiBrandTokens.titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (state.activityLabel.trim().isNotEmpty) ...[
            _InlineLine(
              icon: Icons.schedule_rounded,
              text: '正在${state.activityLabel.trim()}',
            ),
            const SizedBox(height: 8),
          ],
          if (state.greeting.trim().isNotEmpty) ...[
            _InlineLine(
              icon: Icons.chat_bubble_outline_rounded,
              text: state.greeting.trim(),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip('心情', _percent(state.mood)),
              _MiniChip('饥饿', _percent(state.hunger)),
              _MiniChip('精力', _percent(state.energy)),
              _MiniChip('人格', profile.persona.trim().isEmpty ? '默认' : '自定义'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasContent = child is Column && (child as Column).children.isNotEmpty;
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
              Icon(icon, size: 18, color: AiBrandTokens.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AiBrandTokens.titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasContent) child else Text(
            emptyText,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory});

  final CompanionMemoryData memory;

  @override
  Widget build(BuildContext context) {
    final content = memory.content.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MiniChip(memory.memoryType.isNotEmpty ? memory.memoryType : '记忆',
                  memory.importance >= 8 ? '高优先' : '普通'),
              const Spacer(),
              Text(
                memory.createdAt,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content.isNotEmpty ? content : '空记忆',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AiBrandTokens.titleColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatLogTile extends StatelessWidget {
  const _ChatLogTile({required this.log});

  final CompanionChatLogData log;

  String _preview(String text) {
    final value = text.trim().replaceAll('\n', ' ');
    if (value.length <= 72) return value;
    return '${value.substring(0, 72)}…';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = log.role == 'user';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFF4F8FF) : const Color(0xFFF8F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              _MiniChip(isUser ? '我' : '伙伴', log.role),
              const Spacer(),
              Text(
                log.createdAt,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _preview(log.content),
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AiBrandTokens.titleColor,
            ),
            textAlign: isUser ? TextAlign.right : TextAlign.left,
          ),
        ],
      ),
    );
  }
}

class _InlineLine extends StatelessWidget {
  const _InlineLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AiBrandTokens.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AiBrandTokens.titleColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AiBrandTokens.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        '$label · $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AiBrandTokens.primary,
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _profileFieldDecoration(label).copyWith(hintText: hint),
    );
  }
}

InputDecoration _profileFieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: AiBrandTokens.primary),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

class _FallbackCard extends StatelessWidget {
  const _FallbackCard({required this.errorText, required this.onRetry});

  final String errorText;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFE7FF), Color(0xFFFBE8F0), Color(0xFFF8F3E7)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📡', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                'AI 账户暂时不可用',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AiBrandTokens.titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
                style: FilledButton.styleFrom(
                  backgroundColor: AiBrandTokens.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
