import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/feature_flags.dart';
import '../../models/ai_agent.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../services/llm_api_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_action_row.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_glass_surface.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/moe_segment_bar.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_motion.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/motion/moe_sheet.dart';
import 'agent_editor_page.dart';

/// 身份卡广场：官方推荐模板 + 公开角色卡 + 我的专属卡。
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
  int _mineIndex = 0;
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
        if (_mineIndex >= _myAgents.length) {
          _mineIndex = _myAgents.isEmpty ? 0 : _myAgents.length - 1;
        }
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

  Future<void> _openCreate({AiStarterAgentTemplate? initialTemplate}) async {
    HapticFeedback.lightImpact();
    final draft = initialTemplate == null
        ? null
        : AiStarterTemplates.buildAgentFromTemplate(
            initialTemplate,
            modelName: '',
          );
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AgentEditorPage(agent: draft)),
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
    final use = await MoeSheet.show<bool>(
      context,
      backgroundColor: MoeTokens.surface1,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MoeTokens.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusFull),
                      ),
                      child: Text(
                        mark,
                        style: const TextStyle(
                          fontSize: MoeTokens.textXs,
                          fontWeight: FontWeight.w800,
                          color: MoeTokens.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(sheetContext, false),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: MoeTokens.hintText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: MoeTokens.textXl,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  line,
                  style: const TextStyle(
                    fontSize: MoeTokens.textBase,
                    height: 1.4,
                    color: MoeTokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MoeTokens.pageBackground,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                    border: Border.all(color: MoeTokens.surfaceBorder),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: MoeTokens.textSm,
                        height: 1.5,
                        color: MoeTokens.titleText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                MoePressable(
                  onTap: () => Navigator.pop(sheetContext, true),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: MoeTokens.gradientPrimary,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                      boxShadow: MoeTokens.shadowSm(),
                    ),
                    child: const Text(
                      '套用这张身份卡',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MoeTokens.textMd,
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
    final picked = await MoeSheet.show<LlmManagedModel>(
      context,
      backgroundColor: MoeTokens.surface1,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '套到已有模型',
                    style: TextStyle(
                      fontSize: MoeTokens.textLg,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '只改这个模型的系统提示词，不新建模型。',
                    style: TextStyle(
                      fontSize: MoeTokens.textSm,
                      color: MoeTokens.inkMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final model in ready)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: MoeActionRow(
                      icon: Icons.smart_toy_outlined,
                      iconColor: MoeTokens.primary,
                      backgroundColor: MoeTokens.pageBackground,
                      borderColor: MoeTokens.surfaceBorder,
                      title: model.modelName,
                      subtitle: Text('基座 ${model.baseModel}'),
                      onTap: () => Navigator.pop(sheetContext, model),
                    ),
                  ),
              ],
            ),
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
              : '社区用户公开分享的身份卡',
          body: _cardPrompt(agent),
          prompt: _cardPrompt(agent),
          onUse: () => _applyCard(agent),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final glassNav = FeatureFlags.glassNavigation;
    final motion =
        moeReduceMotion(context) ? Duration.zero : MoeTokens.motionFast;

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        titleSpacing: _searchOpen ? 0 : null,
        centerTitle: !_searchOpen,
        title: _searchOpen
            ? Padding(
                padding: const EdgeInsets.only(right: 4),
                child: MoeSearchBar(
                  hintText: '搜索角色名、标签或设定',
                  onSearch: (value) => setState(() => _plazaQuery = value),
                  onClear: () => setState(() => _plazaQuery = ''),
                ),
              )
            : const Text('身份卡'),
        backgroundColor: glassNav ? Colors.transparent : MoeTokens.surface1,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: glassNav
            ? MoeGlassSurface(
                tint: MoeTokens.surface1.withValues(alpha: 0.82),
                showBorder: false,
                child: const SizedBox.expand(),
              )
            : null,
        shape: const Border(
          bottom: BorderSide(color: MoeTokens.surfaceBorder),
        ),
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
              color: MoeTokens.primary,
              child: AnimatedSwitcher(
                duration: motion,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey<int>(_section),
                  child: switch (_section) {
                    1 => _CreateStage(
                        onCreateBlank: () => _openCreate(),
                        onPickTemplate: (tpl) =>
                            _openCreate(initialTemplate: tpl),
                      ),
                    2 => _buildMineDeck(),
                    _ => _buildPlazaDeck(),
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: MoeSegmentBar(
                index: _section,
                onChanged: (index) {
                  if (index == _section) return;
                  HapticFeedback.selectionClick();
                  setState(() {
                    _section = index;
                    if (index != 0) {
                      _searchOpen = false;
                      _plazaQuery = '';
                    }
                  });
                },
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
    final motion =
        moeReduceMotion(context) ? Duration.zero : MoeTokens.motionFast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final filter in const ['全部', '官方', '公开'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MoePressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _plazaFilter = filter);
                    },
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    child: AnimatedContainer(
                      duration: motion,
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _plazaFilter == filter
                            ? MoeTokens.primary
                            : MoeTokens.surface1,
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusFull),
                        border: Border.all(
                          color: _plazaFilter == filter
                              ? MoeTokens.primary
                              : MoeTokens.surfaceBorder,
                        ),
                        boxShadow: _plazaFilter == filter
                            ? MoeTokens.shadowSm()
                            : null,
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: MoeTokens.textSm,
                          fontWeight: FontWeight.w700,
                          color: _plazaFilter == filter
                              ? Colors.white
                              : MoeTokens.titleText,
                        ),
                      ),
                    ),
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
                  children: [
                    const SizedBox(height: 48),
                    MoeEmptyState(
                      icon: Icons.search_off_rounded,
                      title: '没有匹配的身份卡',
                      subtitle: '试试换个关键词，或者切回「全部」看看官方推荐。',
                      compact: true,
                      primaryAction:
                          _plazaFilter != '全部' || _plazaQuery.trim().isNotEmpty
                              ? MoeEmptyStateAction(
                                  label: '重置筛选',
                                  icon: Icons.refresh_rounded,
                                  onPressed: () => setState(() {
                                    _plazaFilter = '全部';
                                    _plazaQuery = '';
                                  }),
                                )
                              : null,
                    ),
                  ],
                )
              : GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 174,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return MoeReveal(
                      delay: Duration(
                        milliseconds: 30 * index.clamp(0, 6),
                      ),
                      child: _BrowseCard(
                        card: card,
                        onTap: () => _confirmUse(
                          name: card.name,
                          mark: card.mark,
                          line: card.line,
                          prompt: card.prompt,
                          onUse: card.onUse,
                        ),
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
        children: [
          const SizedBox(height: 64),
          MoeEmptyState(
            icon: Icons.style_outlined,
            title: '还没有自己的身份卡',
            subtitle: '去「创建」定制一张专属人设卡，或者在「广场」直接使用官方模板。',
            compact: true,
            primaryAction: MoeEmptyStateAction(
              label: '去创建',
              icon: Icons.add_rounded,
              onPressed: () => setState(() => _section = 1),
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Row(
            children: [
              Text(
                '我的卡组（${_mineIndex + 1}/${_myAgents.length}）',
                style: const TextStyle(
                  fontSize: MoeTokens.textSm,
                  fontWeight: FontWeight.w700,
                  color: MoeTokens.inkMuted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openCreate(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('新建'),
                style: TextButton.styleFrom(
                  foregroundColor: MoeTokens.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: _mineDeck,
            itemCount: _myAgents.length,
            onPageChanged: (idx) => setState(() => _mineIndex = idx),
            itemBuilder: (context, index) {
              final agent = _myAgents[index];
              final card = _DeckCard(
                name: agent.name,
                mark: agent.isPublic ? '已公开' : '私密',
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
    final isOfficial = card.mark == '官方';
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isOfficial
                        ? MoeTokens.primary.withValues(alpha: 0.12)
                        : MoeTokens.softChipBg,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  ),
                  child: Text(
                    card.mark,
                    style: TextStyle(
                      fontSize: MoeTokens.textXs,
                      fontWeight: FontWeight.w800,
                      color:
                          isOfficial ? MoeTokens.primary : MoeTokens.inkMuted,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
                  color: MoeTokens.hintText,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: MoeTokens.textMd,
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
                  fontSize: MoeTokens.textSm,
                  height: 1.4,
                  color: MoeTokens.inkMuted,
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
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowMd(),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -18,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 132,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: MoeTokens.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MoeTokens.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    ),
                    child: Text(
                      card.mark,
                      style: const TextStyle(
                        fontSize: MoeTokens.textXs,
                        fontWeight: FontWeight.w800,
                        color: MoeTokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    card.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: MoeTokens.text2xl,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: MoeTokens.textBase,
                      height: 1.35,
                      color: MoeTokens.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MoeTokens.pageBackground,
                        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                        border: Border.all(color: MoeTokens.surfaceBorder),
                      ),
                      child: Text(
                        card.body,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: MoeTokens.textSm,
                          height: 1.5,
                          color: MoeTokens.inkMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (onEdit != null) ...[
                        MoePressable(
                          onTap: onEdit,
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusFull),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: MoeTokens.softChipBg,
                              borderRadius:
                                  BorderRadius.circular(MoeTokens.radiusFull),
                              border:
                                  Border.all(color: MoeTokens.surfaceBorder),
                            ),
                            child: const Text(
                              '编辑',
                              style: TextStyle(
                                color: MoeTokens.titleText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                              boxShadow: MoeTokens.shadowSm(),
                            ),
                            child: const Text(
                              '套用身份卡',
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
  const _CreateStage({
    required this.onCreateBlank,
    required this.onPickTemplate,
  });

  final VoidCallback onCreateBlank;
  final ValueChanged<AiStarterAgentTemplate> onPickTemplate;

  @override
  Widget build(BuildContext context) {
    final templates = AiStarterTemplates.agentTemplates;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        MoeReveal(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            decoration: BoxDecoration(
              color: MoeTokens.surface1,
              borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
              border: Border.all(color: MoeTokens.surfaceBorder),
              boxShadow: MoeTokens.shadowMd(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MoeTokens.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: MoeTokens.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '从零创建专属身份卡',
                  style: TextStyle(
                    fontSize: MoeTokens.textXl,
                    fontWeight: FontWeight.w900,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '写下名字、性格、说话语气和开场白，保存后即可随时套用到你的伙伴模型上，也可以公开分享到广场。',
                  style: TextStyle(
                    fontSize: MoeTokens.textBase,
                    height: 1.5,
                    color: MoeTokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 18),
                MoePressable(
                  onTap: onCreateBlank,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: MoeTokens.gradientPrimary,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                      boxShadow: MoeTokens.shadowSm(),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          '创建空白身份卡',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MoeTokens.textMd,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (templates.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '从官方样板改写',
              style: TextStyle(
                fontSize: MoeTokens.textBase,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final tpl in templates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MoeActionRow(
                icon: Icons.style_outlined,
                iconColor: MoeTokens.primary,
                backgroundColor: MoeTokens.surface1,
                borderColor: MoeTokens.surfaceBorder,
                title: tpl.name,
                subtitle: Text(tpl.tagline),
                onTap: () => onPickTemplate(tpl),
              ),
            ),
        ],
      ],
    );
  }
}
