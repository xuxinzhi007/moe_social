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
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_empty_state.dart';
import '../../widgets/ai/ai_sheet.dart';
import '../../widgets/ai/ai_theme.dart';
import '../../widgets/moe_action_row.dart';
import 'tavern/tavern_hero_card.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_search_bar.dart';

part 'tavern/agents_tab.part.dart';
part 'tavern/providers_tab.part.dart';

enum _TavernMenuAction { plaza, importCard, lorebooks, providers }

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
      const Color(0xFF7F7FD5),
      const Color(0xFF86A8E7),
      const Color(0xFF91EAE4),
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
      case _TavernMenuAction.plaza:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CharacterCardPlazaPage()),
        );
        if (mounted) await _loadAgents();
      case _TavernMenuAction.importCard:
        await _showImportCharacterCardDialog();
      case _TavernMenuAction.lorebooks:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiLorebooksPage()),
        );
        if (mounted) await _loadAgents();
      case _TavernMenuAction.providers:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiProviderProfilesPage()),
        );
        if (mounted) await _reloadPageData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text(
          'AI 酒馆',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: _pageBackground,
        elevation: 0,
        actions: [
          PopupMenuButton<_TavernMenuAction>(
            tooltip: '酒馆菜单',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: _onTavernMenuSelected,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _TavernMenuAction.plaza,
                child: _buildTavernMenuItem(
                  icon: Icons.storefront_rounded,
                  title: '角色卡广场',
                ),
              ),
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
              PopupMenuItem(
                value: _TavernMenuAction.providers,
                child: _buildTavernMenuItem(
                  icon: Icons.hub_rounded,
                  title: '模型来源管理',
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '角色剧场'),
            Tab(text: '模型来源'),
          ],
          indicatorColor: _brandPrimary,
          labelColor: _brandPrimary,
          unselectedLabelColor: Colors.grey[600],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyAgentsList(),
          _buildAgentSquare(),
        ],
      ),
      floatingActionButton: _showFab ? _buildFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2430),
                  ),
                ),
                const SizedBox(height: 4),
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

  Widget _buildHeroCard() {
    return TavernHeroCard(
      agentCount: _agents.length,
      providerCount: _providerProfiles.length,
      onOpenProvidersTab: () => _tabController.animateTo(1),
    );
  }

  Widget _buildTemplateChipRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: Icon(Icons.auto_awesome_rounded,
              size: 18, color: AiBrandTokens.primary),
          label: const Text('套用角色模板'),
          onPressed: _createFromStarterTemplate,
        ),
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '默认角色模板',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '先套一个骨架，再继续改成你自己的 Tavern 风格。',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
