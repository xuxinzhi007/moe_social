import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_provider_profile.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_cloud_config_service.dart';
import '../../services/ai_models_cache_service.dart';
import '../../services/ai_provider_connectivity_cache.dart';
import '../../services/ai_provider_detector.dart';
import '../../services/ai_provider_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_confirm_sheet.dart';
import '../../widgets/ai/ai_loading_skeleton.dart';
import '../../widgets/ai/ai_scaffold.dart';
import '../../widgets/ai/ai_sheet.dart';
import '../../widgets/ai/ai_status_dot.dart';
import '../../widgets/ai/ai_surface_card.dart';
import '../../widgets/ai/ai_theme.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_pressable.dart';

// ── 预设服务 ──────────────────────────────────────────────────────────────

class _Preset {
  final String name;
  final IconData icon;
  final Color color;
  final String baseUrl;
  final String hint;

  const _Preset({
    required this.name,
    required this.icon,
    required this.color,
    required this.baseUrl,
    required this.hint,
  });
}

const _presets = <_Preset>[
  _Preset(
    name: 'OpenAI',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF10A37F),
    baseUrl: 'https://api.openai.com/v1',
    hint: 'GPT-4o / GPT-4o-mini',
  ),
  _Preset(
    name: 'DeepSeek',
    icon: Icons.bolt_rounded,
    color: Color(0xFF4F6EF7),
    baseUrl: 'https://api.deepseek.com/v1',
    hint: 'deepseek-chat / deepseek-reasoner',
  ),
  _Preset(
    name: 'OpenRouter',
    icon: Icons.route_rounded,
    color: Color(0xFF6C3FC5),
    baseUrl: 'https://openrouter.ai/api/v1',
    hint: '聚合多家模型',
  ),
  _Preset(
    name: 'SiliconFlow',
    icon: Icons.memory_rounded,
    color: Color(0xFFE97B20),
    baseUrl: 'https://api.siliconflow.cn/v1',
    hint: '国内高速中转',
  ),
  _Preset(
    name: '自定义',
    icon: Icons.tune_rounded,
    color: Color(0xFF757575),
    baseUrl: '',
    hint: '任意 OpenAI 兼容服务',
  ),
];

// ── 页面 ──────────────────────────────────────────────────────────────────

class AiProviderProfilesPage extends StatefulWidget {
  const AiProviderProfilesPage({super.key});

  @override
  State<AiProviderProfilesPage> createState() => _AiProviderProfilesPageState();
}

