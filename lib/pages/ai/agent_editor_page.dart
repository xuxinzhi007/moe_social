import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_provider_profile.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_provider_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../services/ai_agent_draft_factory.dart';
import '../../services/ai_prompt_defaults.dart';
import '../../services/llm_api_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_scaffold.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/app_message_widget.dart';
import '../../providers/loading_provider.dart';
import '../../widgets/motion/moe_reveal.dart';

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
  List<AiProviderProfile> _providerProfiles = [
    AiProviderProfile.builtinBackend(),
  ];
  String _providerProfileId = AiProviderProfile.builtinBackendId;
  String? _lorebookId;
  final bool _createRealModel = false;
  final bool _syncModelOnEdit = false;
  bool _publishToPlaza = false;
  int _facet = 0;
  String? _templateId;
  int _cardPop = 0;
  final FocusNode _writingFocus = FocusNode();
  bool _pageActive = true;
  bool _supportsModelManagement = false;
  final String _newAgentId = LlmApiService.newRequestId();

  bool get _isEphemeralDraft =>
      widget.agent != null &&
      AiAgentDraftFactory.isEphemeralId(widget.agent!.id);

  AiProviderProfile? get _selectedProvider {
    for (final item in _providerProfiles) {
      if (item.id == _providerProfileId) return item;
    }
    return AiProviderProfile.builtinBackend();
  }

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
    _writingFocus.addListener(() {
      if (mounted) setState(() {});
    });
    if (agent != null) {
      _providerProfileId =
          agent.providerProfileId ?? AiProviderProfile.builtinBackendId;
      _lorebookId = agent.lorebookId;
      _publishToPlaza = agent.isPublic;
    }
    _loadProviders();
    _loadModelCapabilities();
  }

  Future<void> _loadModelCapabilities() async {
    try {
      final config = await LlmApiService.getInferenceConfig();
      if (!mounted) return;
      setState(() => _supportsModelManagement =
          config['supports_model_management'] == true);
    } catch (_) {
      // 能力未知时只允许保存卡，不猜测服务器支持模型写操作。
    }
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
    _writingFocus.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    late final List<AiProviderProfile> profiles;
    try {
      profiles = await AiProviderService().listProfiles();
    } catch (_) {
      return;
    }
    if (!mounted || !_pageActive) return;
    setState(() {
      _providerProfiles = profiles;
      final exists = profiles.any((item) => item.id == _providerProfileId);
      if (!exists) {
        _providerProfileId = AiProviderProfile.builtinBackendId;
      }
    });
  }

  void _fillTemplate(AiStarterAgentTemplate result) {
    setState(() {
      _templateId = result.id;
      _cardPop += 1;
      _facet = 0;
      _nameController.text = result.name;
      _descController.text = result.description;
      _promptController.text = result.systemPrompt;
      _personaController.text = result.persona;
      _scenarioController.text = result.scenario;
      _openingMessageController.text = result.openingMessage;
      _exampleDialoguesController.text = result.exampleDialogues;
    });
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
    try {
      final isNewAgent = widget.agent == null || _isEphemeralDraft;
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      final prompt = _promptController.text.trim();
      final provider = _selectedProvider ?? AiProviderProfile.builtinBackend();

      // 新建卡不记模型。旧卡上已有的模型名原样留着，真正绑定发生在广场「使用」。
      final modelForChat = isNewAgent ? '' : _modelNameController.text.trim();

      final shouldCreateOllamaModel =
          provider.isBackendOllama && isNewAgent && _createRealModel;
      final shouldSyncOllamaModel =
          provider.isBackendOllama && !isNewAgent && _syncModelOnEdit;

      final agent = AiAgent(
        id: (!isNewAgent ? widget.agent?.id : null) ?? _newAgentId,
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

      String? syncError;
      LlmManagedModel? syncResult;
      if (shouldCreateOllamaModel || shouldSyncOllamaModel) {
        try {
          syncResult = await _syncSavedAgent(agent);
          if (!syncResult.isReady || !syncResult.bindingApplied) {
            syncError = syncResult.outcomeMessage;
          }
          // 绑定由服务器 CAS 完成；只重读，绝不把刚保存的旧卡再 PUT 回去。
          await AiAgentCloudService().syncAgentsFromCloud();
        } catch (e) {
          syncError = e.toString();
        }
      }

      if (mounted && _pageActive) {
        if (syncError != null) {
          MoeToast.error(context, '身份卡已保存；$syncError');
        } else {
          MoeToast.success(
            context,
            syncResult?.outcomeMessage ?? (isNewAgent ? '身份卡已保存' : '修改已保存'),
          );
        }
        _pageActive = false;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted && _pageActive) {
        MoeToast.error(context, _userFacingSaveError(e));
      }
    } finally {
      loadingProvider.setOperationLoading(LoadingKeys.saveAgent, false);
    }
  }

  Future<LlmManagedModel> _syncSavedAgent(AiAgent agent) async {
    if (!_supportsModelManagement) throw Exception('后端暂不支持本人模型管理');
    final models = await LlmApiService.listManagedModels();
    LlmManagedModel? managed;
    for (final model in models) {
      if (model.agentId == agent.id) managed = model;
    }
    if (managed?.isUnresolved == true) return managed!;
    // 同步本人模型时用记录中的基座；显式另选模型时用所选基座。
    final baseModel = managed != null && agent.modelName == managed.modelName
        ? managed.baseModel
        : agent.modelName;
    return LlmApiService.upsertAgentPrompt(
      agentId: agent.id,
      // 每次用户主动同步都是新意图：复用旧 ID 会被服务端判成幂等重放或 409。
      // 未决操作在上面已提前返回，所以新 ID 不会造成重复写入。
      requestId: LlmApiService.newRequestId(),
      baseModel: baseModel,
      systemPrompt: agent.systemPrompt,
    );
  }

  static const _facets = [
    (label: '人设', hint: '这个角色是什么样的人'),
    (label: '场景', hint: '现在处在什么场合'),
    (label: '开场', hint: '见面第一句'),
    (label: '提示词', hint: '真正交给模型的说法'),
    (label: '示例', hint: '一两段示范对话'),
  ];

  TextEditingController get _facetController {
    return switch (_facet) {
      0 => _personaController,
      1 => _scenarioController,
      2 => _openingMessageController,
      3 => _promptController,
      _ => _exampleDialoguesController,
    };
  }

  Duration _motion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MoeTokens.motionFast;
  }

  Widget _tinyChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return MoePressable(
      onTap: onTap,
      pressedScale: MoeTokens.motionPressScaleStrong,
      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      child: AnimatedContainer(
        duration: _motion(context),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? MoeTokens.primary.withValues(alpha: 0.12)
              : MoeTokens.softChipBg,
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: MoeTokens.primary),
              const SizedBox(width: 3),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: MoeTokens.textXs,
                  fontWeight: FontWeight.w700,
                  color: selected ? MoeTokens.primary : MoeTokens.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: MoeTokens.textXs,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: MoeTokens.inkMuted,
        ),
      ),
    );
  }

  InputDecoration _insetField(String hint, {bool emphasize = false}) {
    return MoeFieldDecoration.decorate(
      hintText: hint,
      emphasize: emphasize,
    );
  }

  Widget _buildStudioCard() {
    final card = Container(
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        boxShadow: MoeTokens.shadowCard(),
        border: Border.all(color: MoeTokens.primary.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '身份',
                style: TextStyle(
                  fontSize: MoeTokens.textXs,
                  fontWeight: FontWeight.w700,
                  color: MoeTokens.primary.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              _tinyChip(
                label: _publishToPlaza ? '广场可见' : '仅自己',
                icon: _publishToPlaza
                    ? Icons.public_rounded
                    : Icons.lock_outline_rounded,
                selected: _publishToPlaza,
                onTap: () => setState(() => _publishToPlaza = !_publishToPlaza),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _nameMark(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(
                        fontSize: MoeTokens.textMd,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: MoeTokens.titleText,
                      ),
                      decoration: _insetField('角色名字', emphasize: true),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? '写一个名字'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      minLines: 1,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: MoeTokens.textSm,
                        height: 1.35,
                        color: MoeTokens.inkMuted,
                      ),
                      decoration: _insetField('一句话介绍'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ListenableBuilder(
            listenable: _openingMessageController,
            builder: (context, _) {
              final line = _openingMessageController.text.trim();
              return AnimatedSize(
                duration: _motion(context) == Duration.zero
                    ? Duration.zero
                    : MoeTokens.motionMedium,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: line.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: MoeTokens.softChipBg,
                            borderRadius:
                                BorderRadius.circular(MoeTokens.radiusMd),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.format_quote_rounded,
                                  size: 14,
                                  color: MoeTokens.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    line,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: MoeTokens.textXs,
                                      height: 1.35,
                                      color: MoeTokens.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceLg,
        MoeTokens.spaceSm,
        MoeTokens.spaceLg,
        0,
      ),
      child: _cardPop == 0
          ? card
          : TweenAnimationBuilder<double>(
              key: ValueKey(_cardPop),
              tween: Tween(begin: 0.96, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : MoeTokens.motionMedium,
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: card,
            ),
    );
  }

  Widget _nameMark() {
    return ListenableBuilder(
      listenable: _nameController,
      builder: (context, _) {
        final name = _nameController.text.trim();
        final letter = name.isEmpty ? '卡' : name.substring(0, 1);
        return Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MoeTokens.surface1,
            boxShadow: MoeTokens.shadowSm(),
            border: Border.all(
              color: MoeTokens.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: MoeTokens.gradientSoft,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: _motion(context),
              child: Text(
                letter,
                key: ValueKey(letter),
                style: const TextStyle(
                  fontSize: MoeTokens.textXl,
                  fontWeight: FontWeight.w800,
                  color: MoeTokens.inkDark,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplateStrip() {
    final templates = AiStarterTemplates.agentTemplates;
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: MoeTokens.spaceSm),
        itemBuilder: (context, index) {
          final template = templates[index];
          final selected = _templateId == template.id;
          return Align(
            alignment: Alignment.center,
            child: MoePressable(
              onTap: () => _fillTemplate(template),
              pressedScale: MoeTokens.motionPressScaleStrong,
              borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
              child: AnimatedScale(
                scale: selected ? 1 : 0.97,
                duration: _motion(context),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: _motion(context),
                  curve: Curves.easeOutCubic,
                  width: 124,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? MoeTokens.primary.withValues(alpha: 0.10)
                        : MoeTokens.surface1,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                    boxShadow: MoeTokens.shadowSm(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        template.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: MoeTokens.textSm,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? MoeTokens.primary
                              : MoeTokens.titleText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        template.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: MoeTokens.textXs,
                          color: MoeTokens.hintText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFacetEditor() {
    final facet = _facets[_facet];
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MoeTokens.motionMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < _facets.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  _tinyChip(
                    label: _facets[index].label,
                    selected: _facet == index,
                    onTap: () => setState(() => _facet = index),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: MoeTokens.spaceSm),
          AnimatedContainer(
            duration: motion,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: MoeTokens.surface1,
              borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
              border: Border.all(
                color: _writingFocus.hasFocus
                    ? MoeTokens.primary.withValues(alpha: 0.55)
                    : MoeTokens.lineSoft,
                width: _writingFocus.hasFocus ? 1.4 : 1,
              ),
              boxShadow: _writingFocus.hasFocus
                  ? MoeTokens.shadowSm()
                  : const <BoxShadow>[],
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: MoeTokens.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: motion,
                      child: Text(
                        facet.label,
                        key: ValueKey(facet.label),
                        style: const TextStyle(
                          fontSize: MoeTokens.textSm,
                          fontWeight: FontWeight.w700,
                          color: MoeTokens.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        facet.hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: MoeTokens.textXs,
                          color: MoeTokens.hintText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  focusNode: _writingFocus,
                  controller: _facetController,
                  minLines: 4,
                  maxLines: 6,
                  style: const TextStyle(
                    fontSize: MoeTokens.textSm,
                    height: 1.5,
                    color: MoeTokens.titleText,
                  ),
                  decoration: _insetField('写在这里'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(bool isCreate) {
    return Material(
      color: MoeTokens.pageBackground.withValues(alpha: 0.92),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MoeTokens.spaceLg,
            8,
            MoeTokens.spaceLg,
            10,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: MoeTokens.gradientPrimary,
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              boxShadow: MoeTokens.shadowSm(),
            ),
            child: LoadingButton(
              operationKey: LoadingKeys.saveAgent,
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                textStyle: const TextStyle(
                  fontSize: MoeTokens.textSm,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(isCreate ? '保存身份卡' : '保存修改'),
            ),
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
      title: isCreate ? '创建身份卡' : '编辑身份卡',
      subtitle: '人设写在这张卡上',
      bottomNavigationBar: _buildSaveBar(isCreate),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: 20 + bottomInset),
          children: [
            MoeReveal(delay: Duration.zero, child: _buildStudioCard()),
            const SizedBox(height: MoeTokens.spaceMd),
            MoeReveal(
              delay: MoeTokens.motionStaggerStep,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('模板'),
                  const SizedBox(height: 6),
                  _buildTemplateStrip(),
                ],
              ),
            ),
            const SizedBox(height: MoeTokens.spaceMd),
            MoeReveal(
              delay: MoeTokens.motionStaggerStep * 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('写法'),
                  const SizedBox(height: 6),
                  _buildFacetEditor(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
