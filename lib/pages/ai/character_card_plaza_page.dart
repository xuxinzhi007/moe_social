import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_agent.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../services/llm_api_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_pressable.dart';
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
      backgroundColor: MoeTokens.pageBackground,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text(
                '套到已有模型',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MoeTokens.titleText,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '只改这个模型的系统提示词，不新建。',
                style: TextStyle(fontSize: 12, color: MoeTokens.hintText),
              ),
              const SizedBox(height: 12),
              for (final model in ready)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MoePressable(
                    onTap: () => Navigator.pop(sheetContext, model),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: MoeTokens.surface1,
                        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.modelName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: MoeTokens.titleText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '基座 ${model.baseModel}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MoeTokens.hintText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('角色卡'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: MoeTokens.titleText,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _sectionTitle('官方样板', '点一张，生成你自己的卡'),
            const SizedBox(height: 10),
            _PlazaGrid(
              children: [
                for (final template in AiStarterTemplates.agentTemplates)
                  _PlazaTile(
                    name: template.name,
                    kicker: template.tagline,
                    body: template.description,
                    onTap: () => _useStarterTemplate(template),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle('我的角色卡', '已保存在你的账号里'),
            const SizedBox(height: 10),
            if (_loadingAgents)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: MoeLoading()),
              )
            else if (_myAgents.isEmpty)
              _buildEmptyMine()
            else
              _PlazaGrid(
                children: [for (final agent in _myAgents) _mineTile(agent)],
              ),
            const SizedBox(height: 24),
            _sectionTitle('别人公开的', '套进你已有的模型'),
            const SizedBox(height: 10),
            if (_loadingPublic)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: MoeLoading()),
              )
            else if (_publicAgents.isEmpty)
              _buildPublicEmpty()
            else
              _PlazaGrid(
                children: [
                  for (final agent in _publicAgents) _publicTile(agent),
                ],
              ),
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
            color: MoeTokens.titleText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: MoeTokens.hintText),
        ),
      ],
    );
  }

  Widget _mineTile(AiAgent agent) {
    final subtitle = agent.description.trim().isNotEmpty
        ? agent.description
        : (agent.persona.trim().isNotEmpty ? agent.persona : '还没有简介');
    return _PlazaTile(
      name: agent.name,
      kicker: '我的',
      body: subtitle,
      actions: [
        _TileAction('编辑', () => _editAgent(agent)),
        _TileAction('套用', () => _applyCard(agent)),
      ],
    );
  }

  Widget _publicTile(AiAgent agent) {
    final author = (agent.authorName?.trim().isNotEmpty ?? false)
        ? agent.authorName!
        : '用户';
    return _PlazaTile(
      name: agent.name,
      kicker: author,
      body: agent.modelName.trim().isEmpty ? '公开角色' : agent.modelName,
      actions: [
        _TileAction('套用', () => _applyCard(agent)),
      ],
    );
  }

  Widget _buildEmptyMine() {
    return const _EmptyNote(
      icon: Icons.person_outline_rounded,
      title: '还没有自己的卡',
      body: '点上面的样板就能生成一张。发布之后，别人也能套用。',
    );
  }

  Widget _buildPublicEmpty() {
    return const _EmptyNote(
      icon: Icons.public_rounded,
      title: '还没有人公开',
      body: '编辑自己的卡时打开「发布」，保存后会出现在这里。',
    );
  }
}

class _TileAction {
  const _TileAction(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

class _PlazaGrid extends StatelessWidget {
  const _PlazaGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 188,
      ),
      children: children,
    );
  }
}

class _PlazaTile extends StatelessWidget {
  const _PlazaTile({
    required this.name,
    required this.kicker,
    required this.body,
    this.onTap,
    this.actions = const [],
  });

  final String name;
  final String kicker;
  final String body;
  final VoidCallback? onTap;
  final List<_TileAction> actions;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Mark(name),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MoeTokens.titleText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kicker,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MoeTokens.primary,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: MoeTokens.hintText,
              ),
            ),
          ),
          if (actions.isNotEmpty)
            Row(
              children: [
                for (final action in actions)
                  TextButton(
                    onPressed: action.onTap,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(action.label),
                  ),
              ],
            ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      child: tile,
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MoeTokens.softChipBg,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
      ),
      child: Text(
        letter,
        style: const TextStyle(
          color: MoeTokens.primary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: MoeTokens.hintText),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: MoeTokens.titleText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MoeTokens.hintText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