class _AiProviderProfilesPageState extends State<AiProviderProfilesPage> {
  List<AiProviderProfile> _profiles = [];
  bool _initialLoading = true;
  bool _syncingCloud = false;
  String? _activeProfileId;
  final Map<String, ProviderConnectivityState?> _connectivity = {};
  final Map<String, bool> _apiKeyConfigured = {};
  final Set<String> _cloudApiKeyProfiles = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_profiles.isEmpty) {
      setState(() => _initialLoading = true);
    } else {
      setState(() => _syncingCloud = true);
    }
    final providerService = AiProviderService();
    final profiles = await providerService.listProfiles();
    final activeSelection =
        await providerService.resolveActiveProvider(profiles: profiles);
    final conn = <String, ProviderConnectivityState?>{};
    final keys = <String, bool>{};
    final cloudKeyIds = await providerService
        .readCloudApiKeyProfileIds()
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    for (final p in profiles) {
      if (!p.isBuiltin) {
        conn[p.id] = await AiProviderConnectivityCache.read(p.id);
        if (p.requiresApiKey) {
          keys[p.id] = (await AiProviderService().readApiKey(p.id)).isNotEmpty;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeProfileId = activeSelection.profile.isBuiltinBackend
          ? null
          : activeSelection.profile.id;
      _connectivity
        ..clear()
        ..addAll(conn);
      _apiKeyConfigured
        ..clear()
        ..addAll(keys);
      if (cloudKeyIds != null) {
        _cloudApiKeyProfiles
          ..clear()
          ..addAll(cloudKeyIds);
      }
      _initialLoading = false;
      _syncingCloud = false;
    });
  }

  AiSyncStatus _statusFor(AiProviderProfile p) {
    final s = _connectivity[p.id];
    if (s == null) return AiSyncStatus.idle;
    return s.isSuccess ? AiSyncStatus.success : AiSyncStatus.error;
  }

  List<AiProviderProfile> get _customProfiles =>
      _profiles.where((p) => !p.isBuiltin).toList(growable: false);

  String _hostFor(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return url.trim();
  }

  // ── 动态描述 ──

  String _descriptionFor(AiProviderProfile p) {
    final host = Uri.tryParse(p.baseUrl)?.host.toLowerCase() ?? '';
    if (host.contains('openai.com')) return 'OpenAI 官方 API';
    if (host.contains('deepseek')) return 'DeepSeek 深度求索';
    if (host.contains('openrouter')) return 'OpenRouter 模型聚合';
    if (host.contains('siliconflow')) return 'SiliconFlow 硅基流动';
    if (host.contains('anthropic')) return 'Anthropic Claude';
    if (host.contains('google')) return 'Google AI';
    if (p.isBackendOllama) return '后端推理服务';
    if (p.isLlamaCppServer) return '本机 llama.cpp 推理';
    return 'OpenAI 兼容中转站';
  }

  IconData _iconFor(AiProviderProfile p) {
    final host = Uri.tryParse(p.baseUrl)?.host.toLowerCase() ?? '';
    if (host.contains('openai.com')) return Icons.auto_awesome_rounded;
    if (host.contains('deepseek')) return Icons.bolt_rounded;
    if (host.contains('openrouter')) return Icons.route_rounded;
    if (host.contains('siliconflow')) return Icons.memory_rounded;
    return Icons.api_rounded;
  }

  Color _accentFor(AiProviderProfile p) {
    final host = Uri.tryParse(p.baseUrl)?.host.toLowerCase() ?? '';
    if (host.contains('openai.com')) return const Color(0xFF10A37F);
    if (host.contains('deepseek')) return const Color(0xFF4F6EF7);
    if (host.contains('openrouter')) return const Color(0xFF6C3FC5);
    if (host.contains('siliconflow')) return const Color(0xFFE97B20);
    return const Color(0xFF42A5F5);
  }

  // ── Provider 列表卡片 ──

  Widget _buildCard(AiProviderProfile profile) {
    final accent = _accentFor(profile);
    final defaultModel = profile.defaultModel.trim();
    final host = _hostFor(profile.baseUrl);
    final connectivity = _connectivity[profile.id];
    final isActive = _activeProfileId == profile.id;
    final configuredModelCount = profile.effectiveModelIds.length;
    final modelCount =
        connectivity != null && connectivity.modelCount > configuredModelCount
            ? connectivity.modelCount
            : configuredModelCount;
    final keyLabel = profile.requiresApiKey
        ? (_apiKeyConfigured[profile.id] != true
            ? '待配置 Key'
            : _cloudApiKeyProfiles.contains(profile.id)
                ? '账号已同步'
                : '仅本机保存')
        : '无需 Key';

    return AiSurfaceCard(
      onTap: () => _showEditor(initial: profile),
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceLg,
        MoeTokens.spaceMd,
        MoeTokens.spaceXs,
        MoeTokens.spaceMd,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                ),
                child: Icon(_iconFor(profile), color: accent, size: 22),
              ),
              const SizedBox(width: MoeTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: MoeTokens.fontWeightTitle,
                              fontSize: MoeTokens.textMd,
                              color: AiBrandTokens.titleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: MoeTokens.spaceSm),
                        _StatusPill(status: _statusFor(profile)),
                      ],
                    ),
                    const SizedBox(height: MoeTokens.spaceXs),
                    Text(
                      _descriptionFor(profile),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AiTheme.caption,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: MoeTokens.inkMuted,
                ),
                iconSize: 22,
                offset: const Offset(0, 8),
                position: PopupMenuPosition.under,
                color: MoeTokens.surface3,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                ),
                onSelected: (value) {
                  if (value == 'edit') _showEditor(initial: profile);
                  if (value == 'delete') _delete(profile);
                  if (value == 'select') _selectForChat(profile);
                },
                itemBuilder: (_) => [
                  if (!isActive)
                    const PopupMenuItem(
                      value: 'select',
                      height: 44,
                      child: _ProviderActionMenuItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '设为聊天服务',
                        color: MoeTokens.primary,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    height: 44,
                    child: _ProviderActionMenuItem(
                      icon: Icons.edit_outlined,
                      label: '编辑',
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 44,
                    child: _ProviderActionMenuItem(
                      icon: Icons.delete_outline_rounded,
                      label: '删除',
                      color: MoeTokens.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: MoeTokens.spaceMd),
          Divider(height: 1, color: MoeTokens.lineSoft.withValues(alpha: 0.7)),
          const SizedBox(height: MoeTokens.spaceMd),
          Wrap(
            spacing: MoeTokens.spaceSm,
            runSpacing: MoeTokens.spaceXs,
            children: [
              if (host.isNotEmpty)
                _MetaChip(icon: Icons.link_rounded, label: host),
              _MetaChip(
                icon: Icons.smart_toy_outlined,
                label: modelCount > 0 ? '$modelCount 个模型' : '未设置模型',
                muted: modelCount == 0,
              ),
              _MetaChip(
                icon: profile.requiresApiKey
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_outlined,
                label: keyLabel,
                muted: profile.requiresApiKey &&
                    _apiKeyConfigured[profile.id] != true,
              ),
              if (isActive)
                const _MetaChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '聊天使用中',
                ),
              if (defaultModel.isNotEmpty)
                _MetaChip(
                  icon: Icons.star_outline_rounded,
                  label: defaultModel,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 编辑 Sheet ──

  Future<void> _showEditor({AiProviderProfile? initial}) async {
    final isEditing = initial != null && !initial.isBuiltin;
    final editorProfileId =
        initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final storedApiKey =
        initial == null ? '' : await AiProviderService().readApiKey(initial.id);
    final cachedModels = await AiModelsCacheService().read(editorProfileId);
    final canSyncApiKey = AiCloudConfigService().isAuthenticated;
    final cloudApiKeyProfileIds = initial != null && canSyncApiKey
        ? await AiProviderService()
            .readCloudApiKeyProfileIds()
            .timeout(const Duration(seconds: 2), onTimeout: () => null)
        : null;
    final nameController = TextEditingController(text: initial?.name ?? '');
    final baseUrlController =
        TextEditingController(text: initial?.baseUrl ?? '');
    final defaultModelController =
        TextEditingController(text: initial?.defaultModel ?? '');
    final modelInputController = TextEditingController();
    final apiKeyController = TextEditingController(text: storedApiKey);

    var providerType = initial?.providerType ?? AiProviderType.openAiCompatible;
    var supportsSystemMessages = initial?.supportsSystemMessages ?? true;
    var supportsStreaming = initial?.supportsStreaming ?? false;
    var supportsVision = initial?.supportsVision ?? false;
    var supportsToolCalls = initial?.supportsToolCalls ?? false;
    var manualModels = <String>[
      ...(initial?.manualModels ?? const <String>[])
          .map((model) => model.trim())
          .where((model) => model.isNotEmpty),
    ];
    final initialDefaultModel = initial?.defaultModel.trim() ?? '';
    final cachedAndConfigured = <String>{
      ...manualModels,
      ...cachedModels,
    };
    if (initialDefaultModel.isNotEmpty) {
      cachedAndConfigured.add(initialDefaultModel);
    }
    manualModels = cachedAndConfigured.toList();
    String? testResult;
    bool? testSuccess;
    var detecting = false;
    var showAdvanced = false;
    var obscureApiKey = true;
    var saving = false;
    var clearApiKey = false;
    var detectedModelCount = 0;
    var syncApiKeyToAccount =
        cloudApiKeyProfileIds?.contains(editorProfileId) == true;
    var cloudApiKeySyncTouched = false;
    var selectedPreset = -1;

    // 尝试匹配已有 preset
    if (initial != null) {
      for (var i = 0; i < _presets.length - 1; i++) {
        if (initial.baseUrl
            .contains(_presets[i].baseUrl.replaceAll('/v1', ''))) {
          selectedPreset = i;
          break;
        }
      }
    }

    if (!mounted) return;

    void disposeControllers() {
      nameController.dispose();
      baseUrlController.dispose();
      defaultModelController.dispose();
      modelInputController.dispose();
      apiKeyController.dispose();
    }

    void mergeModels(Iterable<String> incoming) {
      final merged = <String>{
        ...manualModels
            .map((model) => model.trim())
            .where((model) => model.isNotEmpty),
      };
      for (final raw in incoming) {
        final model = raw.trim();
        if (model.isNotEmpty) merged.add(model);
      }
      manualModels = merged.toList();
    }

    bool? savedToCloud;
    try {
      savedToCloud = await AiSheet.show<bool>(
        context: context,
        title: isEditing ? '编辑模型服务' : '添加模型服务',
        subtitle: '连接 AI 模型，让你的伙伴更聪明',
        initialChildSize: 0.98,
        minChildSize: 0.64,
        maxChildSize: 0.99,
        footer: StatefulBuilder(
          builder: (ctx, setFooterState) {
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: AiTheme.secondaryButtonStyle(),
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: AiTheme.primaryButtonStyle(),
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final baseUrl = baseUrlController.text.trim();
                            if (name.isEmpty || baseUrl.isEmpty) {
                              MoeToast.error(context, '请填写服务名称和地址');
                              return;
                            }
                            setFooterState(() => saving = true);
                            try {
                              final now = DateTime.now();
                              final profile = AiProviderProfile(
                                id: editorProfileId,
                                name: name,
                                providerType: providerType,
                                baseUrl: baseUrl,
                                defaultModel:
                                    defaultModelController.text.trim(),
                                manualModels: manualModels,
                                supportsSystemMessages: supportsSystemMessages,
                                supportsStreaming: supportsStreaming,
                                supportsVision: supportsVision,
                                supportsToolCalls: supportsToolCalls,
                                createdAt: initial?.createdAt ?? now,
                                updatedAt: now,
                              );
                              final bool? cloudSyncDecision =
                                  cloudApiKeySyncTouched ||
                                          cloudApiKeyProfileIds != null
                                      ? syncApiKeyToAccount
                                      : null;
                              await AiProviderService().saveProfile(
                                profile,
                                apiKey: apiKeyController.text.trim(),
                                clearApiKey: clearApiKey,
                                syncApiKeyToCloud: cloudSyncDecision,
                              );
                              if (!isEditing) {
                                await AiProviderService()
                                    .saveLastSelectedProfileId(profile.id);
                              }
                              if (testSuccess == true) {
                                await AiProviderConnectivityCache.saveSuccess(
                                  profile.id,
                                  modelCount: detectedModelCount > 0
                                      ? detectedModelCount
                                      : manualModels.length,
                                );
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx, cloudSyncDecision == true);
                            } on AiCloudSyncException catch (error) {
                              if (!ctx.mounted) return;
                              setFooterState(() => saving = false);
                              MoeToast.error(ctx, error.message);
                            } catch (_) {
                              if (!ctx.mounted) return;
                              setFooterState(() => saving = false);
                              MoeToast.error(ctx, '保存失败，请稍后重试');
                            }
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (saving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: MoeTokens.spaceSm),
                        Text(saving ? '保存中...' : '保存'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocalState) {
            // ── 一键检测 ──
            Future<void> runDetectAndTest() async {
              final url = baseUrlController.text.trim();
              if (url.isEmpty) {
                MoeToast.error(context, '请先填写服务地址');
                return;
              }
              final enteredApiKey =
                  AiProviderService.normalizeApiKey(apiKeyController.text);
              final previewProfile = AiProviderProfile(
                id: editorProfileId,
                name: nameController.text.trim().isEmpty
                    ? '预览'
                    : nameController.text.trim(),
                providerType: providerType,
                baseUrl: AiProviderDetector.normalizeBaseUrl(url),
                defaultModel: defaultModelController.text.trim(),
                manualModels: manualModels,
                supportsSystemMessages: supportsSystemMessages,
                supportsStreaming: supportsStreaming,
                supportsVision: supportsVision,
                supportsToolCalls: supportsToolCalls,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              if (previewProfile.requiresApiKey && enteredApiKey.isEmpty) {
                setLocalState(() {
                  testResult = '请先填写 API Key，再检测连接';
                  testSuccess = false;
                });
                return;
              }
              setLocalState(() {
                detecting = true;
                testResult = null;
                testSuccess = null;
              });
              try {
                // 1. 智能识别
                final detect = await AiProviderDetector.detect(
                  baseUrl: url,
                  apiKey: apiKeyController.text.trim(),
                  previewProfileId: initial?.id,
                );
                if (!ctx.mounted) return;
                baseUrlController.text = detect.normalizedBaseUrl;
                providerType = detect.suggestedType;
                if (detect.suggestedName != null &&
                    (nameController.text.trim().isEmpty ||
                        nameController.text.trim() == '我的模型服务')) {
                  nameController.text = detect.suggestedName!;
                }
                if (detect.models.isNotEmpty) {
                  mergeModels(detect.models);
                  if (defaultModelController.text.trim().isEmpty) {
                    defaultModelController.text = detect.models.first.trim();
                  }
                }

                // 2. 测试连接
                final temp = AiProviderProfile(
                  id: editorProfileId,
                  name: nameController.text.trim().isEmpty
                      ? '预览'
                      : nameController.text.trim(),
                  providerType: providerType,
                  baseUrl: baseUrlController.text.trim(),
                  defaultModel: defaultModelController.text.trim(),
                  manualModels: manualModels,
                  supportsSystemMessages: supportsSystemMessages,
                  supportsStreaming: supportsStreaming,
                  supportsVision: supportsVision,
                  supportsToolCalls: supportsToolCalls,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                late final List<String> models;
                models = await AiChatGatewayService().fetchModelsForProfile(
                  temp,
                  apiKey: enteredApiKey,
                  allowCachedFallback: false,
                );
                if (!ctx.mounted) return;

                if (models.isNotEmpty) {
                  mergeModels(models);
                  detectedModelCount = models.length;
                  if (defaultModelController.text.trim().isEmpty) {
                    defaultModelController.text = models.first.trim();
                  }
                }

                testSuccess = true;
                if (initial?.id != null) {
                  await AiProviderConnectivityCache.saveSuccess(
                    initial!.id,
                    modelCount: models.length,
                  );
                }
                setLocalState(() {
                  testResult = models.isEmpty
                      ? '连接成功！暂未发现模型列表，可手动添加'
                      : '连接成功！发现 ${models.length} 个可用模型';
                });
              } catch (e) {
                testSuccess = false;
                if (initial?.id != null) {
                  await AiProviderConnectivityCache.saveFailure(initial!.id);
                }
                final msg = e.toString();
                String friendly;
                if (msg.contains('401') || msg.contains('403')) {
                  friendly = 'API Key 无效或已过期，请检查后重试';
                } else if (msg.contains('timeout') || msg.contains('Timeout')) {
                  friendly = '连接超时，请检查地址是否正确';
                } else if (msg.contains('SocketException') ||
                    msg.contains('Connection')) {
                  friendly = '无法连接到服务，请检查网络或地址';
                } else {
                  friendly = '连接失败，请检查服务地址、API Key 和接口兼容性';
                }
                if (ctx.mounted) {
                  setLocalState(() => testResult = friendly);
                }
              } finally {
                if (ctx.mounted) {
                  setLocalState(() {
                    detecting = false;
                  });
                }
              }
            }

            void addManualModel() {
              final value = modelInputController.text.trim();
              if (value.isEmpty || manualModels.contains(value)) return;
              setLocalState(() {
                manualModels.add(value);
                if (defaultModelController.text.trim().isEmpty) {
                  defaultModelController.text = value;
                }
                modelInputController.clear();
              });
            }

            final selectedModel = defaultModelController.text.trim();
            final displayModels = <String>[
              if (selectedModel.isNotEmpty &&
                  manualModels.contains(selectedModel))
                selectedModel,
              ...manualModels.where((model) => model != selectedModel),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Step 1: 快速选择 ──
                if (!isEditing) ...[
                  _buildSectionLabel('选择服务'),
                  const SizedBox(height: MoeTokens.spaceSm),
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presets.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: MoeTokens.spaceSm),
                      itemBuilder: (_, i) {
                        final p = _presets[i];
                        final isSelected = selectedPreset == i;
                        return _PresetTile(
                          preset: p,
                          selected: isSelected,
                          onTap: () {
                            setLocalState(() {
                              selectedPreset = i;
                              if (p.baseUrl.isNotEmpty) {
                                baseUrlController.text = p.baseUrl;
                              }
                              if (nameController.text.trim().isEmpty ||
                                  _presets.any((pr) =>
                                      nameController.text.trim() == pr.name)) {
                                nameController.text =
                                    i < _presets.length - 1 ? p.name : '';
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: MoeTokens.spaceXl),
                ],

                // ── Step 2: 基础信息 ──
                _buildSectionLabel('基本信息'),
                const SizedBox(height: MoeTokens.spaceSm),
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: AiTheme.inputDecoration(
                    labelText: '服务名称',
                    hintText: '例如：我的 GPT、DeepSeek',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.badge_outlined,
                      color: MoeTokens.inkMuted,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceMd),
                TextField(
                  controller: baseUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: AiTheme.inputDecoration(
                    labelText: '服务地址',
                    hintText: 'https://api.example.com/v1',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.link_rounded,
                      color: MoeTokens.inkMuted,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      tooltip: '从剪贴板粘贴',
                      onPressed: () async {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          baseUrlController.text = data!.text!;
                          setLocalState(() {});
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceMd),
                TextField(
                  controller: apiKeyController,
                  obscureText: obscureApiKey,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  decoration: AiTheme.inputDecoration(
                    labelText: 'API Key（密钥）',
                    hintText: 'sk-... 或留空（本地服务无需密钥）',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.key_outlined,
                      color: MoeTokens.inkMuted,
                      size: 20,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (apiKeyController.text.trim().isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 18,
                            ),
                            tooltip: '清除已保存的 API Key',
                            onPressed: () => setLocalState(() {
                              apiKeyController.clear();
                              clearApiKey = true;
                              syncApiKeyToAccount = false;
                              cloudApiKeySyncTouched = true;
                            }),
                          ),
                        IconButton(
                          icon: Icon(
                            obscureApiKey
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 19,
                          ),
                          tooltip: obscureApiKey ? '显示 API Key' : '隐藏 API Key',
                          onPressed: () => setLocalState(
                            () => obscureApiKey = !obscureApiKey,
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.content_paste_rounded, size: 18),
                          tooltip: '从剪贴板粘贴',
                          onPressed: () async {
                            final data =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              apiKeyController.text = data!.text!;
                              setLocalState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  onChanged: (value) {
                    if (value.trim().isEmpty && initial != null) {
                      clearApiKey = true;
                      syncApiKeyToAccount = false;
                      cloudApiKeySyncTouched = true;
                    } else if (value.trim().isNotEmpty) {
                      clearApiKey = false;
                    }
                    setLocalState(() {});
                  },
                ),
                const SizedBox(height: MoeTokens.spaceSm),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    MoeTokens.spaceMd,
                    MoeTokens.spaceSm,
                    MoeTokens.spaceSm,
                    MoeTokens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: AiBrandTokens.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                    border: Border.all(
                      color: AiBrandTokens.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_sync_outlined,
                        size: 19,
                        color: canSyncApiKey
                            ? AiBrandTokens.primary
                            : MoeTokens.hintText,
                      ),
                      const SizedBox(width: MoeTokens.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '在账号间同步 Key',
                              style: AiTheme.body.copyWith(
                                fontWeight: MoeTokens.fontWeightSubtitle,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !canSyncApiKey
                                  ? '登录后可开启，默认不会上传'
                                  : cloudApiKeyProfileIds == null && isEditing
                                      ? '账号同步暂时不可用，可先保存在本机'
                                      : syncApiKeyToAccount
                                          ? '已加密保存，换设备登录后可恢复'
                                          : '仅保存在当前设备，不会上传',
                              style: AiTheme.caption,
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: syncApiKeyToAccount,
                        activeThumbColor: AiBrandTokens.primary,
                        onChanged: !canSyncApiKey ||
                                apiKeyController.text.trim().isEmpty ||
                                (cloudApiKeyProfileIds == null && isEditing)
                            ? null
                            : (value) => setLocalState(() {
                                  syncApiKeyToAccount = value;
                                  cloudApiKeySyncTouched = true;
                                }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceXs),
                Text(
                  '本机始终保留安全副本；关闭同步不会影响当前设备。',
                  style: AiTheme.caption.copyWith(color: AiTheme.success),
                ),
                const SizedBox(height: MoeTokens.spaceLg),

                // ── 一键检测 ──
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: AiTheme.secondaryButtonStyle(),
                    onPressed: detecting ? null : runDetectAndTest,
                    icon: detecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AiBrandTokens.primary,
                            ),
                          )
                        : const Icon(Icons.auto_fix_high_rounded, size: 20),
                    label: Text(
                      detecting ? '正在检测...' : '检测连接并获取模型',
                      style: const TextStyle(
                        fontSize: MoeTokens.textMd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // 检测结果
                if (testResult != null) ...[
                  const SizedBox(height: MoeTokens.spaceSm),
                  Container(
                    padding: const EdgeInsets.all(MoeTokens.spaceMd),
                    decoration: BoxDecoration(
                      color: (testSuccess == true
                              ? AiTheme.success
                              : AiTheme.danger)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                      border: Border.all(
                        color: (testSuccess == true
                                ? AiTheme.success
                                : AiTheme.danger)
                            .withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          testSuccess == true
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 18,
                          color: testSuccess == true
                              ? AiTheme.success
                              : AiTheme.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            testResult!,
                            style: TextStyle(
                              fontSize: MoeTokens.textSm,
                              color: testSuccess == true
                                  ? AiTheme.success
                                  : AiTheme.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: MoeTokens.spaceXl),

                // ── 模型选择 ──
                _buildSectionLabel('可用模型'),
                const SizedBox(height: MoeTokens.spaceXs),
                Text(
                  '点击模型名称设为默认，支持手动补充',
                  style: AiTheme.caption,
                ),
                const SizedBox(height: MoeTokens.spaceMd),

                // 模型列表
                if (manualModels.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(MoeTokens.spaceLg),
                    decoration: BoxDecoration(
                      color: MoeTokens.softChipBg,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                      border: Border.all(color: MoeTokens.surfaceBorder),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.view_list_outlined,
                            size: 28,
                            color: MoeTokens.hintText,
                          ),
                          const SizedBox(height: MoeTokens.spaceSm),
                          Text(
                            '暂无模型',
                            style: AiTheme.body.copyWith(
                              color: MoeTokens.inkMuted,
                              fontWeight: MoeTokens.fontWeightSubtitle,
                            ),
                          ),
                          const SizedBox(height: MoeTokens.spaceXs),
                          Text(
                            '先检测连接，或在下方手动添加',
                            style: AiTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${manualModels.length} 个模型',
                            style: AiTheme.caption.copyWith(
                              color: MoeTokens.inkMuted,
                              fontWeight: MoeTokens.fontWeightSubtitle,
                            ),
                          ),
                          const Spacer(),
                          if (selectedModel.isNotEmpty)
                            const _ModelDefaultBadge(),
                        ],
                      ),
                      const SizedBox(height: MoeTokens.spaceSm),
                      ...displayModels.map((model) {
                        final isDefault = selectedModel == model;
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: MoeTokens.spaceXs,
                          ),
                          child: _ModelRow(
                            model: model,
                            isDefault: isDefault,
                            onTap: () => setLocalState(
                              () => defaultModelController.text = model,
                            ),
                            onDelete: () {
                              setLocalState(() {
                                manualModels.remove(model);
                                if (defaultModelController.text.trim() ==
                                    model) {
                                  defaultModelController.text =
                                      manualModels.isEmpty
                                          ? ''
                                          : manualModels.first;
                                }
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),

                // 手动添加模型
                const SizedBox(height: MoeTokens.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: modelInputController,
                        textInputAction: TextInputAction.done,
                        decoration: AiTheme.inputDecoration(
                          labelText: '手动添加模型 ID',
                          hintText: '例如：gpt-4o-mini',
                        ).copyWith(
                          prefixIcon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: MoeTokens.inkMuted,
                            size: 20,
                          ),
                        ),
                        onSubmitted: (_) => addManualModel(),
                      ),
                    ),
                    const SizedBox(width: MoeTokens.spaceSm),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AiBrandTokens.primary.withValues(alpha: 0.12),
                          foregroundColor: AiBrandTokens.primary,
                        ),
                        onPressed: addManualModel,
                        tooltip: '添加模型',
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: MoeTokens.spaceXl),

                // ── 高级设置（折叠） ──
                MoePressable(
                  onTap: () =>
                      setLocalState(() => showAdvanced = !showAdvanced),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                  child: AnimatedContainer(
                    duration: MoeTokens.motionFast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: MoeTokens.spaceMd,
                      vertical: MoeTokens.spaceMd,
                    ),
                    decoration: BoxDecoration(
                      color: showAdvanced
                          ? AiBrandTokens.primary.withValues(alpha: 0.08)
                          : MoeTokens.softChipBg,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                      border: Border.all(
                        color: showAdvanced
                            ? AiBrandTokens.primary.withValues(alpha: 0.32)
                            : MoeTokens.surfaceBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(MoeTokens.spaceSm),
                          decoration: BoxDecoration(
                            color:
                                AiBrandTokens.primary.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(MoeTokens.radiusMd),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: AiBrandTokens.primary,
                          ),
                        ),
                        const SizedBox(width: MoeTokens.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '高级设置',
                                style: AiTheme.body.copyWith(
                                  fontWeight: MoeTokens.fontWeightSubtitle,
                                ),
                              ),
                              const SizedBox(height: MoeTokens.spaceXs),
                              Text(
                                '调整输出方式与模型能力',
                                style: AiTheme.caption,
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: showAdvanced ? 0.5 : 0,
                          duration: MoeTokens.motionFast,
                          child: const Icon(
                            Icons.expand_more_rounded,
                            color: MoeTokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (showAdvanced) ...[
                  const SizedBox(height: MoeTokens.spaceSm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text('系统消息',
                        style:
                            AiTheme.body.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('部分旧模型不支持，关闭后自动兼容', style: AiTheme.caption),
                    value: supportsSystemMessages,
                    activeTrackColor: AiBrandTokens.primary,
                    onChanged: (v) =>
                        setLocalState(() => supportsSystemMessages = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text('流式输出',
                        style:
                            AiTheme.body.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('逐字显示回复，体验更流畅', style: AiTheme.caption),
                    value: supportsStreaming,
                    activeTrackColor: AiBrandTokens.primary,
                    onChanged: (v) =>
                        setLocalState(() => supportsStreaming = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text('图像理解',
                        style:
                            AiTheme.body.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('支持发送图片给 AI 分析', style: AiTheme.caption),
                    value: supportsVision,
                    activeTrackColor: AiBrandTokens.primary,
                    onChanged: (v) => setLocalState(() => supportsVision = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text('工具调用',
                        style:
                            AiTheme.body.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('允许 AI 调用记忆搜索等高级功能', style: AiTheme.caption),
                    value: supportsToolCalls,
                    activeTrackColor: AiBrandTokens.primary,
                    onChanged: (v) =>
                        setLocalState(() => supportsToolCalls = v),
                  ),
                ],

                const SizedBox(height: MoeTokens.space2xl),
              ],
            );
          },
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        disposeControllers();
      });
    }
    if (mounted) {
      await _load();
      if (savedToCloud == true && mounted) {
        MoeToast.success(context, 'API Key 已同步到账号，登录后可恢复');
      }
    }
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AiBrandTokens.titleColor,
        ),
      ),
    );
  }

  // ── 删除 ──

  Future<void> _selectForChat(AiProviderProfile profile) async {
    await AiProviderService().saveLastSelectedProfileId(profile.id);
    if (!mounted) return;
    setState(() => _activeProfileId = profile.id);
    MoeToast.success(context, '已切换到 ${profile.name}，聊天会使用它');
  }

  Future<void> _delete(AiProviderProfile profile) async {
    final ok = await AiConfirmSheet.show(
      context: context,
      title: '删除服务',
      message: '确定删除「${profile.name}」吗？已使用它的角色需要重新选择来源。',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (!ok) return;
    await AiProviderService().deleteProfile(profile.id);
    await _load();
    if (mounted) {
      MoeToast.success(context, '已删除');
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final customProfiles = _customProfiles;

    return AiScaffold(
      title: '模型服务',
      syncStatus: _syncingCloud ? AiSyncStatus.syncing : AiSyncStatus.idle,
      syncLabel: _syncingCloud ? '正在同步…' : null,
      bottomNavigationBar: _initialLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MoeTokens.spaceLg,
                  MoeTokens.spaceSm,
                  MoeTokens.spaceLg,
                  MoeTokens.spaceSm,
                ),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: AiTheme.primaryButtonStyle(),
                    onPressed: () => _showEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      '添加服务',
                      style: TextStyle(
                        fontSize: MoeTokens.textMd,
                        fontWeight: MoeTokens.fontWeightTitle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: _initialLoading
          ? const AiLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: customProfiles.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AiTheme.pagePadding),
                      children: const [
                        SizedBox(height: MoeTokens.space3xl),
                        MoeEmptyState(
                          icon: Icons.hub_outlined,
                          title: '还没有模型服务',
                          subtitle:
                              '连接 OpenAI、DeepSeek、OpenRouter 等兼容接口，配置后即可和伙伴聊天。',
                          compact: true,
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AiTheme.pagePadding,
                        MoeTokens.spaceMd,
                        AiTheme.pagePadding,
                        MoeTokens.spaceLg,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            MoeTokens.spaceXs,
                            MoeTokens.spaceSm,
                            MoeTokens.spaceXs,
                            MoeTokens.spaceMd,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('我的模型来源', style: AiTheme.title),
                                    const SizedBox(height: MoeTokens.spaceXs),
                                    Text(
                                      '聊天和角色会共用这里的连接配置',
                                      style: AiTheme.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${customProfiles.length} 个服务',
                                style: const TextStyle(
                                  fontSize: MoeTokens.textSm,
                                  fontWeight: MoeTokens.fontWeightSubtitle,
                                  color: MoeTokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...customProfiles.map(_buildCard),
                      ],
                    ),
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AiSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AiSyncStatus.success => ('已连通', MoeTokens.success),
      AiSyncStatus.error => ('连接失败', MoeTokens.danger),
      AiSyncStatus.syncing => ('检测中', MoeTokens.secondary),
      AiSyncStatus.warning => ('异常', MoeTokens.warning),
      AiSyncStatus.idle => ('未检测', MoeTokens.inkMuted),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MoeTokens.spaceSm,
          vertical: MoeTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: MoeTokens.spaceXs),
            Text(
              label,
              style: TextStyle(
                fontSize: MoeTokens.textXs,
                fontWeight: MoeTokens.fontWeightSubtitle,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.icon,
    this.muted = false,
  });

  final String label;
  final IconData? icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? MoeTokens.hintText : MoeTokens.caption;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceSm,
        vertical: MoeTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: MoeTokens.softChipBg,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: MoeTokens.spaceXs),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 168),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: MoeTokens.textXs,
                fontWeight: MoeTokens.fontWeightSubtitle,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderActionMenuItem extends StatelessWidget {
  const _ProviderActionMenuItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: MoeTokens.spaceSm),
        Text(
          label,
          style: TextStyle(
            fontSize: MoeTokens.textBase,
            fontWeight: MoeTokens.fontWeightSubtitle,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final _Preset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '选择${preset.name}，${preset.hint}',
      child: SizedBox(
        width: 104,
        child: MoePressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          child: AnimatedContainer(
            duration: MoeTokens.motionFast,
            padding: const EdgeInsets.symmetric(
              horizontal: MoeTokens.spaceSm,
              vertical: MoeTokens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? preset.color.withValues(alpha: 0.10)
                  : MoeTokens.surface1,
              borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
              border: Border.all(
                color: selected ? preset.color : MoeTokens.surfaceBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(preset.icon, color: preset.color, size: 21),
                const SizedBox(height: MoeTokens.spaceXs),
                Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: MoeTokens.textXs,
                    fontWeight: selected
                        ? MoeTokens.fontWeightTitle
                        : MoeTokens.fontWeightSubtitle,
                    color: selected ? preset.color : MoeTokens.inkDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: MoeTokens.textXs,
                    color: selected
                        ? preset.color.withValues(alpha: 0.84)
                        : MoeTokens.hintText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.isDefault,
    required this.onTap,
    required this.onDelete,
  });

  final String model;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = isDefault ? AiBrandTokens.primary : MoeTokens.inkMuted;
    return Semantics(
      button: true,
      selected: isDefault,
      label: isDefault ? '$model，默认模型' : model,
      child: MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
        child: AnimatedContainer(
          duration: MoeTokens.motionFast,
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.fromLTRB(
            MoeTokens.spaceSm,
            MoeTokens.spaceXs,
            MoeTokens.spaceXs,
            MoeTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: isDefault
                ? AiBrandTokens.primary.withValues(alpha: 0.10)
                : MoeTokens.softChipBg,
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            border: Border.all(
              color: isDefault
                  ? AiBrandTokens.primary.withValues(alpha: 0.72)
                  : MoeTokens.surfaceBorder,
              width: isDefault ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDefault
                      ? AiBrandTokens.primary.withValues(alpha: 0.16)
                      : MoeTokens.surface1,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
                ),
                child: Icon(
                  isDefault ? Icons.star_rounded : Icons.smart_toy_outlined,
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(width: MoeTokens.spaceSm),
              Expanded(
                child: Text(
                  model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AiTheme.mono.copyWith(
                    color: isDefault
                        ? AiBrandTokens.primary
                        : AiBrandTokens.titleColor,
                    fontWeight:
                        isDefault ? MoeTokens.fontWeightTitle : FontWeight.w500,
                  ),
                ),
              ),
              if (isDefault) ...[
                const SizedBox(width: MoeTokens.spaceSm),
                const _ModelDefaultBadge(),
              ],
              IconButton(
                onPressed: onDelete,
                tooltip: '移除模型',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                splashRadius: 18,
                iconSize: 17,
                color: MoeTokens.hintText,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelDefaultBadge extends StatelessWidget {
  const _ModelDefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceSm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AiBrandTokens.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      ),
      child: Text(
        '默认',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: MoeTokens.textXs,
          fontWeight: MoeTokens.fontWeightSubtitle,
          color: AiBrandTokens.primary,
        ),
      ),
    );
  }
}
