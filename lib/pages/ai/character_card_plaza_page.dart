import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_agent.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import 'agent_editor_page.dart';
import 'chat_page.dart';

/// 角色卡广场：内置推荐模板 + 我的角色，社区区预留。
class CharacterCardPlazaPage extends StatefulWidget {
  const CharacterCardPlazaPage({super.key});

  @override
  State<CharacterCardPlazaPage> createState() => _CharacterCardPlazaPageState();
}

class _CharacterCardPlazaPageState extends State<CharacterCardPlazaPage> {
  List<AiAgent> _myAgents = [];
  bool _loadingAgents = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    try {
      final local = await AiAgentCloudService().getLocalAgents();
      if (mounted && local.isNotEmpty) {
        setState(() {
          _myAgents = local;
          _loadingAgents = false;
        });
      }
    } catch (_) {}

    if (mounted && _myAgents.isEmpty) {
      setState(() => _loadingAgents = true);
    }
    try {
      final agents = await AiAgentCloudService().syncAgentsFromCloud();
      if (!mounted) return;
      setState(() {
        _myAgents = agents;
        _loadingAgents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAgents = false);
    }
  }

  Future<void> _useStarterTemplate(AiStarterAgentTemplate template) async {
    HapticFeedback.lightImpact();
    final draft = AiStarterTemplates.buildAgentFromTemplate(
      template,
      modelName: 'llama3:8b',
    );
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AgentEditorPage(agent: draft)),
    );
    if (created == true) {
      await _loadAgents();
    }
  }

  Future<void> _openChat(AiAgent agent) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(agent: agent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: const Text('角色卡广场'),
        backgroundColor: AiBrandTokens.pageBackground,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAgents,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHero(),
            const SizedBox(height: 20),
            _sectionTitle('推荐角色卡', '内置模板，一键套用 Tavern 骨架'),
            const SizedBox(height: 10),
            ...AiStarterTemplates.agentTemplates.map(_buildStarterCard),
            const SizedBox(height: 24),
            _sectionTitle('我的角色卡', '已创建或导入的角色'),
            const SizedBox(height: 10),
            if (_loadingAgents)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: MoeLoading()),
              )
            else if (_myAgents.isEmpty)
              _buildEmptyMine()
            else
              ..._myAgents.map(_buildMyAgentCard),
            const SizedBox(height: 24),
            _sectionTitle('社区广场', '下载与分享角色卡'),
            const SizedBox(height: 10),
            _buildComingSoon(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AiBrandTokens.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AiBrandTokens.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '发现角色，开启对话',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '从推荐模板快速起号，或使用你已导入、创建的角色卡直接进入聊天。',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AiBrandTokens.titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildStarterCard(AiStarterAgentTemplate template) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _useStarterTemplate(template),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AiBrandTokens.userBubbleGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    template.name.isNotEmpty ? template.name[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.tagline,
                        style: TextStyle(
                          fontSize: 12,
                          color: AiBrandTokens.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        template.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyAgentCard(AiAgent agent) {
    final subtitle = agent.description.trim().isNotEmpty
        ? agent.description
        : (agent.persona.trim().isNotEmpty
            ? agent.persona
            : '暂无简介');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: AiBrandTokens.primary.withValues(alpha: 0.15),
            child: Text(
              agent.name.isNotEmpty ? agent.name[0] : '?',
              style: const TextStyle(
                color: AiBrandTokens.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            agent.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.35),
          ),
          trailing: FilledButton(
            onPressed: () => _openChat(agent),
            style: FilledButton.styleFrom(
              backgroundColor: AiBrandTokens.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('使用'),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMine() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.person_outline_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text('还没有角色卡', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '从上方推荐模板创建，或在 AI 酒馆主页导入 JSON。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '社区角色卡即将上线',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '未来将支持浏览、下载与分享社区角色卡（SillyTavern 等格式规划中）。',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              MoeToast.info(context, '社区广场开发中，敬请期待');
            },
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }
}
