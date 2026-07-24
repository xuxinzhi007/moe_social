import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ai_character_card_service.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_provider_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_provider_profile.dart';
import 'agent_editor_page.dart';
import 'ai_lorebooks_page.dart';
import 'ai_provider_profiles_page.dart';
import 'character_card_plaza_page.dart';
import 'chat_page.dart';
import '../../services/ai_agent_draft_factory.dart';
import '../../services/ai_agent_usage_service.dart';
import '../../services/ai_models_cache_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_empty_state.dart';
import '../../widgets/ai/ai_sheet.dart';
import '../../widgets/ai/ai_theme.dart';
import '../../widgets/moe_action_row.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_search_bar.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';

part 'tavern/agents_tab.part.dart';
part 'tavern/providers_tab.part.dart';

// 精简菜单：仅保留不易被快捷入口覆盖的操作
enum _TavernMenuAction { importCard, lorebooks }

enum _AgentCardAction { edit, export, delete }

enum _CharacterCardExportMode { file, clipboard }

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});

  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AiAgent> _agents = [];
  List<AiAgent> _filteredAgents = [];
  bool _isLoading = true;
  List<String> _squareModels = [];
  bool _isLoadingSquareModels = false;
  List<AiProviderProfile> _providerProfiles = [];
  String _selectedSquareProviderId = '';
  Map<String, Color> _agentColors = {};
  final bool _showFab = true;

  // 新增状态变量
  String _searchQuery = '';
  String _sortBy = '创建时间';
  final List<String> _sortOptions = ['创建时间', '名称', '使用频率'];
  Map<String, int> _usageCounts = {};

  static const _pageBackground = AiBrandTokens.pageBackground;
  static const _brandPrimary = AiBrandTokens.primary;
  static const _brandSecondary = AiBrandTokens.secondary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAgents();
    _loadProviderProfiles();
    _loadUsageCounts();
  }

  Future<void> _loadUsageCounts() async {
    final counts = await AiAgentUsageService().loadCounts();
    if (!mounted) return;
    setState(() => _usageCounts = counts);
  }

  void _updateTavernState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  void _filterAgents() {
    if (!mounted) return;
    setState(() {
      _filteredAgents = _agents.where((agent) {
        // 搜索过滤
        final matchesSearch = _searchQuery.isEmpty ||
            agent.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            agent.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());

        return matchesSearch;
      }).toList();

      // 排序
      _sortAgents();
    });
  }

  void _sortAgents() {
    switch (_sortBy) {
      case '创建时间':
        _filteredAgents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case '名称':
        _filteredAgents.sort((a, b) => a.name.compareTo(b.name));
        break;
      case '使用频率':
        _filteredAgents.sort((a, b) {
          final countA = _usageCounts[a.id] ?? 0;
          final countB = _usageCounts[b.id] ?? 0;
          return countB.compareTo(countA);
        });
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _normalizeProviderId(String? providerId) {
    if (providerId == null || providerId.trim().isEmpty) {
      return AiProviderProfile.builtinBackendId;
    }
    return providerId.trim();
  }

  bool _isBackendProviderId(String? providerId) {
    return _normalizeProviderId(providerId) ==
        AiProviderProfile.builtinBackendId;
  }

  AiProviderProfile _resolveProviderById(String? providerId) {
    if (providerId == null || providerId.trim().isEmpty) {
      return _providerProfiles.firstWhere(
        (p) => p.isBuiltinBackend,
        orElse: () => AiProviderProfile.builtinBackend(),
      );
    }
    final normalized = providerId.trim();
    for (final profile in _providerProfiles) {
      if (profile.id == normalized) return profile;
    }
    return AiProviderProfile.builtinBackend();
  }

  AiProviderProfile get _selectedSquareProvider =>
      _resolveProviderById(_selectedSquareProviderId);

  String _providerSourceLabel(AiProviderProfile profile) {
    if (profile.isLlamaCppServer) return '本机 llama.cpp';
    if (profile.isBuiltinBackend) return '后端推理';
    return '我的 API';
  }

  Future<void> _loadProviderProfiles({bool reloadSquareModels = true}) async {
    final profiles = await AiProviderService().listProfiles();
    final lastSelected = await AiProviderService().readLastSelectedProfileId();
    if (!mounted) return;
    setState(() {
      _providerProfiles = profiles;
      final preferredId = lastSelected ?? _selectedSquareProviderId;
      final exists = profiles.any((item) => item.id == preferredId);
      if (!exists && profiles.isNotEmpty) {
        _selectedSquareProviderId = profiles.first.id;
      } else if (exists) {
        _selectedSquareProviderId = preferredId;
      }
    });
    if (reloadSquareModels) {
      await _loadSquareModels();
    }
  }

  Future<void> _loadSquareModels() async {
    final profileId = _selectedSquareProviderId;
    final cached = await AiModelsCacheService().read(profileId);
    if (cached.isNotEmpty && mounted) {
      setState(() => _squareModels = cached);
    }
    if (mounted) setState(() => _isLoadingSquareModels = true);
    try {
      var models = await AiChatGatewayService()
          .fetchModelsForProfile(_selectedSquareProvider);
      if (models.isEmpty) {
        models = _selectedSquareProvider.effectiveModelIds;
      }
      if (models.isNotEmpty) {
        await AiModelsCacheService().write(profileId, models);
      }
      if (!mounted) return;
      setState(() {
        _squareModels = models.toSet().toList();
      });
    } catch (_) {
      if (!mounted) return;
      if (_squareModels.isEmpty) {
        setState(() => _squareModels = []);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSquareModels = false);
      }
    }
  }

  Future<void> _reloadPageData() async {
    await _loadProviderProfiles();
    if (!mounted) return;
    await _loadAgents();
  }

  Future<void> _loadAgents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final cloudAgents = await AiAgentCloudService()
          .getAgents()
          .timeout(const Duration(seconds: 12));
      _applyAgents(_dedupeAgents(cloudAgents));
    } catch (e, st) {
      debugPrint('load agents failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _agents = [];
        _filteredAgents = [];
      });
      MoeToast.error(context, '加载我的智能体失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyAgents(List<AiAgent> agents) {
    if (!mounted) return;
    final colors = _generateAgentColors(agents);
    setState(() {
      _agents = agents;
      _agentColors = colors;
    });
    _filterAgents();
  }

  /// 角色剧场只展示真实角色卡，不把 Ollama 模型名冒充为角色。
  List<AiAgent> _dedupeAgents(List<AiAgent> agents) {
    final seen = <String>{};
    final out = <AiAgent>[];
    for (final agent in agents) {
      if (seen.add(agent.id)) {
        out.add(agent);
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Map<String, Color> _generateAgentColors(List<AiAgent> agents) {
    final colors = <String, Color>{};
    final colorList = [
      MoeTokens.primary,
      MoeTokens.secondary,
      MoeTokens.accent,
      const Color(0xFFFF9A9E),
      const Color(0xFFA18CD1),
      const Color(0xFFFAD0C4),
      const Color(0xFFFFD1DC),
      const Color(0xFFE0F7FA),
      const Color(0xFFE8EAF6),
      const Color(0xFFF3E5F5),
    ];

    for (final agent in agents) {
      final random = Random(agent.id.hashCode);
      final color = colorList[random.nextInt(colorList.length)];
      colors[agent.id] = color;
    }

    return colors;
  }

  AiAgent? _findExistingAgentForModel(
    String modelName, {
    required String providerId,
  }) {
    final normalizedProviderId = _normalizeProviderId(providerId);
    for (final agent in _agents) {
      if (agent.modelName == modelName &&
          _normalizeProviderId(agent.providerProfileId) ==
              normalizedProviderId) {
        return agent;
      }
    }
    return null;
  }

  Future<void> _onTavernMenuSelected(_TavernMenuAction action) async {
    switch (action) {
      case _TavernMenuAction.importCard:
        await _showImportCharacterCardDialog();
      case _TavernMenuAction.lorebooks:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiLorebooksPage()),
        );
        if (mounted) await _loadAgents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      template: PageTemplate.fullscreen,
      backgroundColor: _pageBackground,
      floatingActionButton: _showFab ? _buildFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildHeroHeader()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(child: _buildCustomTabBar()),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyAgentsList(),
            _buildAgentSquare(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _brandPrimary,
            _brandSecondary,
            const Color(0xFF7DD3FC),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MoeTokens.spaceXl,
              MoeTokens.spaceLg, MoeTokens.spaceXl, MoeTokens.space3xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── 左侧：返回按钮 + 标题 ──
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          padding: const EdgeInsets.all(MoeTokens.spaceSm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: MoeTokens.spaceMd),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 酒馆',
                            style: TextStyle(
                              fontSize: MoeTokens.text3xl,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: MoeTokens.spaceSm),
                          Text(
                            '创造你的专属角色，开启奇妙对话',
                            style: TextStyle(
                              fontSize: MoeTokens.textBase,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // ── 右侧：精简菜单 ──
                  PopupMenuButton<_TavernMenuAction>(
                    tooltip: '更多功能',
                    icon: Container(
                      padding: const EdgeInsets.all(MoeTokens.spaceSm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    onSelected: _onTavernMenuSelected,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _TavernMenuAction.importCard,
                        child: _buildTavernMenuItem(
                          icon: Icons.input_rounded,
                          title: '导入角色卡',
                        ),
                      ),
                      PopupMenuItem(
                        value: _TavernMenuAction.lorebooks,
                        child: _buildTavernMenuItem(
                          icon: Icons.menu_book_rounded,
                          title: '世界书管理',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: MoeTokens.spaceXl),
              _buildHeroSearchBar(),
              const SizedBox(height: MoeTokens.spaceLg),
              Row(
                children: [
                  _buildHeroStat(
                    icon: Icons.people_alt_rounded,
                    value: '${_agents.length}',
                    label: '角色',
                  ),
                  const SizedBox(width: MoeTokens.spaceLg),
                  _buildHeroStat(
                    icon: Icons.hub_rounded,
                    value: '${_providerProfiles.length}',
                    label: '模型源',
                  ),
                  const SizedBox(width: MoeTokens.spaceLg),
                  _buildHeroStat(
                    icon: Icons.auto_awesome_rounded,
                    value: '${_usageCounts.length}',
                    label: '对话过',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          _updateTavernState(() => _searchQuery = value);
          _filterAgents();
        },
        style: TextStyle(fontSize: MoeTokens.textBase, height: 1.4),
        decoration: InputDecoration(
          hintText: '搜索角色、描述或模型...',
          hintStyle: TextStyle(
              color: Colors.grey.shade400, fontSize: MoeTokens.textBase),
          prefixIcon:
              Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: Colors.grey.shade400, size: 20),
                  onPressed: () {
                    _updateTavernState(() => _searchQuery = '');
                    _filterAgents();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: MoeTokens.spaceLg, vertical: MoeTokens.spaceMd),
        ),
      ),
    );
  }

  Widget _buildHeroStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(MoeTokens.spaceSm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          ),
          child: Icon(icon, color: Colors.white, size: MoeTokens.textLg),
        ),
        const SizedBox(width: MoeTokens.spaceSm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: MoeTokens.textLg,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: MoeTokens.textXs,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(MoeTokens.spaceLg, MoeTokens.spaceLg,
          MoeTokens.spaceLg, MoeTokens.spaceXs),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.add_circle_rounded,
              title: '新建角色',
              subtitle: '创建你的专属AI',
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brandPrimary, _brandSecondary],
              ),
              onTap: () async {
                HapticFeedback.lightImpact();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AgentEditorPage()),
                );
                if (result == true && mounted) {
                  await _loadAgents();
                }
              },
            ),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.storefront_rounded,
              title: '角色广场',
              subtitle: '发现更多角色',
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFFF472B6), const Color(0xFFC084FC)],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CharacterCardPlazaPage()),
                );
                if (mounted) await _loadAgents();
              },
            ),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.menu_book_rounded,
              title: '世界书',
              subtitle: '世界观设定',
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF34D3C8), const Color(0xFF60A5FA)],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiLorebooksPage()),
                );
                if (mounted) await _loadAgents();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(MoeTokens.spaceMd),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient)
                  .colors
                  .first
                  .withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(MoeTokens.spaceSm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: MoeTokens.spaceMd),
            Text(
              title,
              style: const TextStyle(
                fontSize: MoeTokens.textBase,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: MoeTokens.spaceXs),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: MoeTokens.textXs,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(MoeTokens.spaceLg, MoeTokens.spaceMd,
          MoeTokens.spaceLg, MoeTokens.spaceSm),
      child: Container(
        padding: const EdgeInsets.all(MoeTokens.spaceXs),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Row(
          children: [
            _buildTabItem(0, '角色剧场', Icons.theater_comedy_rounded),
            _buildTabItem(1, '模型来源', Icons.hub_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          if (mounted) setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: MoeTokens.spaceMd),
          decoration: BoxDecoration(
            color: isSelected ? _brandPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade500,
              ),
              const SizedBox(width: MoeTokens.spaceSm),
              Text(
                label,
                style: TextStyle(
                  fontSize: MoeTokens.textBase,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(MoeTokens.spaceLg, MoeTokens.spaceLg,
          MoeTokens.spaceLg, MoeTokens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: MoeTokens.textXl,
                    fontWeight: FontWeight.w800,
                    color: AiBrandTokens.titleColor,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceXs),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildTavernMenuItem({
    required IconData icon,
    required String title,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AiBrandTokens.primary),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () async {
        HapticFeedback.lightImpact();
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AgentEditorPage()),
        );
        if (result == true && mounted) {
          await _loadAgents();
        }
      },
      backgroundColor: _brandPrimary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoeTokens.radius2xl)),
      heroTag: 'agent_list_fab',
      child: const Icon(Icons.add_rounded, size: 24),
    );
  }

  Future<void> _openAgentEditor({AiAgent? agent}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgentEditorPage(agent: agent)),
    );
    if (result == true && mounted) {
      await _loadAgents();
    }
  }

  Future<void> _createFromStarterTemplate() async {
    final template = await showModalBottomSheet<AiStarterAgentTemplate>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(MoeTokens.spaceLg),
          children: [
            const Text(
              '默认角色模板',
              style: TextStyle(
                  fontSize: MoeTokens.textLg, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: MoeTokens.spaceSm),
            Text(
              '先套一个骨架，再继续改成你自己的 Tavern 风格。',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: MoeTokens.spaceLg),
            ...AiStarterTemplates.agentTemplates.map(
              (template) => Card(
                child: MoeActionRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AiBrandTokens.primary,
                  title: template.name,
                  subtitle: Text(
                    '${template.tagline}\n${template.description}',
                    style: const TextStyle(height: 1.4),
                  ),
                  onTap: () => Navigator.pop(ctx, template),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (template == null || !mounted) return;
    final draft = AiStarterTemplates.buildAgentFromTemplate(
      template,
      modelName: _squareModels.isNotEmpty ? _squareModels.first : 'llama3:8b',
      providerProfileId: _selectedSquareProvider.isBackendOllama
          ? null
          : _selectedSquareProvider.id,
    );
    await _openAgentEditor(agent: draft);
  }

  Widget _buildMyAgentsList() => tavernBuildMyAgentsList();

  Widget _buildAgentSquare() => tavernBuildAgentSquare();

  Future<void> _createAgentWithManualModelId(AiProviderProfile provider) async {
    final controller = TextEditingController(
      text: provider.defaultModel.trim(),
    );
    if (!mounted) return;
    final modelId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('绑定模型 ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '填写你在中转站控制台里实际调用的模型名，例如 gpt-4o-mini、deepseek-chat。',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '模型 ID',
                hintText: 'gpt-4o-mini',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (v) {
                final trimmed = v.trim();
                if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) return;
              Navigator.pop(ctx, trimmed);
            },
            child: const Text('创建角色卡'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (modelId == null || modelId.trim().isEmpty || !mounted) return;
    await _createAgentFromModel(modelId.trim(), provider);
  }

  Future<void> _createAgentFromModel(
    String modelName,
    AiProviderProfile provider,
  ) async {
    final existing = _findExistingAgentForModel(
      modelName,
      providerId: provider.id,
    );
    if (existing != null) {
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(agent: existing)),
        );
      }
      return;
    }

    // 角色卡 = 身份设定 + 绑定已有模型 ID；不调用 Ollama 创建模型 API。
    final draft = AiAgentDraftFactory.fromModel(
      modelName: modelName,
      provider: provider,
    );
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AgentEditorPage(agent: draft),
      ),
    );
    if (saved == true && mounted) {
      await _loadAgents();
    }
  }

  Future<void> _finishCharacterCardImport(
    AiCharacterCardImportResult result,
  ) async {
    await _reloadPageData();
    if (!mounted) return;
    final noticeText =
        result.notices.isEmpty ? '' : '；${result.notices.join('；')}';
    MoeToast.success(
      context,
      '角色卡已导入：${result.agent.name}$noticeText',
    );
  }

  Future<void> _showImportCharacterCardDialog() async {
    final controller = TextEditingController();
    var isImporting = false;
    final exportDirHint = await AiCharacterCardService().exportDirectoryPath();
    if (!mounted) return;

    await AiSheet.show<void>(
      context: context,
      title: '导入角色卡',
      subtitle: '支持 JSON 文件、粘贴内容；含人设与世界书，不含 API Key',
      child: StatefulBuilder(
        builder: (ctx, setLocalState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.tonalIcon(
              onPressed: isImporting
                  ? null
                  : () async {
                      setLocalState(() => isImporting = true);
                      try {
                        final result = await AiCharacterCardService()
                            .importCharacterCardFromFilePicker();
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _finishCharacterCardImport(result);
                      } catch (e) {
                        if (!mounted) return;
                        final msg = e
                            .toString()
                            .replaceFirst(RegExp(r'^Exception:\s*'), '');
                        if (msg.contains('已取消')) return;
                        MoeToast.error(context, msg);
                      } finally {
                        if (ctx.mounted) {
                          setLocalState(() => isImporting = false);
                        }
                      }
                    },
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('从 JSON 文件导入'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 10,
              maxLines: 16,
              decoration: AiTheme.inputDecoration(
                hintText: '或粘贴从其他平台导出的角色卡 JSON',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: isImporting
                  ? null
                  : () async {
                      final data = await Clipboard.getData('text/plain');
                      final text = data?.text?.trim() ?? '';
                      if (text.isEmpty) {
                        if (mounted) {
                          MoeToast.error(context, '剪贴板里没有可用内容');
                        }
                        return;
                      }
                      setLocalState(() => controller.text = text);
                    },
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('从剪贴板粘贴'),
            ),
            const SizedBox(height: 8),
            Text(
              exportDirHint == null
                  ? '导入仅含人设与推荐模型；导出文件名为「角色名_card.json」。'
                  : '本应用导出目录：\n$exportDirHint\n（桌面端选文件时会优先打开此目录）',
              style: AiTheme.caption,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isImporting ? null : () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: AiTheme.primaryButtonStyle(),
                    onPressed: isImporting
                        ? null
                        : () async {
                            final raw = controller.text.trim();
                            if (raw.isEmpty) {
                              MoeToast.error(context, '请先粘贴角色卡内容');
                              return;
                            }
                            setLocalState(() => isImporting = true);
                            try {
                              final result = await AiCharacterCardService()
                                  .importCharacterCardJson(raw);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              await _finishCharacterCardImport(result);
                            } catch (e) {
                              if (mounted) {
                                final msg = e.toString().replaceFirst(
                                    RegExp(r'^Exception:\s*'), '');
                                MoeToast.error(context, msg);
                              }
                            } finally {
                              if (ctx.mounted) {
                                setLocalState(() => isImporting = false);
                              }
                            }
                          },
                    child: isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('导入'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  Future<void> _exportCharacterCard(AiAgent agent) async {
    final mode = await AiSheet.showActions<_CharacterCardExportMode>(
      context: context,
      title: '导出角色卡',
      subtitle: '导出文件便于备份；复制适合快速粘贴导入',
      actions: const [
        AiSheetAction(
          icon: Icons.ios_share_rounded,
          label: '导出为文件',
          subtitle: '通过系统分享保存到本机或其它应用',
          value: _CharacterCardExportMode.file,
        ),
        AiSheetAction(
          icon: Icons.content_copy_rounded,
          label: '复制到剪贴板',
          subtitle: '适合在其它设备上粘贴导入',
          value: _CharacterCardExportMode.clipboard,
        ),
      ],
    );
    if (!mounted || mode == null) return;

    try {
      final service = AiCharacterCardService();
      switch (mode) {
        case _CharacterCardExportMode.file:
          final savedPath = await service.shareCharacterCardFile(agent);
          if (!mounted) return;
          final fileLabel = savedPath.contains(RegExp(r'[/\\]'))
              ? savedPath.split(RegExp(r'[/\\]')).last
              : savedPath;
          MoeToast.success(
            context,
            '已导出 $fileLabel，可在分享面板另存到下载目录',
          );
        case _CharacterCardExportMode.clipboard:
          await service.copyCharacterCardToClipboard(agent);
          if (!mounted) return;
          MoeToast.success(context, '角色卡内容已复制到剪贴板');
      }
    } catch (_) {
      if (mounted) {
        MoeToast.error(context, '导出失败，请重试');
      }
    }
  }

  Future<void> _showAgentOptions(AiAgent agent) async {
    HapticFeedback.lightImpact();
    final action = await AiSheet.showActions<_AgentCardAction>(
      context: context,
      title: agent.name,
      subtitle: '轻触卡片即可开始聊天',
      actions: const [
        AiSheetAction(
          icon: Icons.edit_rounded,
          label: '编辑角色卡',
          value: _AgentCardAction.edit,
        ),
        AiSheetAction(
          icon: Icons.ios_share_rounded,
          label: '导出角色卡',
          value: _AgentCardAction.export,
        ),
        AiSheetAction(
          icon: Icons.delete_outline_rounded,
          label: '删除角色卡',
          subtitle: '不可恢复',
          value: _AgentCardAction.delete,
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _AgentCardAction.edit:
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => AgentEditorPage(agent: agent),
          ),
        );
        if (result == true && mounted) {
          await _loadAgents();
        }
      case _AgentCardAction.export:
        await _exportCharacterCard(agent);
      case _AgentCardAction.delete:
        await _confirmDeleteAgent(agent);
    }
  }

  Future<void> _confirmDeleteAgent(AiAgent agent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl)),
        title: const Text('确认删除'),
        content: Text('确定要删除角色卡「${agent.name}」吗？相关聊天记录也将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // 角色卡仅为服务器 JSON；model_name 是聊天用的模型 ID，不等于 Ollama 里创建的模型。
    try {
      await AiAgentCloudService().deleteAgent(agent.id);
    } catch (e) {
      if (mounted) MoeToast.error(context, '删除角色卡失败：$e');
      return;
    }
    if (mounted) {
      await _loadAgents();
    }
    if (mounted) {
      MoeToast.success(context, '角色卡已删除');
    }
  }
}
