import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_lorebook.dart';
import '../../models/ai_provider_profile.dart';
import '../../services/ai_db_service.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_provider_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../services/ai_agent_draft_factory.dart';
import '../../services/ai_prompt_defaults.dart';
import '../../services/llm_api_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_chip.dart';
import '../../widgets/ai/ai_scaffold.dart';
import '../../widgets/ai/ai_section_header.dart';
import '../../widgets/ai/ai_surface_card.dart';
import '../../widgets/ai/ai_theme.dart';
import '../../widgets/moe_action_row.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/app_message_widget.dart';
import '../../providers/loading_provider.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/motion/moe_reveal.dart';
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
  bool _createRealModel = false;
  bool _syncModelOnEdit = false;
  bool _showAdvancedFields = false;
  bool _publishToPlaza = false;
  bool _pageActive = true;

  bool get _isEphemeralDraft =>
      widget.agent != null &&
      AiAgentDraftFactory.isEphemeralId(widget.agent!.id);

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
      text: agent?.modelName ?? '',
    );
    _personaController = TextEditingController(text: agent?.persona ?? '');
    _scenarioController = TextEditingController(text: agent?.scenario ?? '');
    _openingMessageController =
        TextEditingController(text: agent?.openingMessage ?? '');
    _exampleDialoguesController =
        TextEditingController(text: agent?.exampleDialogues ?? '');
    _modelNameController.addListener(() {
      if (mounted) setState(() {});
    });
    if (agent != null) {
      _providerProfileId =
          agent.providerProfileId ?? AiProviderProfile.builtinBackendId;
      _lorebookId = agent.lorebookId;
      _publishToPlaza = agent.isPublic;
      final modelSeed = agent.modelName.trim();
      if (modelSeed.isNotEmpty) {
        _models = [modelSeed];
      }
    }
    _loadProviders();
    _loadLorebooks();
  }

  @override
  void dispose() {
    _pageActive = false;
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
    final profile = profiles.firstWhere(
      (item) => item.id == _providerProfileId,
      orElse: () => AiProviderProfile.builtinBackend(),
    );
    if (!mounted || !_pageActive) return;
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
      final selected = profiles.firstWhere(
        (item) => item.id == _providerProfileId,
        orElse: () => AiProviderProfile.builtinBackend(),
      );
      if (_models.isEmpty && selected.effectiveModelIds.isNotEmpty) {
        _models = selected.effectiveModelIds;
      }
      final bound = _modelNameController.text.trim();
      if (bound.isEmpty) {
        if (selected.defaultModel.trim().isNotEmpty) {
          _modelNameController.text = selected.defaultModel.trim();
        } else if (selected.effectiveModelIds.isNotEmpty) {
          _modelNameController.text = selected.effectiveModelIds.first;
        }
      }
    });
    unawaited(_loadModels(background: profile.isBackendOllama));
  }

  Future<void> _loadLorebooks() async {
    try {
      final lorebooks = await AiDbService().getLorebooks();
      if (!mounted || !_pageActive) return;
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
            padding: const EdgeInsets.all(MoeTokens.spaceLg),
            children: [
              const Text(
                '选择角色模板',
                style: TextStyle(
                    fontSize: MoeTokens.textLg, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              Text(
                '模板会填充角色结构，便于你继续改成自己的风格。',
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
        );
      },
    );

    if (result == null || !mounted || !_pageActive) return;
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

  Future<void> _loadModels({bool background = false}) async {
    final profile = _selectedProvider ?? AiProviderProfile.builtinBackend();
    final localIds = profile.effectiveModelIds;
    if (!background && mounted && localIds.isNotEmpty) {
      setState(() => _models = localIds);
    }

    // 中转站已配置模型 ID 时不必阻塞页面等 /models。
    if (!profile.isBackendOllama && localIds.isNotEmpty && !background) {
      return;
    }

    if (mounted && _pageActive) setState(() => _isLoadingModels = true);
    try {
      final models = await AiChatGatewayService()
          .fetchModelsForProfile(profile)
          .timeout(const Duration(seconds: 5));
      if (!mounted || !_pageActive) return;
      setState(() {
        if (models.isNotEmpty) {
          _models = models;
        } else if (localIds.isNotEmpty) {
          _models = localIds;
        }
        final current = _modelNameController.text.trim();
        if (current.isEmpty && _models.isNotEmpty) {
          _modelNameController.text = _models.first;
        }
      });
      if (_selectedProviderIsBackend &&
          widget.agent != null &&
          !background &&
          _promptController.text.trim().isEmpty &&
          _modelNameController.text.trim().isNotEmpty) {
        unawaited(_refreshPromptFromBackend(_modelNameController.text.trim()));
      }
    } catch (_) {
      if (mounted && _pageActive && _models.isEmpty && localIds.isNotEmpty) {
        setState(() => _models = localIds);
      }
    } finally {
      if (mounted && _pageActive) setState(() => _isLoadingModels = false);
    }
  }

  /// 从 Ollama /api/show 获取模型实际系统提示词
  Future<String> _fetchOllamaSystemPrompt(String modelName) =>
      LlmApiService.fetchOllamaSystemPrompt(modelName);

  Widget _buildPromptPreview(String localPrompt, String modelName) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
        color: Colors.blue.shade50.withValues(alpha: 0.4),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('prompt-preview-$modelName'),
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
                        padding: const EdgeInsets.all(MoeTokens.spaceMd),
                        decoration: BoxDecoration(
                          color: MoeTokens.cardBackground,
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusSm),
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

  String _userFacingSaveError(Object e) {
    final raw = e.toString();
    if (raw.contains('请输入')) {
      return raw.replaceFirst('Exception: ', '');
    }
    if (raw.contains('JSON') ||
        raw.contains('FormatException') ||
        raw.contains('SocketException') ||
        raw.contains('ClientException')) {
      return '保存失败，请检查网络或填写内容后重试';
    }
    const prefix = 'Exception: ';
    if (raw.startsWith(prefix)) {
      final inner = raw.substring(prefix.length);
      if (inner.length < 80 && !inner.contains('{')) return inner;
    }
    return '保存失败，请稍后重试';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_pageActive) return;
    final loadingProvider = context.read<LoadingProvider>();
    loadingProvider.setOperationLoading(LoadingKeys.saveAgent, true);
    var didPop = false;
    try {
      final isNewAgent = widget.agent == null || _isEphemeralDraft;
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      final prompt = _promptController.text.trim();
      final provider = _selectedProvider ?? AiProviderProfile.builtinBackend();

      // 身份卡：modelName 仅为聊天时传给 API 的模型 ID，与 Ollama 是否「创建模型」无关。
      final modelForChat = _modelNameController.text.trim();
      if (modelForChat.isEmpty) {
        throw Exception('请输入绑定模型 ID');
      }

      final shouldCreateOllamaModel =
          provider.isBackendOllama && isNewAgent && _createRealModel;
      final shouldSyncOllamaModel =
          provider.isBackendOllama && !isNewAgent && _syncModelOnEdit;

      final agent = AiAgent(
        id: (!isNewAgent ? widget.agent?.id : null) ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: desc,
        systemPrompt: prompt,
        modelName: modelForChat,
        providerProfileId: provider.isBackendOllama ? null : provider.id,
        lorebookId:
            (_lorebookId?.trim().isNotEmpty ?? false) ? _lorebookId : null,
        persona: _personaController.text.trim(),
        scenario: _scenarioController.text.trim(),
        openingMessage: _openingMessageController.text.trim(),
        exampleDialogues: _exampleDialoguesController.text.trim(),
        createdAt: isNewAgent
            ? DateTime.now()
            : (widget.agent?.createdAt ?? DateTime.now()),
        createdByUserId: isNewAgent ? null : widget.agent?.createdByUserId,
        isPublic: _publishToPlaza,
      );

      // 角色卡 = 账号下一条 JSON，PUT /api/ai/agents
      if (isNewAgent) {
        await AiAgentCloudService().saveAgent(agent);
      } else {
        await AiAgentCloudService().updateAgent(agent);
      }

      if (mounted && _pageActive) {
        MoeToast.success(
          context,
          isNewAgent ? '角色卡已保存' : '修改已保存',
        );
        _pageActive = false;
        didPop = true;
        Navigator.pop(context, true);
      }

      if (shouldCreateOllamaModel || shouldSyncOllamaModel) {
        unawaited(
          _postSaveOllamaSideEffects(
            agent: agent,
            shouldCreate: shouldCreateOllamaModel,
            shouldSync: shouldSyncOllamaModel,
            baseModel: modelForChat,
            prompt: prompt,
            displayName: name,
          ),
        );
      }
    } catch (e) {
      if (mounted && _pageActive) {
        MoeToast.error(context, _userFacingSaveError(e));
      }
    } finally {
      if (mounted && _pageActive && !didPop) {
        context
            .read<LoadingProvider>()
            .setOperationLoading(LoadingKeys.saveAgent, false);
      }
    }
  }

  /// 仅「内置 Ollama」且用户显式开启高级选项时，在后台同步服务器 Modelfile。
  Future<void> _postSaveOllamaSideEffects({
    required AiAgent agent,
    required bool shouldCreate,
    required bool shouldSync,
    required String baseModel,
    required String prompt,
    required String displayName,
  }) async {
    if (!shouldCreate && !shouldSync) {
      return;
    }
    var ollamaModelName = agent.modelName;
    if (shouldCreate) {
      var safeName = displayName.toLowerCase();
      safeName = safeName.replaceAll(RegExp(r'\s+'), '-');
      safeName = safeName.replaceAll(RegExp(r'[^a-z0-9_\-\.:/]'), '_');
      if (safeName.isNotEmpty) {
        ollamaModelName = safeName;
      }
    }
    try {
      await _createOrUpdateModelInOllama(
        modelName: ollamaModelName,
        baseModel: baseModel,
        prompt: prompt,
      );
    } catch (_) {}
  }

  Future<void> _createOrUpdateModelInOllama({
    required String modelName,
    required String baseModel,
    required String prompt,
  }) async {
    try {
      await LlmApiService.upsertAgentPrompt(
        name: modelName,
        baseModel: baseModel,
        systemPrompt: prompt,
      );
    } on TimeoutException {
      throw Exception('创建 Ollama 模型超时（45 秒），通常是首次拉取基础模型较慢，请稍后重试');
    }
  }

  Future<void> _refreshPromptFromBackend(String modelName) async {
    final prompt = await LlmApiService.fetchOllamaSystemPrompt(modelName);
    if (!mounted || prompt.trim().isEmpty || prompt.startsWith('（读取失败')) {
      return;
    }
    _promptController.text = prompt.trim();
  }

  Widget _buildModelChips() {
    if (_models.isEmpty) return const SizedBox.shrink();
    final selected = _modelNameController.text.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _models.map((model) {
          return AiChip(
            label: model,
            selected: model == selected,
            icon: Icons.memory_rounded,
            onTap: () => setState(() => _modelNameController.text = model),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFieldSection({
    required String title,
    required String? subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiSectionHeader(title: title, subtitle: subtitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AiTheme.pagePadding),
          child: AiSurfaceCard(
            padding: const EdgeInsets.all(AiTheme.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveBar(bool isCreate) {
    return Material(
      color: AiBrandTokens.pageBackground,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AiTheme.pagePadding,
            8,
            AiTheme.pagePadding,
            12,
          ),
          child: LoadingButton(
            operationKey: LoadingKeys.saveAgent,
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AiBrandTokens.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
              ),
            ),
            child: Text(isCreate ? '保存角色卡' : '保存修改'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.agent == null || _isEphemeralDraft;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return AiScaffold(
      title: isCreate ? '创建角色卡' : '编辑角色卡',
      subtitle: '保存到账号（服务器）',
      bottomNavigationBar: _buildSaveBar(isCreate),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: 16 + bottomInset),
          children: [
            MoeReveal(
              delay: Duration.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AiTheme.pagePadding,
                  8,
                  AiTheme.pagePadding,
                  0,
                ),
                child: AiSurfaceCard(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AiBrandTokens.primary.withValues(alpha: 0.08),
                      AiBrandTokens.secondary.withValues(alpha: 0.06),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        color: AiBrandTokens.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedProviderIsBackend
                              ? '角色卡会保存你的人设与绑定模型，并同步到你的账号。默认不会在服务器新建 Ollama 模型。'
                              : '角色卡保存人设与模型绑定；开始聊天时将使用你选择的 API 与模型。',
                          style: AiTheme.body.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            MoeReveal(
              delay: MoeTokens.motionStaggerStep,
              child: _buildFieldSection(
                title: '基础信息',
                subtitle: '名称与一句话介绍',
                children: [
                  MoeInputField(
                    controller: _nameController,
                    hintText: '角色名称',
                    style: AiTheme.title.copyWith(fontSize: 16),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '请输入名称' : null,
                  ),
                  const SizedBox(height: 12),
                  MoeInputField(
                    controller: _descController,
                    hintText: '简介',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Consumer<LoadingProvider>(
                      builder: (context, loading, _) => FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              AiBrandTokens.primary.withValues(alpha: 0.1),
                          foregroundColor: AiBrandTokens.primary,
                        ),
                        onPressed:
                            loading.isOperationLoading(LoadingKeys.saveAgent)
                                ? null
                                : _applyStarterTemplate,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('套用角色模板'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            MoeReveal(
              delay: MoeTokens.motionStaggerStep * 2,
              child: _buildFieldSection(
                title: '模型与来源',
                subtitle: '选择 API 并填写要调用的模型 ID',
                children: [
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
                          decoration:
                              AiTheme.inputDecoration(labelText: 'API 来源'),
                          items: _providerProfiles
                              .map(
                                (item) => DropdownMenuItem(
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
                            final profile = _providerProfiles.firstWhere(
                              (item) => item.id == value,
                              orElse: () => AiProviderProfile.builtinBackend(),
                            );
                            setState(() {
                              _providerProfileId = value;
                              if (!profile.isBackendOllama) {
                                _createRealModel = false;
                                _syncModelOnEdit = false;
                              }
                              _models = profile.effectiveModelIds;
                            });
                            await AiProviderService()
                                .saveLastSelectedProfileId(value);
                            unawaited(_loadModels(background: true));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: '管理 Provider',
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MoeInputField(
                    controller: _modelNameController,
                    hintText: '绑定模型 ID',
                    style: AiTheme.mono,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '请输入绑定模型 ID' : null,
                  ),
                  if (_isLoadingModels)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  AiBrandTokens.primary.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('后台刷新模型列表…', style: AiTheme.caption),
                        ],
                      ),
                    ),
                  _buildModelChips(),
                  const SizedBox(height: 12),
                  MoeActionRow(
                    icon: Icons.public_rounded,
                    title: '发布到角色卡广场',
                    subtitle: const Text('开启后，其他用户可在角色卡广场发现并使用这个角色'),
                    onTap: () =>
                        setState(() => _publishToPlaza = !_publishToPlaza),
                    showDefaultTrailing: false,
                    iconColor: AiBrandTokens.primary,
                    trailing: Switch.adaptive(
                      value: _publishToPlaza,
                      activeThumbColor: AiBrandTokens.primary,
                      onChanged: (v) => setState(() => _publishToPlaza = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _lorebooks.any((item) => item.id == _lorebookId)
                        ? _lorebookId
                        : null,
                    isExpanded: true,
                    decoration: AiTheme.inputDecoration(labelText: '世界书（可选）'),
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
                    onChanged: (value) => setState(() => _lorebookId = value),
                  ),
                ],
              ),
            ),
            MoeReveal(
              delay: MoeTokens.motionStaggerStep * 3,
              child: _buildFieldSection(
                title: '扮演设定',
                subtitle: '人设与场景决定聊天时的身份感',
                children: [
                  MoeInputField(
                    controller: _personaController,
                    hintText: '角色人设',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  MoeInputField(
                    controller: _scenarioController,
                    hintText: '场景设定',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  MoeInputField(
                    controller: _openingMessageController,
                    hintText: '开场白',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            MoeReveal(
              delay: MoeTokens.motionStaggerStep * 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AiTheme.pagePadding),
                child: AiSurfaceCard(
                  child: Column(
                    children: [
                      MoeActionRow(
                        icon: Icons.tune_rounded,
                        title: '高级选项',
                        titleStyle: AiTheme.title.copyWith(fontSize: 16),
                        subtitle: Text(
                          _selectedProviderIsBackend
                              ? '系统提示词、示例对话；可选同步到服务器模型'
                              : '系统提示词、示例对话等进阶设定',
                          style: AiTheme.caption,
                        ),
                        trailing: Icon(
                          _showAdvancedFields
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                        showDefaultTrailing: false,
                        onTap: () => setState(
                          () => _showAdvancedFields = !_showAdvancedFields,
                        ),
                      ),
                      if (_showAdvancedFields) ...[
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        if (widget.agent == null &&
                            !_isEphemeralDraft &&
                            _selectedProviderIsBackend)
                          MoeActionRow(
                            icon: Icons.precision_manufacturing_rounded,
                            title: '【可选】在服务器生成 Ollama 模型',
                            subtitle: const Text('与身份卡无关；默认关闭。仅内置 Ollama 用户需要'),
                            onTap: () => setState(
                                () => _createRealModel = !_createRealModel),
                            showDefaultTrailing: false,
                            iconColor: AiBrandTokens.primary,
                            trailing: Switch.adaptive(
                              value: _createRealModel,
                              activeThumbColor: AiBrandTokens.primary,
                              onChanged: (v) =>
                                  setState(() => _createRealModel = v),
                            ),
                          ),
                        if (widget.agent != null && _selectedProviderIsBackend)
                          MoeActionRow(
                            icon: Icons.sync_rounded,
                            title: '同步更新 Ollama 模型',
                            subtitle: const Text('保存后后台同步，不阻塞界面'),
                            onTap: () => setState(
                                () => _syncModelOnEdit = !_syncModelOnEdit),
                            showDefaultTrailing: false,
                            iconColor: AiBrandTokens.primary,
                            trailing: Switch.adaptive(
                              value: _syncModelOnEdit,
                              activeThumbColor: AiBrandTokens.primary,
                              onChanged: (v) =>
                                  setState(() => _syncModelOnEdit = v),
                            ),
                          ),
                        if (widget.agent != null &&
                            _selectedProviderIsBackend) ...[
                          _buildPromptPreview(
                            widget.agent!.systemPrompt,
                            widget.agent!.modelName,
                          ),
                          const SizedBox(height: 12),
                        ],
                        MoeInputField(
                          controller: _promptController,
                          hintText: '系统提示词',
                          maxLines: 6,
                        ),
                        const SizedBox(height: 12),
                        MoeInputField(
                          controller: _exampleDialoguesController,
                          hintText: '示例对话',
                          maxLines: 5,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
