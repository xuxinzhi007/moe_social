import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/llm_endpoint_config.dart';
import '../../services/ai_db_service.dart';
import '../../models/ai_agent.dart';
import 'agent_editor_page.dart';
import 'chat_page.dart';

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
    setState(() {
      _agents = agents;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 智能体'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '我的智能体'),
            Tab(text: '智能体广场'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AgentEditorPage()),
              );
              if (result == true) {
                _loadAgents();
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyAgentsList(),
          _buildAgentSquare(),
        ],
      ),
    );
  }

  Widget _buildMyAgentsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('还没有智能体', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('去广场看看'),
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
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
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
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 32,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            agent.modelName,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgentSquare() {
    if (_isLoadingModels) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ollamaModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('未找到 Ollama 模型', style: TextStyle(color: Colors.grey)),
            const Text('请确保 Ollama 服务已启动', style: TextStyle(color: Colors.grey, fontSize: 12)),
            TextButton(
              onPressed: _loadOllamaModels,
              child: const Text('重试'),
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
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _createAgentFromModel(modelName),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: alreadyAdded
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      alreadyAdded ? Icons.check_circle_rounded : Icons.memory_rounded,
                      color: alreadyAdded ? Colors.green : Colors.blue,
                      size: 32,
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
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alreadyAdded ? '已添加 · 点击进入对话' : 'Ollama 原生模型',
                          style: TextStyle(
                            color: alreadyAdded ? Colors.green.shade600 : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    alreadyAdded
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.add_circle_outline_rounded,
                    color: alreadyAdded ? Colors.green : Colors.blue,
                  ),
                ],
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage(agent: agent)),
      );
    }
  }

  void _showAgentOptions(AiAgent agent) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('编辑智能体'),
                onTap: () async {
                  Navigator.pop(context);
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
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('删除智能体', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('确认删除'),
                      content: Text('确定要删除智能体 "${agent.name}" 吗？所有相关聊天记录也将被删除。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('删除', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await AiDbService().deleteAgent(agent.id);
                    _loadAgents();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
