import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../models/ai_agent.dart';
import '../../models/ai_lorebook.dart';
import '../../models/ai_provider_profile.dart';
import '../../services/ai_db_service.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_provider_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../services/api_service.dart';
import '../../services/ai_prompt_defaults.dart';
import '../../services/llm_endpoint_config.dart';
import '../../widgets/moe_toast.dart';
import 'ai_lorebooks_page.dart';
import 'ai_provider_profiles_page.dart';

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
  late TextEditingController _modelNameController;
  late TextEditingController _personaController;
  late TextEditingController _scenarioController;
  late TextEditingController _openingMessageController;
  late TextEditingController _exampleDialoguesController;
  List<String> _models = [];
  List<AiProviderProfile> _providerProfiles = [
    AiProviderProfile.builtinBackend(),
  ];
  List<AiLorebook> _lorebooks = [];
  String _providerProfileId = AiProviderProfile.builtinBackendId;
  String? _lorebookId;
  bool _isLoadingModels = false;
  bool _isSaving = false;
  bool _createRealModel = true;
  bool _syncModelOnEdit = true;

  bool get _isTemplateDraft =>
      (widget.agent?.id.startsWith('template_') ?? false);

  AiProviderProfile? get _selectedProvider {
    for (final item in _providerProfiles) {
      if (item.id == _providerProfileId) return item;
    }
    return AiProviderProfile.builtinBackend();
  }

  bool get _selectedProviderIsBackend =>
      (_selectedProvider ?? AiProviderProfile.builtinBackend()).isBackendOllama;

  @override
  void initState() {
    super.initState();
    final agent = widget.agent;
    final initialPrompt = (agent?.systemPrompt ?? '').trim().isEmpty
        ? AiPromptDefaults.defaultAgentSystemPrompt
        : (agent!.systemPrompt);
    _nameController = TextEditingController(text: agent?.name ?? '');
    _descController = TextEditingController(text: agent?.description ?? '');
    _promptController = TextEditingController(
      text: initialPrompt,
    );
    _modelNameController = TextEditingController(
      text: agent?.modelName ?? 'llama3:8b',
    );
    _personaController = TextEditingController(text: agent?.persona ?? '');
    _scenarioController = TextEditingController(text: agent?.scenario ?? '');
    _openingMessageController =
        TextEditingController(text: agent?.openingMessage ?? '');
    _exampleDialoguesController =
        TextEditingController(text: agent?.exampleDialogues ?? '');
    if (agent != null) {
      _providerProfileId =
          agent.providerProfileId ?? AiProviderProfile.builtinBackendId;
      _lorebookId = agent.lorebookId;
    }
    _loadProviders();
    _loadLorebooks();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    _modelNameController.dispose();
    _personaController.dispose();
    _scenarioController.dispose();
    _openingMessageController.dispose();
    _exampleDialoguesController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    final profiles = await AiProviderService().listProfiles();
    final lastSelected = await AiProviderService().readLastSelectedProfileId();
    if (!mounted) return;
    setState(() {
      _providerProfiles = profiles;
      if (widget.agent == null &&
          lastSelected != null &&
          profiles.any((item) => item.id == lastSelected)) {
        _providerProfileId = lastSelected;
      }
      final exists = profiles.any((item) => item.id == _providerProfileId);
      if (!exists) {
        _providerProfileId = AiProviderProfile.builtinBackendId;
      }
    });
    await _loadModels();
  }

  Future<void> _loadLorebooks() async {
    try {
      final lorebooks = await AiDbService().getLorebooks();
      if (!mounted) return;
      setState(() {
        _lorebooks = lorebooks;
        final exists = lorebooks.any((item) => item.id == _lorebookId);
        if (!exists) {
          _lorebookId = null;
        }
      });
    } catch (_) {
      // Ignore local lorebook errors for now.
    }
  }

  Future<void> _applyStarterTemplate() async {
    final result = await showModalBottomSheet<AiStarterAgentTemplate>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '选择角色模板',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '模板会填充角色结构，便于你继续改成自己的风格。',
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
        );
      },
    );

    if (result == null) return;
    setState(() {
      _nameController.text = result.name;
      _descController.text = result.description;
      _promptController.text = result.systemPrompt;
      _personaController.text = result.persona;
      _scenarioController.text = result.scenario;
      _openingMessageController.text = result.openingMessage;
      _exampleDialoguesController.text = result.exampleDialogues;
    });
  }

  Future<void> _loadModels() async {
    setState(() => _isLoadingModels = true);
    try {
      final profile =
          _selectedProvider ?? AiProviderProfile.builtinBackend();
      final models = await AiChatGatewayService().fetchModelsForProfile(profile);
      if (!mounted) return;
      setState(() {
        _models = models;
        if (_modelNameController.text.trim().isEmpty && _models.isNotEmpty) {
          _modelNameController.text = _models.first;
        }
        if (_models.isNotEmpty &&
            !_models.contains(_modelNameController.text.trim()) &&
            profile.isBackendOllama) {
          _modelNameController.text = _models.first;
        }
      });
      if (_selectedProviderIsBackend &&
          widget.agent != null &&
          _promptController.text.trim().isEmpty &&
          _modelNameController.text.trim().isNotEmpty) {
        _refreshPromptFromBackend(_modelNameController.text.trim());
      }
    } catch (_) {
      // Ignore errors, use default or current
    } finally {
      if (mounted) setState(() => _isLoadingModels = false);
    }
  }

  /// 从 Ollama /api/show 获取模型实际系统提示词
  Future<String> _fetchOllamaSystemPrompt(String modelName) async {
    try {
      final uri = LlmEndpointConfig.showUri();
      ApiService.logDirectHttp('POST', uri);
      final token = ApiService.token;
      final headers = ApiService.mergeTunnelHeaders(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
      final response = await http
          .post(uri, headers: headers, body: jsonEncode({'name': modelName}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // 新版 Ollama 直接返回 system 字段
        if (data is Map &&
            data['system'] is String &&
            (data['system'] as String).isNotEmpty) {
          return data['system'] as String;
        }
        // 旧版从 modelfile 解析 SYSTEM 指令
        if (data is Map && data['modelfile'] is String) {
          final mf = data['modelfile'] as String;
          final tripleMatch =
              RegExp(r'SYSTEM\s+"""([\s\S]*?)"""', multiLine: true)
                  .firstMatch(mf);
          if (tripleMatch != null) return tripleMatch.group(1)?.trim() ?? '';
          final singleMatch = RegExp(r'SYSTEM\s+"(.*?)"').firstMatch(mf);
          if (singleMatch != null) return singleMatch.group(1)?.trim() ?? '';
        }
        return '';
      }
      return '（读取失败：HTTP ${response.statusCode}）';
    } catch (e) {
      return '（读取失败：$e）';
    }
  }

  Widget _buildPromptPreview(String localPrompt, String modelName) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50.withOpacity(0.4),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(Icons.visibility_outlined,
              size: 18, color: Colors.blueGrey),
          title: const Text(
            '查看当前提示词（含 Ollama 模型内置）',
            style: TextStyle(
                fontSize: 13,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w500),
          ),
          children: [
            FutureBuilder<String>(
              future: _fetchOllamaSystemPrompt(modelName),
              builder: (ctx, snap) {
                final ollamaPrompt = snap.data;
                final effectivePrompt =
                    (ollamaPrompt != null && ollamaPrompt.isNotEmpty)
                        ? ollamaPrompt
                        : localPrompt;
                final isLoading =
                    snap.connectionState == ConnectionState.waiting;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('正在从 Ollama 读取...',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    else ...[
                      if (ollamaPrompt != null && ollamaPrompt.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 13, color: Colors.green),
                              const SizedBox(width: 4),
                              Text('来自 Ollama Modelfile',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: effectivePrompt.isEmpty
                            ? Text(
                                '暂未设置提示词',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13),
                              )
                            : SelectableText(
                                effectivePrompt,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: Colors.black87),
                              ),
                      ),
                      if (effectivePrompt.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            icon: const Icon(Icons.copy_rounded, size: 13),
                            label: const Text('复制',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: effectivePrompt));
                              if (!ctx.mounted) return;
                              MoeToast.success(ctx, '提示词已复制');
                            },
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final isNewAgent = widget.agent == null || _isTemplateDraft;
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      final prompt = _promptController.text.trim();
      final provider =
          _selectedProvider ?? AiProviderProfile.builtinBackend();

      String modelForChat = _modelNameController.text.trim();
      String resolvedPromptForLocal = prompt;

      final shouldCreateNew =
          provider.isBackendOllama && isNewAgent && _createRealModel;
      final shouldSyncEdit =
          provider.isBackendOllama && !isNewAgent && _syncModelOnEdit;
      if (shouldCreateNew || shouldSyncEdit) {
        final baseModel = _modelNameController.text.trim();
        if (baseModel.isEmpty) {
          throw Exception('请选择基础模型');
        }

        if (shouldCreateNew) {
          String safeName = name.toLowerCase();
          safeName = safeName.replaceAll(RegExp(r'\s+'), '-');
          safeName = safeName.replaceAll(RegExp(r'[^a-z0-9_\-\.:/]'), '_');
          if (safeName.isEmpty) {
            throw Exception('无效的模型名称');
          }
          modelForChat = safeName;
        } else {
          modelForChat = widget.agent!.modelName;
        }

        await _createOrUpdateModelInOllama(
          modelName: modelForChat,
          baseModel: baseModel,
          prompt: prompt,
        );

        if (resolvedPromptForLocal.isEmpty) {
          final backendPrompt =
              await _fetchSystemPromptFromBackend(modelForChat);
          if (backendPrompt != null && backendPrompt.trim().isNotEmpty) {
            resolvedPromptForLocal = backendPrompt.trim();
          }
        }
      }

      if (modelForChat.isEmpty) {
        throw Exception('请输入模型 ID');
      }

      final agent = AiAgent(
        id: (!isNewAgent ? widget.agent?.id : null) ??
            (shouldCreateNew
                ? modelForChat
                : DateTime.now().millisecondsSinceEpoch.toString()),
        name: name,
        description: desc,
        systemPrompt: resolvedPromptForLocal,
        modelName: modelForChat,
        providerProfileId:
            provider.isBuiltinBackend ? null : provider.id,
        lorebookId: (_lorebookId?.trim().isNotEmpty ?? false) ? _lorebookId : null,
        persona: _personaController.text.trim(),
        scenario: _scenarioController.text.trim(),
        openingMessage: _openingMessageController.text.trim(),
        exampleDialogues: _exampleDialoguesController.text.trim(),
        createdAt: isNewAgent ? DateTime.now() : (widget.agent?.createdAt ?? DateTime.now()),
      );

      // 本地库只作为补充元数据存储；写入失败不阻塞“后端模型”流程。
      try {
        if (isNewAgent) {
          await AiDbService().insertAgent(agent);
        } else {
          await AiDbService().updateAgent(agent);
        }
        if (isNewAgent) {
          await AiAgentCloudService().saveAgent(agent);
        } else {
          await AiAgentCloudService().updateAgent(agent);
        }
      } catch (_) {}

      if (mounted) {
        MoeToast.success(
          context,
          isNewAgent
              ? '智能体创建成功'
              : (_selectedProviderIsBackend && _syncModelOnEdit
                  ? '智能体已保存并同步模型'
                  : '智能体已保存'),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createOrUpdateModelInOllama({
    required String modelName,
    required String baseModel,
    required String prompt,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/llm/agents');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = ApiService.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final body = jsonEncode({
      'name': modelName,
      'base_model': baseModel,
      'system_prompt': prompt,
    });

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('创建/更新 Ollama 模型失败: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final success = data is Map && (data['success'] == true);
    if (!success) {
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : '创建/更新 Ollama 模型失败';
      throw Exception(msg);
    }
  }

  Future<void> _refreshPromptFromBackend(String modelName) async {
    final prompt = await _fetchSystemPromptFromBackend(modelName);
    if (!mounted || prompt == null || prompt.trim().isEmpty) return;
    _promptController.text = prompt.trim();
  }

  Future<String?> _fetchSystemPromptFromBackend(String modelName) async {
    try {
      final uri = LlmEndpointConfig.showUri();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        ...ApiService.mergeTunnelHeaders(uri),
      };
      final token = ApiService.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final resp = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'name': modelName}),
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map) return null;
      final directSystem = data['system'];
      if (directSystem is String && directSystem.trim().isNotEmpty) {
        return directSystem;
      }
      final modelfile = data['modelfile'];
      if (modelfile is! String || modelfile.trim().isEmpty) return null;
      return _extractSystemPromptFromModelfile(modelfile);
    } catch (_) {
      return null;
    }
  }

  String? _extractSystemPromptFromModelfile(String modelfile) {
    final triple = RegExp(
      r'SYSTEM\s+"""([\s\S]*?)"""',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(modelfile);
    if (triple != null) {
      return triple.group(1)?.trim();
    }
    final single = RegExp(
      r'^SYSTEM\s+"(.*)"$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(modelfile);
    if (single != null) {
      return single.group(1)?.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((widget.agent == null || _isTemplateDraft) ? '创建智能体' : '编辑智能体'),
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
            FilledButton.tonalIcon(
              onPressed: _isSaving ? null : _applyStarterTemplate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('套用默认角色模板'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _providerProfiles.any(
                      (item) => item.id == _providerProfileId,
                    )
                        ? _providerProfileId
                        : AiProviderProfile.builtinBackendId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                    ),
                    items: _providerProfiles
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _providerProfileId = value);
                      await AiProviderService().saveLastSelectedProfileId(value);
                      await _loadModels();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiProviderProfilesPage(),
                      ),
                    );
                    await _loadProviders();
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('管理'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _lorebooks.any((item) => item.id == _lorebookId)
                        ? _lorebookId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lorebook',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('不绑定世界书'),
                      ),
                      ..._lorebooks.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _lorebookId = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiLorebooksPage(),
                      ),
                    );
                    await _loadLorebooks();
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('管理'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.agent == null && _selectedProviderIsBackend)
              SwitchListTile(
                title: const Text('在 Ollama 中创建真实模型'),
                subtitle: const Text('使用上面的基础模型和系统提示词创建可复用模型'),
                value: _createRealModel,
                onChanged: (v) {
                  setState(() => _createRealModel = v);
                },
              ),
            if (widget.agent != null && _selectedProviderIsBackend)
              SwitchListTile(
                title: const Text('同步更新到 Ollama 模型'),
                subtitle: const Text('关闭后仅修改本地展示，开启后会重建模型使新提示词生效'),
                value: _syncModelOnEdit,
                onChanged: (v) {
                  setState(() => _syncModelOnEdit = v);
                },
              ),
            if (widget.agent == null) const SizedBox(height: 16),
            if (widget.agent != null) const SizedBox(height: 16),
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
              value: _models.contains(_modelNameController.text.trim())
                  ? _modelNameController.text.trim()
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '模型列表',
                border: OutlineInputBorder(),
              ),
              items: _models.isEmpty
                  ? [
                      DropdownMenuItem(
                        value: _modelNameController.text.trim(),
                        child: Text(
                          _modelNameController.text.trim().isEmpty
                              ? '暂无可用模型'
                              : _modelNameController.text.trim(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ]
                  : _models.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(m, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _modelNameController.text = v);
                }
              },
            ),
            if (_isLoadingModels)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('正在加载模型列表...',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelNameController,
              decoration: const InputDecoration(
                labelText: '模型 ID',
                hintText: '可手动输入模型，例如 gpt-4o-mini / deepseek-chat',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入模型 ID' : null,
            ),
            const SizedBox(height: 16),
            if (widget.agent != null && _selectedProviderIsBackend) ...[
              _buildPromptPreview(
                widget.agent!.systemPrompt,
                widget.agent!.modelName,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _promptController,
              maxLines: 8,
              decoration: InputDecoration(
                labelText:
                    widget.agent != null ? '修改系统提示词' : '系统提示词 (System Prompt)',
                hintText: '设定智能体的人设、语气、擅长领域等...',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _personaController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '角色人设',
                hintText: '例如：温柔冷静的图书管理员，喜欢细致回答问题',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _scenarioController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '场景设定',
                hintText: '例如：你和用户正在深夜咖啡馆中聊天',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _openingMessageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '开场白',
                hintText: '新会话开始时自动发送的第一句 assistant 消息',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _exampleDialoguesController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '示例对话',
                hintText: '用于约束角色语气与风格，可写多轮示例',
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
