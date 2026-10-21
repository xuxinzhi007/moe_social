import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_agent.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../services/llm_api_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/moe_segment_bar.dart';
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

  int _section = 0;
  bool _searchOpen = false;
  String _plazaQuery = '';
  String _plazaFilter = '全部';
  late final PageController _mineDeck;

  @override
  void initState() {
    super.initState();
    _mineDeck = PageController(viewportFraction: 0.88);
    _loadAgents();
    _loadPublicAgents();
  }

  @override
  void dispose() {
    _mineDeck.dispose();
    super.dispose();
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

  Future<void> _openCreate() async {
    HapticFeedback.lightImpact();
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AgentEditorPage()),
    );
    if (created == true) {
      await _refreshAll();
      if (mounted) setState(() => _section = 2);
    }
  }

  Future<void> _confirmUse({
    required String name,
    required String mark,
    required String line,
    required String prompt,
    required Future<void> Function() onUse,
  }) async {
    HapticFeedback.lightImpact();
    final use = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: MoeTokens.pageBackground,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mark,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  line,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: MoeTokens.hintText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  prompt,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: 16),
                MoePressable(
                  onTap: () => Navigator.pop(sheetContext, true),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: MoeTokens.gradientPrimary,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    ),
                    child: const Text(
                      '使用',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (use == true && mounted) await onUse();
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
        '还没有可套用的模型。每人最多新建 3 个，创建后再把身份卡写进已有模型。',
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

  List<_DeckCard> get _plazaCards {
    return [
      for (final template in AiStarterTemplates.agentTemplates)
        _DeckCard(
          name: template.name,
          mark: '官方',
          line: template.tagline,
          body: template.description,
          prompt: template.systemPrompt,
          onUse: () {
            final agent = AiStarterTemplates.buildAgentFromTemplate(
              template,
              modelName: 'template',
            );
            return _applyCard(agent);
          },
        ),
      for (final agent in _publicAgents)
        _DeckCard(
          name: agent.name,
          mark: (agent.authorName?.trim().isNotEmpty ?? false)
              ? agent.authorName!.trim()
              : '公开',
          line: agent.description.trim().isNotEmpty
              ? agent.description.trim()
              : '别人公开的角色',
          body: _cardPrompt(agent),
          prompt: _cardPrompt(agent),
          onUse: () => _applyCard(agent),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        titleSpacing: _searchOpen ? 0 : null,
        centerTitle: !_searchOpen,
        title: _searchOpen
            ? Padding(
                padding: const EdgeInsets.only(right: 4),
                child: MoeSearchBar(
                  hintText: '搜索名字或说法',
                  onSearch: (value) => setState(() => _plazaQuery = value),
                  onClear: () => setState(() => _plazaQuery = ''),
                ),
              )
            : const Text('身份卡'),
        backgroundColor: Colors.transparent,
        foregroundColor: MoeTokens.titleText,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_section == 0)
            IconButton(
              tooltip: _searchOpen ? '关闭搜索' : '搜索',
              onPressed: () => setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _plazaQuery = '';
              }),
              icon: Icon(
                _searchOpen ? Icons.close_rounded : Icons.search_rounded,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              child: switch (_section) {
                1 => _CreateStage(onCreate: _openCreate),
                2 => _buildMineDeck(),
                _ => _buildPlazaDeck(),
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: MoeSegmentBar(
                index: _section,
                onChanged: (index) => setState(() {
                  _section = index;
                  if (index != 0) {
                    _searchOpen = false;
                    _plazaQuery = '';
                  }
                }),
                items: const [
                  MoeSegmentItem(icon: Icons.dashboard_rounded, label: '广场'),
                  MoeSegmentItem(icon: Icons.add_rounded, label: '创建'),
                  MoeSegmentItem(icon: Icons.person_rounded, label: '我的'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlazaDeck() {
    if (_loadingPublic && _publicAgents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: MoeLoading()),
        ],
      );
    }
    final cards = _visiblePlazaCards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final filter in const ['全部', '官方', '公开'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _plazaFilter == filter,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _plazaFilter == filter
                          ? Colors.white
                          : MoeTokens.titleText,
                    ),
                    selectedColor: MoeTokens.primary,
                    backgroundColor: MoeTokens.surface1,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    onSelected: (_) => setState(() => _plazaFilter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: cards.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 48),
                    _EmptyNote(
                      icon: Icons.search_off_rounded,
                      title: '没有对上的卡',
                      body: '换个词，或者切到「全部」。',
                    ),
                  ],
                )
              : GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 168,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return _BrowseCard(
                      card: card,
                      onTap: () => _confirmUse(
                        name: card.name,
                        mark: card.mark,
                        line: card.line,
                        prompt: card.prompt,
                        onUse: card.onUse,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<_DeckCard> get _visiblePlazaCards {
    final query = _plazaQuery.trim();
    return [
      for (final card in _plazaCards)
        if (_plazaFilter == '全部' ||
            (_plazaFilter == '官方' && card.mark == '官方') ||
            (_plazaFilter == '公开' && card.mark != '官方'))
          if (query.isEmpty ||
              card.name.contains(query) ||
              card.line.contains(query) ||
              card.body.contains(query))
            card,
    ];
  }

  Widget _buildMineDeck() {
    if (_loadingAgents) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: MoeLoading()),
        ],
      );
    }
    if (_myAgents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          _EmptyNote(
            icon: Icons.person_outline_rounded,
            title: '还没有自己的卡',
            body: '去「创建」做一张空白卡。广场上的卡是拿来使用的。',
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      children: [
        SizedBox(
          height: 430,
          child: PageView.builder(
            controller: _mineDeck,
            itemCount: _myAgents.length,
            itemBuilder: (context, index) {
              final agent = _myAgents[index];
              final card = _DeckCard(
                name: agent.name,
                mark: '我的',
                line: agent.description.trim().isNotEmpty
                    ? agent.description.trim()
                    : '保存在你的账号里',
                body: _cardPrompt(agent),
                prompt: _cardPrompt(agent),
                onUse: () => _applyCard(agent),
              );
              return _StageCard(
                card: card,
                onEdit: () => _editAgent(agent),
                onUse: () => _confirmUse(
                  name: card.name,
                  mark: card.mark,
                  line: card.line,
                  prompt: card.prompt,
                  onUse: card.onUse,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DeckCard {
  const _DeckCard({
    required this.name,
    required this.mark,
    required this.line,
    required this.body,
    required this.prompt,
    required this.onUse,
  });

  final String name;
  final String mark;
  final String line;
  final String body;
  final String prompt;
  final Future<void> Function() onUse;
}

class _BrowseCard extends StatelessWidget {
  const _BrowseCard({required this.card, required this.onTap});

  final _DeckCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MoeTokens.softChipBg,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              ),
              child: Text(
                card.mark,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: MoeTokens.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              card.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                card.line,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: MoeTokens.hintText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.card,
    required this.onUse,
    this.onEdit,
  });

  final _DeckCard card;
  final VoidCallback onUse;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final letter =
        card.name.trim().isEmpty ? '卡' : card.name.trim().substring(0, 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
          border: Border.all(color: MoeTokens.primary.withValues(alpha: 0.12)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -18,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 140,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: MoeTokens.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MoeTokens.softChipBg,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    ),
                    child: Text(
                      card.mark,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MoeTokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    card.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: MoeTokens.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Text(
                      card.body,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: MoeTokens.hintText,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (onEdit != null) ...[
                        TextButton(onPressed: onEdit, child: const Text('编辑')),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: MoePressable(
                          onTap: onUse,
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusFull),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: MoeTokens.gradientPrimary,
                              borderRadius:
                                  BorderRadius.circular(MoeTokens.radiusFull),
                            ),
                            child: const Text(
                              '使用',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateStage extends StatelessWidget {
  const _CreateStage({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      children: [
        Container(
          height: 430,
          decoration: BoxDecoration(
            color: MoeTokens.surface1,
            borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
            border:
                Border.all(color: MoeTokens.primary.withValues(alpha: 0.12)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 8,
                top: -10,
                child: Text(
                  '新',
                  style: TextStyle(
                    fontSize: 150,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: MoeTokens.primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '空白卡',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '从这里新建一张只属于你的身份卡。广场上的官方卡和别人的卡，是拿来使用的。',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: MoeTokens.hintText,
                      ),
                    ),
                    const Spacer(),
                    MoePressable(
                      onTap: onCreate,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: MoeTokens.gradientPrimary,
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusFull),
                        ),
                        child: const Text(
                          '开始创建',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
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
