import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_agent.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../services/llm_api_service.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import 'agent_editor_page.dart';

/// 角色卡广场：内置推荐模板 + 我的角色，社区区预留。
class CharacterCardPlazaPage extends StatefulWidget {
  const CharacterCardPlazaPage({super.key});

  @override
  State<CharacterCardPlazaPage> createState() => _CharacterCardPlazaPageState();
}

class _CharacterCardPlazaPageState extends State<CharacterCardPlazaPage> {
  List<AiAgent> _myAgents = [];
  List<AiAgent> _publicAgents = [];
  bool _loadingAgents = true;
  bool _loadingPublic = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
    _loadPublicAgents();
  }

  Future<void> _loadAgents() async {
    if (mounted) setState(() => _loadingAgents = true);
    try {
      final agents = await AiAgentCloudService().getAgents();
      if (!mounted) return;
      setState(() {
        _myAgents = agents;
        _loadingAgents = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _myAgents = [];
          _loadingAgents = false;
        });
      }
    }
  }

  Future<void> _loadPublicAgents() async {
    if (mounted) setState(() => _loadingPublic = true);
    try {
      final agents = await AiAgentCloudService().fetchPublicAgents();
      if (!mounted) return;
      setState(() {
        _publicAgents = agents;
        _loadingPublic = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPublic = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadAgents(), _loadPublicAgents()]);
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
      await _refreshAll();
    }
  }

  Future<void> _editAgent(AiAgent agent) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AgentEditorPage(agent: agent)),
    );
    if (saved == true) {
      await _refreshAll();
    }
  }

  String _cardPrompt(AiAgent agent) {
    final prompt = agent.systemPrompt.trim();
    if (prompt.isNotEmpty) return prompt;
    return [
      agent.persona,
      agent.scenario,
      agent.exampleDialogues,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join('\n');
  }

  Future<void> _applyCard(AiAgent agent) async {
    final prompt = _cardPrompt(agent);
    if (prompt.isEmpty) {
      MoeToast.error(context, '这张卡没有可写入的人设');
      return;
    }
    List<LlmManagedModel> models;
    try {
      models = await LlmApiService.listManagedModels();
    } catch (e) {
      if (mounted) MoeToast.error(context, '读取模型失败：$e');
      return;
    }
    final ready = models.where((model) => model.isReady).toList();
    if (!mounted) return;
    if (ready.isEmpty) {
      MoeToast.error(
        context,
        '还没有可套用的模型。每人最多新建 3 个，创建后再把角色卡写进已有模型。',
      );
      return;
    }
    final picked = await showModalBottomSheet<LlmManagedModel>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('套用到已有模型'),
                subtitle: Text('只更新这个模型的 Modelfile，不会新建。上限 3 个。'),
              ),
              for (final model in ready)
                ListTile(
                  title: Text(model.modelName),
                  subtitle: Text('基座 ${model.baseModel}'),
                  onTap: () => Navigator.pop(sheetContext, model),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    try {
      final result = await LlmApiService.upsertAgentPrompt(
        agentId: picked.agentId,
        requestId: LlmApiService.newRequestId(),
        baseModel: picked.baseModel,
        systemPrompt: prompt,
      );
      if (!mounted) return;
      if (!result.isReady) {
        MoeToast.error(context, result.outcomeMessage);
        return;
      }
      MoeToast.success(context, '已写入 ${picked.modelName}，没有新建模型');
    } catch (e) {
      if (mounted) MoeToast.error(context, '写入失败：$e');
    }
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
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _sectionTitle('推荐角色卡', '内置模板，一键套用 Tavern 骨架'),
            const SizedBox(height: 10),
            ...AiStarterTemplates.agentTemplates.map(_buildStarterCard),
            const SizedBox(height: 24),
            _sectionTitle('我的角色卡', '已保存到你账号下的角色'),
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
            _sectionTitle('角色卡广场', '套用到你已有的模型，只改 Modelfile，不新建'),
            const SizedBox(height: 10),
            if (_loadingPublic)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: MoeLoading()),
              )
            else if (_publicAgents.isEmpty)
              _buildPublicEmpty()
            else
              ..._publicAgents.map(_buildPublicAgentCard),
            const SizedBox(height: 32),
          ],
        ),
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
        : (agent.persona.trim().isNotEmpty ? agent.persona : '暂无简介');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AiBrandTokens.primary.withValues(alpha: 0.15),
                child: Text(
                  agent.name.isNotEmpty ? agent.name[0] : '?',
                  style: const TextStyle(
                    color: AiBrandTokens.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _editAgent(agent),
                child: const Text('编辑'),
              ),
              FilledButton(
                onPressed: () => _applyCard(agent),
                style: FilledButton.styleFrom(
                  backgroundColor: AiBrandTokens.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('套用'),
              ),
            ],
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
          Icon(Icons.person_outline_rounded,
              size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text('还没有角色卡', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '从上方推荐模板创建。编辑自己的卡并打开发布后，别人就能在广场看到。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicEmpty() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.public_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text('广场还没有公开角色卡',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '创建角色卡时开启「发布到角色卡广场」，保存后即可出现在这里。',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicAgentCard(AiAgent agent) {
    final author = (agent.authorName?.trim().isNotEmpty ?? false)
        ? agent.authorName!
        : '用户';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    AiBrandTokens.secondary.withValues(alpha: 0.15),
                child: Text(
                  agent.name.isNotEmpty ? agent.name[0] : '?',
                  style: const TextStyle(
                    color: AiBrandTokens.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$author · ${agent.modelName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => _applyCard(agent),
                style: FilledButton.styleFrom(
                  backgroundColor: AiBrandTokens.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('套用'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
