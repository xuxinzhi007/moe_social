import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../services/llm_endpoint_config.dart';
import '../../services/ai_db_service.dart';
import '../../models/ai_agent.dart';
import 'agent_editor_page.dart';
import 'chat_page.dart';
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
  List<String> _ollamaModels = [];
  bool _isLoadingModels = false;
  Map<String, Color> _agentColors = {};
  bool _showFab = true;
  
  // 新增状态变量
  String _searchQuery = '';
  String _selectedCategory = '全部';
  String _sortBy = '创建时间';
  List<String> _categories = ['全部', '工作', '娱乐', '学习', '创意', '其他'];
  List<String> _sortOptions = ['创建时间', '名称', '使用频率'];
  Map<String, int> _usageCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAgents();
    _loadOllamaModels();
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

  Future<void> _loadOllamaModels() async {
    if (mounted) setState(() => _isLoadingModels = true);
    try {
      final uri = await LlmEndpointConfig.modelsUri();
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        List<String> list = [];
        if (data is Map && data['models'] is List) {
          final raw = data['models'] as List;
          if (raw.whereType<String>().isNotEmpty) {
            list = raw.whereType<String>().toList();
          } else {
            list = raw
                .whereType<Map>()
                .map((m) => m['name'])
                .whereType<String>()
                .toList();
          }
        }
        if (mounted) {
          setState(() {
            _ollamaModels = list;
          });
        }
      }
    } catch (_) {
      // Ignore errors
    } finally {
      if (mounted) {
        setState(() => _isLoadingModels = false);
      }
    }
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    final agents = await AiDbService().getAgents();
    
    // 为每个智能体生成随机颜色
    final colors = _generateAgentColors(agents);
    
    setState(() {
      _agents = agents;
      _agentColors = colors;
      _isLoading = false;
    });
    
    // 加载后过滤智能体
    _filterAgents();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('AI 智能体', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '我的智能体'),
            Tab(text: '智能体广场'),
          ],
          indicatorColor: const Color(0xFF7F7FD5),
          labelColor: const Color(0xFF7F7FD5),
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
      backgroundColor: const Color(0xFF7F7FD5),
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Icon(Icons.add_rounded, size: 24),
    );
  }

  Widget _buildMyAgentsList() {
    if (_isLoading) {
      return const Center(child: MoeLoading());
    }
    if (_agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF7F7FD5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text('还没有智能体', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('创建你的第一个AI智能体开始对话吧', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
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
              icon: const Icon(Icons.add_rounded),
              label: const Text('创建智能体'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F7FD5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 6,
                shadowColor: const Color(0xFF7F7FD5).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('去智能体广场看看', style: TextStyle(color: Color(0xFF7F7FD5))),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        // 搜索栏和筛选器
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // 搜索栏
              MoeSearchBar(
                hintText: '搜索智能体',
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
              
              // 分类和排序（紧凑布局）
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    // 分类选择
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                              _filterAgents();
                            });
                          }
                        },
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        style: const TextStyle(color: Color(0xFF333333), fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 排序选择
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                              _filterAgents();
                            });
                          }
                        },
                        items: _sortOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        style: const TextStyle(color: Color(0xFF333333), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 智能体列表
        Expanded(
          child: _filteredAgents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, color: Colors.grey[300], size: 48),
                      const SizedBox(height: 12),
                      Text('没有找到匹配的智能体', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedCategory = '全部';
                            _filterAgents();
                          });
                        },
                        child: const Text('清除筛选', style: TextStyle(color: Color(0xFF7F7FD5), fontSize: 12)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredAgents.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemBuilder: (context, index) {
                    final agent = _filteredAgents[index];
                    final agentColor = _agentColors[agent.id] ?? const Color(0xFF7F7FD5);
                    final usageCount = _usageCounts[agent.id] ?? 0;
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
                                        Row(
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
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '${agent.createdAt.year}-${agent.createdAt.month}-${agent.createdAt.day}',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 10,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAgentSquare() {
    if (_isLoadingModels) {
      return const Center(child: MoeLoading());
    }
    if (_ollamaModels.isEmpty) {
      return Center(
        child: Column(
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
                  BoxShadow(color: const Color(0xFF86A8E7).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.cloud_off_outlined, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text('未找到 Ollama 模型', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('请确保 Ollama 服务已启动', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadOllamaModels,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF86A8E7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                shadowColor: const Color(0xFF86A8E7).withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }
    
    // 模型分类
    final modelCategories = _categorizeModels(_ollamaModels);
    
    return ListView.builder(
      itemCount: modelCategories.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, categoryIndex) {
        final category = modelCategories.keys.elementAt(categoryIndex);
        final categoryModels = modelCategories[category]!;
        
        return FadeInUp(
          delay: Duration(milliseconds: 50 * categoryIndex),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类标题
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF86A8E7),
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
              
              // 模型列表
              Column(
                children: categoryModels.map((modelName) {
                  final existing = _agents.where((a) => a.modelName == modelName).firstOrNull;
                  final alreadyAdded = existing != null;
                  final cardColor = alreadyAdded ? const Color(0xFF4CAF50) : const Color(0xFF86A8E7);
                  
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
                          _createAgentFromModel(modelName);
                        },
                        child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // 模型图标
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
                          alreadyAdded ? Icons.check_circle_rounded : Icons.memory_rounded,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '已添加',
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cardColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    alreadyAdded ? '已创建' : 'Ollama',
                                    style: TextStyle(
                                      color: cardColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
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

  Future<void> _createAgentFromModel(String modelName) async {
    // 若同模型智能体已存在，直接进入对话，不重复创建
    final existing = _agents.where((a) => a.modelName == modelName).firstOrNull;
    if (existing != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(agent: existing)),
        );
      }
      return;
    }

    final agent = AiAgent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: modelName,
      description: '基于 $modelName 的对话',
      systemPrompt: '',
      modelName: modelName,
      createdAt: DateTime.now(),
    );
    await AiDbService().insertAgent(agent);
    await _loadAgents();

    if (mounted) {
      MoeToast.success(context, '智能体创建成功');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage(agent: agent)),
      );
    }
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
                      await AiDbService().deleteAgent(agent.id);
                      _loadAgents();
                      if (mounted) {
                        MoeToast.success(context, '智能体删除成功');
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
