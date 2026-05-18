import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../../services/ai_character_card_service.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/llm_endpoint_config.dart';
import '../../services/ai_db_service.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_prompt_defaults.dart';
import '../../services/ai_provider_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_provider_profile.dart';
import 'agent_editor_page.dart';
import 'ai_lorebooks_page.dart';
import 'ai_provider_profiles_page.dart';
import 'chat_page.dart';
import 'content_generation_page.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_search_bar.dart';

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});

  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AiAgent> _agents = [];
  List<AiAgent> _filteredAgents = [];
  bool _isLoading = true;
  List<String> _squareModels = [];
  bool _isLoadingSquareModels = false;
  List<AiProviderProfile> _providerProfiles = [
    AiProviderProfile.builtinBackend(),
  ];
  String _selectedSquareProviderId = AiProviderProfile.builtinBackendId;
  Map<String, Color> _agentColors = {};
  bool _showFab = true;
  
  // 新增状态变量
  String _searchQuery = '';
  String _selectedCategory = '全部';
  String _sortBy = '创建时间';
  List<String> _categories = ['全部', '工作', '娱乐', '学习', '创意', '其他'];
  List<String> _sortOptions = ['创建时间', '名称', '使用频率'];
  Map<String, int> _usageCounts = {};

  static const _pageBackground = Color(0xFFF3F5FB);
  static const _brandPrimary = Color(0xFF7F7FD5);
  static const _brandSecondary = Color(0xFF86A8E7);
  static const _brandAccent = Color(0xFF91EAE4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAgents();
    _loadProviderProfiles();
    _loadUsageCounts();
  }
  
  Future<void> _loadUsageCounts() async {
    // 这里可以从本地存储或数据库加载使用频率数据
    // 暂时使用模拟数据
    setState(() {
      _usageCounts = {
        // 模拟数据，实际应从存储中加载
      };
    });
  }
  
  void _filterAgents() {
    setState(() {
      _filteredAgents = _agents.where((agent) {
        // 搜索过滤
        final matchesSearch = _searchQuery.isEmpty || 
            agent.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            agent.description.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // 分类过滤
        final matchesCategory = _selectedCategory == '全部';
        
        return matchesSearch && matchesCategory;
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
    final normalized = _normalizeProviderId(providerId);
    for (final profile in _providerProfiles) {
      if (profile.id == normalized) return profile;
    }
    return AiProviderProfile.builtinBackend();
  }

  AiProviderProfile get _selectedSquareProvider =>
      _resolveProviderById(_selectedSquareProviderId);

  String _providerSourceLabel(AiProviderProfile profile) {
    return profile.isBuiltinBackend ? '服务器 Ollama' : '我的 API';
  }

  Future<void> _loadProviderProfiles({bool reloadSquareModels = true}) async {
    final profiles = await AiProviderService().listProfiles();
    final lastSelected = await AiProviderService().readLastSelectedProfileId();
    if (!mounted) return;
    setState(() {
      _providerProfiles = profiles;
      final preferredId = lastSelected ?? _selectedSquareProviderId;
      final exists = profiles.any((item) => item.id == preferredId);
      if (!exists) {
        _selectedSquareProviderId = AiProviderProfile.builtinBackendId;
      } else {
        _selectedSquareProviderId = preferredId;
      }
    });
    if (reloadSquareModels) {
      await _loadSquareModels();
    }
  }

  Future<void> _loadSquareModels() async {
    if (mounted) setState(() => _isLoadingSquareModels = true);
    try {
      final models = await AiChatGatewayService()
          .fetchModelsForProfile(_selectedSquareProvider);
      if (!mounted) return;
      setState(() {
        _squareModels = models.toSet().toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _squareModels = []);
    } finally {
      if (mounted) {
        setState(() => _isLoadingSquareModels = false);
      }
    }
  }

  Future<void> _reloadPageData() async {
    await _loadProviderProfiles();
    await _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    try {
      var modelNames = <String>[];
      try {
        final uri = await LlmEndpointConfig.modelsUri();
        ApiService.logDirectHttp('GET', uri);
        final response = await http
            .get(uri, headers: ApiService.mergeTunnelHeaders(uri))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final decodedBody = utf8.decode(response.bodyBytes);
          final data = jsonDecode(decodedBody);
          if (data is Map && data['models'] is List) {
            final raw = data['models'] as List;
            if (raw.whereType<String>().isNotEmpty) {
              modelNames = raw.whereType<String>().toList();
            } else {
              modelNames = raw
                  .whereType<Map>()
                  .map((m) => m['name'])
                  .whereType<String>()
                  .toList();
            }
          }
        }
      } catch (_) {
        // 保持静默：允许仅使用本地自定义智能体。
      }

      // 读取本地元数据（描述/提示词）作为可选增强，失败不阻塞页面。
      List<AiAgent> localAgents = [];
      try {
        localAgents =
            await AiAgentCloudService()
                .getAgents()
                .timeout(const Duration(seconds: 2));
      } catch (_) {}
      final localByBackendModel = <String, AiAgent>{
        for (final a in localAgents)
          if (_isBackendProviderId(a.providerProfileId)) a.modelName: a,
      };

      final now = DateTime.now();
      final agents = modelNames.map((model) {
        final local = localByBackendModel[model];
        if (local != null) return local;
        return AiAgent(
          id: model,
          name: model,
          description: _getModelDescription(model),
          systemPrompt: AiPromptDefaults.defaultAgentSystemPrompt,
          modelName: model,
          createdAt: now,
        );
      }).toList();
      for (final local in localAgents) {
        final exists = agents.any((item) => item.id == local.id);
        if (!exists) {
          agents.add(local);
        }
      }

      // 为每个智能体生成随机颜色
      final colors = _generateAgentColors(agents);

      if (!mounted) return;
      setState(() {
        _agents = agents;
        _agentColors = colors;
      });

      // 加载后过滤智能体
      _filterAgents();
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
          IconButton(
            tooltip: '导入角色卡',
            onPressed: _showImportCharacterCardDialog,
            icon: const Icon(Icons.input_rounded),
          ),
          IconButton(
            tooltip: 'Lorebook 管理',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiLorebooksPage(),
                ),
              );
              if (mounted) {
                _loadAgents();
              }
            },
            icon: const Icon(Icons.menu_book_rounded),
          ),
          IconButton(
            tooltip: 'Provider 管理',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiProviderProfilesPage(),
                ),
              );
              if (mounted) {
                _reloadPageData();
              }
            },
            icon: const Icon(Icons.hub_rounded),
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

  Widget _buildHeroCard() {
    final activeProviders = _providerProfiles.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandPrimary, _brandSecondary, _brandAccent],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _brandPrimary.withOpacity(0.24),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            left: -24,
            bottom: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: () => _tabController.animateTo(1),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.16),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('看模型来源'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  '把角色、世界观、模型来源放进同一个酒馆入口。',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '支持自定义 API、中转站、服务器 Ollama，以及可直接套用的默认角色 / 世界书模板。',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _heroChip('角色 ${_agents.length}', Icons.person_outline_rounded),
                    _heroChip('Provider ${activeProviders}', Icons.hub_outlined),
                    _heroChip('世界书 ${_lorebooksCountHint()}', Icons.menu_book_outlined),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _lorebooksCountHint() {
    try {
      return '已接入';
    } catch (_) {
      return '可用';
    }
  }

  Widget _heroChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        if (result == true) {
          _loadAgents();
        }
      },
      backgroundColor: _brandPrimary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Icon(Icons.add_rounded, size: 24),
      heroTag: 'agent_list_fab',
    );
  }

  Future<void> _openAgentEditor({AiAgent? agent}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgentEditorPage(agent: agent)),
    );
    if (result == true) {
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
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    template.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${template.tagline}\n${template.description}',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                  isThreeLine: true,
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
      providerProfileId: _selectedSquareProvider.isBuiltinBackend
          ? null
          : _selectedSquareProvider.id,
    );
    await _openAgentEditor(agent: draft);
  }

  Widget _buildQuickActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _quickActionTile(
              icon: Icons.auto_awesome_rounded,
              title: '套用角色模板',
              subtitle: '快速起一个 Tavern 骨架',
              colors: const [_brandPrimary, _brandSecondary],
              onTap: _createFromStarterTemplate,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickActionTile(
              icon: Icons.menu_book_rounded,
              title: '新建世界书',
              subtitle: '补地点、规则和人物关系',
              colors: const [Color(0xFF5CA9E6), _brandAccent],
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiLorebooksPage()),
                );
                if (mounted) {
                  await _loadAgents();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          MoeSearchBar(
            hintText: '搜索角色、描述或模型',
            onSearch: (query) {
              setState(() {
                _searchQuery = query;
                _filterAgents();
              });
            },
            onClear: () {
              setState(() {
                _searchQuery = '';
                _filterAgents();
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedCategory = value;
                      _filterAgents();
                    });
                  },
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category, style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                  decoration: InputDecoration(
                    labelText: '分类',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FD),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _sortBy = value;
                      _filterAgents();
                    });
                  },
                  items: _sortOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option,
                          child: Text(option, style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                  decoration: InputDecoration(
                    labelText: '排序',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FD),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgentStatsBar() {
    final customProviders = _agents
        .where((agent) => !_isBackendProviderId(agent.providerProfileId))
        .length;
    final backendAgents = _agents.length - customProviders;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              title: '角色池',
              value: '${_filteredAgents.length}',
              hint: '当前可见角色',
              color: _brandPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              title: '服务器模型',
              value: '$backendAgents',
              hint: '来自 Ollama',
              color: const Color(0xFF5B8DEF),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              title: '我的 API',
              value: '$customProviders',
              hint: '自定义 Provider',
              color: const Color(0xFF00A86B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String hint,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyAgentsList() {
    if (_isLoading) {
      return const Center(child: MoeLoading());
    }
    if (_agents.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _buildHeroCard(),
          _buildQuickActionBar(),
          _buildSectionHeader(
            title: '从这里开始',
            subtitle: '先套模板或挑模型，再逐步补全角色、场景和世界书。',
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_brandPrimary, _brandSecondary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.nightlife_rounded,
                    size: 68,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '还没有角色进驻你的酒馆',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2430),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '你可以直接创建角色，也可以先套用默认模板，再慢慢把人设、开场白、Lorebook 和模型来源补完整。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openAgentEditor(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('新建角色'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _createFromStarterTemplate,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('使用模板'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: const Text('去挑模型'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildHeroCard(),
        _buildQuickActionBar(),
        _buildSectionHeader(
          title: '角色剧场',
          subtitle: '角色、模型来源与酒馆设定都在这里汇总管理。',
        ),
        _buildFilterPanel(),
        _buildAgentStatsBar(),
        if (_filteredAgents.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, color: Colors.grey[300], size: 54),
                const SizedBox(height: 12),
                Text(
                  '没有找到匹配的角色',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedCategory = '全部';
                      _filterAgents();
                    });
                  },
                  child: const Text('清除筛选'),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            itemCount: _filteredAgents.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
                    final agent = _filteredAgents[index];
                    final agentColor = _agentColors[agent.id] ?? _brandPrimary;
                    final usageCount = _usageCounts[agent.id] ?? 0;
                    final provider = _resolveProviderById(agent.providerProfileId);
                    final isBackendProvider = provider.isBuiltinBackend;
                    final providerColor = isBackendProvider
                        ? const Color(0xFF5B8DEF)
                        : const Color(0xFF00A86B);
                    return FadeInUp(
                      delay: Duration(milliseconds: 30 * (index % 8)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: agentColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              // 更新使用频率
                              setState(() {
                                _usageCounts[agent.id] = (usageCount) + 1;
                              });
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(agent: agent),
                                ),
                              );
                            },
                            onLongPress: () => _showAgentOptions(agent),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // 智能体头像
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [agentColor, agentColor.withOpacity(0.7)],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: agentColor.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.smart_toy_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                agent.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF333333),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (usageCount > 0)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '使用 $usageCount 次',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          agent.description,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: agentColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                agent.modelName,
                                                style: TextStyle(
                                                  color: agentColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: providerColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                provider.name,
                                                style: TextStyle(
                                                  color: providerColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _providerSourceLabel(provider),
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${agent.createdAt.year}-${agent.createdAt.month}-${agent.createdAt.day}',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 10,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    tooltip: '更多操作',
                                    onSelected: (value) async {
                                      if (value == 'chat') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatPage(agent: agent),
                                          ),
                                        );
                                        return;
                                      }
                                      if (value == 'generate') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ContentGenerationPage(agent: agent),
                                          ),
                                        );
                                        return;
                                      }
                                      if (value == 'more') {
                                        _showAgentOptions(agent);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem<String>(
                                        value: 'chat',
                                        child: Text('进入聊天'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'generate',
                                        child: Text('内容生成'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'more',
                                        child: Text('更多操作'),
                                      ),
                                    ],
                                    child: const Icon(
                                      Icons.more_horiz_rounded,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ],
    );
  }

  Widget _buildAgentSquare() {
    final provider = _selectedSquareProvider;
    final sourceLabel = _providerSourceLabel(provider);

    Widget body;
    if (_isLoadingSquareModels) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MoeLoading(),
          const SizedBox(height: 12),
          Text(
            '正在加载 ${provider.name} 模型列表...',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      );
    } else if (_squareModels.isEmpty) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF86A8E7), Color(0xFF91EAE4)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF86A8E7).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '未找到可用模型',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            provider.isBuiltinBackend
                ? '请检查服务器内置 Ollama 是否可用'
                : '请检查 ${provider.name} 的 Base URL、API Key 或手动模型列表',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadSquareModels,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandSecondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF86A8E7).withOpacity(0.4),
            ),
          ),
        ],
      );
    } else {
      final modelCategories = _categorizeModels(_squareModels);
      body = ListView.builder(
        itemCount: modelCategories.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemBuilder: (context, categoryIndex) {
          final category = modelCategories.keys.elementAt(categoryIndex);
          final categoryModels = modelCategories[category]!;

          return FadeInUp(
            delay: Duration(milliseconds: 50 * categoryIndex),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _brandSecondary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${categoryModels.length})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: categoryModels.map((modelName) {
                    final existing = _findExistingAgentForModel(
                      modelName,
                      providerId: provider.id,
                    );
                    final alreadyAdded = existing != null;
                    final cardColor = alreadyAdded
                        ? const Color(0xFF4CAF50)
                        : (provider.isBuiltinBackend
                            ? _brandSecondary
                            : const Color(0xFF00A86B));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: cardColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _createAgentFromModel(modelName, provider);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [cardColor, cardColor.withOpacity(0.7)],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: cardColor.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    alreadyAdded
                                        ? Icons.check_circle_rounded
                                        : Icons.memory_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              modelName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF333333),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (alreadyAdded)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4CAF50)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                '已创建',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF4CAF50),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getModelDescription(modelName),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cardColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              sourceLabel,
                                              style: TextStyle(
                                                color: cardColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              provider.name,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _getModelSize(modelName),
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  alreadyAdded
                                      ? Icons.chat_bubble_outline_rounded
                                      : Icons.add_circle_outline_rounded,
                                  color: cardColor,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildSectionHeader(
          title: '模型来源',
          subtitle: '明确区分服务器 Ollama 与你的自定义 API，避免来源混淆。',
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _providerProfiles.any(
                        (item) => item.id == _selectedSquareProviderId,
                      )
                          ? _selectedSquareProviderId
                          : AiProviderProfile.builtinBackendId,
                      decoration: InputDecoration(
                        labelText: '当前模型来源',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FD),
                      ),
                      isExpanded: true,
                      items: _providerProfiles
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _selectedSquareProviderId = value);
                        await AiProviderService().saveLastSelectedProfileId(value);
                        await _loadSquareModels();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: '刷新模型',
                    onPressed: _loadSquareModels,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _squareMetaChip(
                      'Provider：${provider.name}',
                      _brandPrimary,
                    ),
                    _squareMetaChip('来源：$sourceLabel', Colors.blueGrey),
                    _squareMetaChip('模型数：${_squareModels.length}', _brandSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
        body,
      ],
    );
  }

  Widget _squareMetaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  // 模型分类
  Map<String, List<String>> _categorizeModels(List<String> models) {
    final categories = <String, List<String>>{
      '通用模型': [],
      '专业模型': [],
      '创意模型': [],
      '其他模型': [],
    };
    
    for (final model in models) {
      if (model.contains('llama') || model.contains('gemma') || model.contains('mistral')) {
        categories['通用模型']!.add(model);
      } else if (model.contains('code') || model.contains('math') || model.contains('scientific')) {
        categories['专业模型']!.add(model);
      } else if (model.contains('creative') || model.contains('art') || model.contains('writing')) {
        categories['创意模型']!.add(model);
      } else {
        categories['其他模型']!.add(model);
      }
    }
    
    // 移除空分类
    categories.removeWhere((key, value) => value.isEmpty);
    
    return categories;
  }
  
  // 获取模型描述
  String _getModelDescription(String model) {
    if (model.contains('llama')) {
      return 'Meta的大型语言模型，适用于多种任务';
    } else if (model.contains('gemma')) {
      return 'Google的轻量级语言模型，性能优异';
    } else if (model.contains('mistral')) {
      return 'Mistral AI的高效语言模型，推理能力强';
    } else if (model.contains('code')) {
      return '专门用于代码生成和理解的模型';
    } else if (model.contains('creative')) {
      return '擅长创意写作和内容生成的模型';
    } else {
      return '通用AI模型，可用于多种任务';
    }
  }
  
  // 获取模型大小
  String _getModelSize(String model) {
    if (model.contains('7b') || model.contains('8b')) {
      return '小模型';
    } else if (model.contains('13b') || model.contains('14b')) {
      return '中模型';
    } else if (model.contains('34b') || model.contains('70b')) {
      return '大模型';
    } else {
      return '未知大小';
    }
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(agent: existing)),
        );
      }
      return;
    }

    // 后端统一模式下直接用模型构建会话入口，不强依赖本地入库。
    final agent = AiAgent(
      id: provider.isBuiltinBackend
          ? modelName
          : '${provider.id}::$modelName',
      name: modelName,
      description: '基于 $modelName 的对话',
      systemPrompt: AiPromptDefaults.defaultAgentSystemPrompt,
      modelName: modelName,
      providerProfileId: provider.isBuiltinBackend ? null : provider.id,
      createdAt: DateTime.now(),
    );

    if (!provider.isBuiltinBackend) {
      try {
        await AiDbService().insertAgent(agent);
        await AiAgentCloudService().saveAgent(agent);
        await _loadAgents();
      } catch (_) {
        // Ignore local persistence errors and continue opening chat.
      }
    }

    if (mounted) {
      MoeToast.success(
        context,
        provider.isBuiltinBackend
            ? '已使用服务器模型创建会话'
            : '已使用自定义 Provider 创建智能体',
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage(agent: agent)),
      );
    }
  }

  Future<void> _showImportCharacterCardDialog() async {
    final controller = TextEditingController();
    var isImporting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('导入角色卡'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  minLines: 10,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    hintText: '粘贴角色卡 JSON',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          final text = data?.text?.trim() ?? '';
                          if (text.isEmpty) {
                            if (mounted) {
                              MoeToast.error(context, '剪贴板里没有可用内容');
                            }
                            return;
                          }
                          controller.text = text;
                        },
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('从剪贴板粘贴'),
                      ),
                      Text(
                        '支持导入角色基础字段、Provider 骨架、Lorebook 设定',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: isImporting
                  ? null
                  : () async {
                      final raw = controller.text.trim();
                      if (raw.isEmpty) {
                        MoeToast.error(context, '请先粘贴角色卡 JSON');
                        return;
                      }
                      setLocalState(() => isImporting = true);
                      try {
                        final result = await AiCharacterCardService()
                            .importCharacterCardJson(raw);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _reloadPageData();
                        if (!mounted) return;
                        final noticeText = result.notices.isEmpty
                            ? ''
                            : '；${result.notices.join('；')}';
                        MoeToast.success(
                          context,
                          '角色卡已导入：${result.agent.name}$noticeText',
                        );
                      } catch (e) {
                        if (mounted) {
                          MoeToast.error(context, e.toString());
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
          ],
        ),
      ),
    );

    controller.dispose();
  }

  Future<void> _exportCharacterCard(AiAgent agent) async {
    final raw = await AiCharacterCardService().exportCharacterCardJson(agent);
    await Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    MoeToast.success(context, '角色卡 JSON 已复制到剪贴板');
  }

  void _showAgentOptions(AiAgent agent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(top: 50),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F7FD5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Color(0xFF7F7FD5)),
                  ),
                  title: const Text('编辑智能体', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AgentEditorPage(agent: agent),
                      ),
                    );
                    if (result == true) {
                      _loadAgents();
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.create_rounded, color: Colors.blue),
                  ),
                  title: const Text('内容生成', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContentGenerationPage(agent: agent),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.ios_share_rounded,
                      color: Colors.green,
                    ),
                  ),
                  title: const Text(
                    '导出角色卡',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    await _exportCharacterCard(agent);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                  title: const Text('删除智能体', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('确认删除'),
                        content: Text('确定要删除智能体 "${agent.name}" 吗？所有相关聊天记录也将被删除。'),
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
                    if (confirm == true) {
                      final isBackendAgent =
                          (agent.providerProfileId == null ||
                              agent.providerProfileId ==
                                  AiProviderProfile.builtinBackendId);
                      if (isBackendAgent) {
                        try {
                          final uri = Uri.parse('${ApiService.baseUrl}/api/llm/models/delete');
                          ApiService.logDirectHttp('POST', uri);
                          final response = await http.post(
                            uri,
                            headers: ApiService.mergeTunnelHeaders(uri, headers: {
                              'Content-Type': 'application/json',
                              if (ApiService.token case final t?)
                                'Authorization': 'Bearer $t',
                            }),
                            body: jsonEncode({'model': agent.modelName}),
                          );
                          if (response.statusCode != 200) {
                            throw Exception('删除失败(${response.statusCode})');
                          }
                          final data = jsonDecode(utf8.decode(response.bodyBytes));
                          if (data is Map && data['success'] == false) {
                            throw Exception(data['message'] ?? '删除失败');
                          }
                        } catch (e) {
                          if (mounted) MoeToast.error(context, '删除后端模型失败：$e');
                          return;
                        }
                      }
                      // 本地元数据清理（非关键）
                      try {
                        await AiAgentCloudService().deleteAgent(agent.id);
                      } catch (_) {}
                      _loadAgents();
                      if (mounted) {
                        MoeToast.success(
                          context,
                          isBackendAgent ? '后端模型删除成功' : '本地智能体删除成功',
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
