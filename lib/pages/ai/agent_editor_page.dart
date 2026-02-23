import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/ai_agent.dart';
import '../../services/ai_db_service.dart';
import '../../services/api_service.dart';
import '../../services/llm_endpoint_config.dart';

class AgentEditorPage extends StatefulWidget {
  final AiAgent? agent;

  const AgentEditorPage({super.key, this.agent});

  @override
  State<AgentEditorPage> createState() => _AgentEditorPageState();
}

class _AgentEditorPageState extends State<AgentEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _promptController;
  String _modelName = 'qwen2.5:0.5b-instruct';
  List<String> _models = [];
  bool _isLoadingModels = false;
  bool _isSaving = false;
  bool _createRealModel = false;

  @override
  void initState() {
    super.initState();
    final agent = widget.agent;
    _nameController = TextEditingController(text: agent?.name ?? '');
    _descController = TextEditingController(text: agent?.description ?? '');
    _promptController = TextEditingController(text: agent?.systemPrompt ?? '');
    if (agent != null) {
      _modelName = agent.modelName;
    }
    _loadModels();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoadingModels = true);
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
        if (list.isNotEmpty) {
          setState(() {
            _models = list;
            if (!_models.contains(_modelName)) {
              _modelName = _models.first;
            }
          });
        }
      }
    } catch (_) {
      // Ignore errors, use default or current
    } finally {
      setState(() => _isLoadingModels = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final prompt = _promptController.text.trim();

    String modelForChat = _modelName;

    if (widget.agent == null && _createRealModel) {
      try {
        final baseModel = _modelName.trim();
        if (baseModel.isEmpty) {
          throw Exception('请选择基础模型');
        }

        String safeName = name.toLowerCase();
        safeName = safeName.replaceAll(RegExp(r'\s+'), '-');
        safeName = safeName.replaceAll(RegExp(r'[^a-z0-9_\-\.:/]'), '_');
        if (safeName.isEmpty) {
          throw Exception('无效的模型名称');
        }

        final uri = Uri.parse('${ApiService.baseUrl}/api/llm/agents');
        final headers = <String, String>{
          'Content-Type': 'application/json',
        };
        final token = ApiService.token;
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        final body = jsonEncode({
          'name': safeName,
          'base_model': baseModel,
          'system_prompt': prompt,
        });

        final response = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(minutes: 5));

        if (response.statusCode != 200) {
          throw Exception('创建 Ollama 模型失败: ${response.statusCode}');
        }

        final data = jsonDecode(response.body);
        final success = data is Map && (data['success'] == true);
        if (!success) {
          final msg = data is Map && data['message'] is String
              ? data['message'] as String
              : '创建 Ollama 模型失败';
          throw Exception(msg);
        }

        modelForChat = safeName;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
    }

    final agent = AiAgent(
      id: widget.agent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: desc,
      systemPrompt: prompt,
      modelName: modelForChat,
      createdAt: widget.agent?.createdAt ?? DateTime.now(),
    );

    if (widget.agent == null) {
      await AiDbService().insertAgent(agent);
    } else {
      await AiDbService().updateAgent(agent);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.agent == null ? '创建智能体' : '编辑智能体'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：代码助手',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            if (widget.agent == null)
              SwitchListTile(
                title: const Text('在 Ollama 中创建真实模型'),
                subtitle: const Text('使用上面的基础模型和系统提示词创建可复用模型'),
                value: _createRealModel,
                onChanged: (v) {
                  setState(() => _createRealModel = v);
                },
              ),
            if (widget.agent == null) const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '简短描述这个智能体的用途',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _modelName,
              decoration: const InputDecoration(
                labelText: '模型',
                border: OutlineInputBorder(),
              ),
              items: _models.isEmpty
                  ? [
                      DropdownMenuItem(
                          value: _modelName, child: Text(_modelName))
                    ]
                  : _models.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _modelName = v);
              },
            ),
            if (_isLoadingModels)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('正在加载模型列表...', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _promptController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '系统提示词 (System Prompt)',
                hintText: '设定智能体的人设、语气、擅长领域等...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
