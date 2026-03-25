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

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});

  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AiAgent> _agents = [];
  bool _isLoading = true;
  List<String> _ollamaModels = [];
  bool _isLoadingModels = false;
  Map<String, Color> _agentColors = {};
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAgents();
    _loadOllamaModels();
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
    return ListView.builder(
      itemCount: _agents.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final agent = _agents[index];
        final agentColor = _agentColors[agent.id] ?? const Color(0xFF7F7FD5);
        return FadeInUp(
          delay: Duration(milliseconds: 30 * (index % 8)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: agentColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(agent: agent),
                    ),
                  );
                },
                onLongPress: () => _showAgentOptions(agent),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 智能体头像
                      Container(
                        width: 64,
                        height: 64,
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
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.smart_toy_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agent.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              agent.description,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: agentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    agent.modelName,
                                    style: TextStyle(
                                      color: agentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '创建于 ${agent.createdAt.year}-${agent.createdAt.month}-${agent.createdAt.day}',
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
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    return ListView.builder(
      itemCount: _ollamaModels.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final modelName = _ollamaModels[index];
        final existing = _agents.where((a) => a.modelName == modelName).firstOrNull;
        final alreadyAdded = existing != null;
        final cardColor = alreadyAdded ? const Color(0xFF4CAF50) : const Color(0xFF86A8E7);
        
        return FadeInUp(
          delay: Duration(milliseconds: 30 * (index % 8)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: cardColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _createAgentFromModel(modelName);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 模型图标
                      Container(
                        width: 64,
                        height: 64,
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
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          alreadyAdded ? Icons.check_circle_rounded : Icons.memory_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              modelName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alreadyAdded ? '已添加 · 点击进入对话' : 'Ollama 原生模型',
                              style: TextStyle(
                                color: cardColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '基于 ${modelName.split(':').first} 模型',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        alreadyAdded
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.add_circle_outline_rounded,
                        color: cardColor,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
