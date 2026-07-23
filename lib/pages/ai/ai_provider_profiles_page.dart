import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_provider_profile.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_provider_connectivity_cache.dart';
import '../../services/ai_provider_detector.dart';
import '../../services/ai_provider_service.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_confirm_sheet.dart';
import '../../widgets/ai/ai_loading_skeleton.dart';
import '../../widgets/ai/ai_scaffold.dart';
import '../../widgets/ai/ai_sheet.dart';
import '../../widgets/ai/ai_status_dot.dart';
import '../../widgets/ai/ai_surface_card.dart';
import '../../widgets/ai/ai_theme.dart';
import '../../widgets/moe_toast.dart';

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
  final Map<String, ProviderConnectivityState?> _connectivity = {};

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
    final profiles = await AiProviderService().listProfiles();
    final conn = <String, ProviderConnectivityState?>{};
    for (final p in profiles) {
      if (!p.isBuiltin) {
        conn[p.id] = await AiProviderConnectivityCache.read(p.id);
      }
    }
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _connectivity
        ..clear()
        ..addAll(conn);
      _initialLoading = false;
      _syncingCloud = false;
    });
  }

  AiSyncStatus _statusFor(AiProviderProfile p) {
    final s = _connectivity[p.id];
    if (s == null) return AiSyncStatus.idle;
    return s.isSuccess ? AiSyncStatus.success : AiSyncStatus.error;
  }

  String? _statusLabelFor(AiProviderProfile p) {
    final s = _connectivity[p.id];
    if (s == null) return null;
    return s.isSuccess ? '已连通' : '连接失败';
  }

  String _shortUrl(String url) {
    if (url.length <= 46) return url;
    return '${url.substring(0, 22)}…${url.substring(url.length - 20)}';
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
    final status = _statusFor(profile);
    final statusLabel = _statusLabelFor(profile);
    final modelLine = profile.defaultModel.isEmpty
        ? '未设置默认模型'
        : profile.defaultModel;
    final manualLine = profile.manualModels.isEmpty
        ? ''
        : ' · 另有 ${profile.manualModels.length} 个模型';
    final accent = _accentFor(profile);

    return AiSurfaceCard(
      onTap: () => _showEditor(initial: profile),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(profile), color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AiBrandTokens.titleColor,
                        ),
                      ),
                    ),
                    AiStatusDot(status: status, label: statusLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_descriptionFor(profile), style: AiTheme.caption),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text('地址', style: AiTheme.caption),
                      ),
                      Expanded(
                        child: Text(
                          _shortUrl(profile.baseUrl),
                          style: AiTheme.caption.copyWith(
                            color: AiBrandTokens.titleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text('模型', style: AiTheme.caption),
                      ),
                      Expanded(
                        child: Text(
                          '$modelLine$manualLine',
                          style: AiTheme.caption.copyWith(
                            color: AiBrandTokens.titleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
            onSelected: (value) {
              if (value == 'edit') _showEditor(initial: profile);
              if (value == 'delete') _delete(profile);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }

  // ── 编辑 Sheet ──

  Future<void> _showEditor({AiProviderProfile? initial}) async {
    final isEditing = initial != null && !initial.isBuiltin;
    final nameController =
        TextEditingController(text: initial?.name ?? '');
    final baseUrlController =
        TextEditingController(text: initial?.baseUrl ?? '');
    final defaultModelController =
        TextEditingController(text: initial?.defaultModel ?? '');
    final apiKeyController = TextEditingController(
      text: initial == null
          ? ''
          : await AiProviderService().readApiKey(initial.id),
    );

    var providerType =
        initial?.providerType ?? AiProviderType.openAiCompatible;
    var supportsSystemMessages = initial?.supportsSystemMessages ?? true;
    var supportsStreaming = initial?.supportsStreaming ?? false;
    var supportsVision = initial?.supportsVision ?? false;
    var supportsToolCalls = initial?.supportsToolCalls ?? false;
    var manualModels = <String>[...(initial?.manualModels ?? const <String>[])];
    String? testResult;
    bool? testSuccess;
    var detecting = false;
    var showAdvanced = false;
    var selectedPreset = -1;

    // 尝试匹配已有 preset
    if (initial != null) {
      for (var i = 0; i < _presets.length - 1; i++) {
        if (initial.baseUrl.contains(_presets[i].baseUrl.replaceAll('/v1', ''))) {
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
      apiKeyController.dispose();
    }

    try {
      await AiSheet.show<void>(
        context: context,
        title: isEditing ? '编辑模型服务' : '添加模型服务',
        subtitle: '连接 AI 模型，让你的伙伴更聪明',
        footer: StatefulBuilder(
          builder: (ctx, setFooterState) {
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: AiTheme.primaryButtonStyle(),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final baseUrl = baseUrlController.text.trim();
                      if (name.isEmpty || baseUrl.isEmpty) {
                        MoeToast.error(context, '请填写服务名称和地址');
                        return;
                      }
                      final now = DateTime.now();
                      final profile = AiProviderProfile(
                        id: initial?.id ??
                            now.millisecondsSinceEpoch.toString(),
                        name: name,
                        providerType: providerType,
                        baseUrl: baseUrl,
                        defaultModel: defaultModelController.text.trim(),
                        manualModels: manualModels,
                        supportsSystemMessages: supportsSystemMessages,
                        supportsStreaming: supportsStreaming,
                        supportsVision: supportsVision,
                        supportsToolCalls: supportsToolCalls,
                        createdAt: initial?.createdAt ?? now,
                        updatedAt: now,
                      );
                      await AiProviderService().saveProfile(
                        profile,
                        apiKey: apiKeyController.text.trim(),
                      );
                      if (testSuccess == true && initial?.id != null) {
                        await AiProviderConnectivityCache.saveSuccess(
                            profile.id);
                      }
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
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
                  final existing = {...manualModels};
                  existing.addAll(detect.models);
                  manualModels = existing.toList();
                  if (defaultModelController.text.trim().isEmpty) {
                    defaultModelController.text = detect.models.first;
                  }
                }

                // 2. 测试连接
                const previewId = 'preview_provider_test';
                final temp = AiProviderProfile(
                  id: initial?.id ?? previewId,
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
                await AiProviderService().writeApiKey(
                  temp.id,
                  apiKeyController.text.trim(),
                );
                final models = await AiChatGatewayService()
                    .fetchModelsForProfile(temp);
                if (initial == null) {
                  await AiProviderService().deleteApiKey(previewId);
                }
                if (!ctx.mounted) return;

                if (models.isNotEmpty) {
                  final existing = {...manualModels};
                  existing.addAll(models);
                  manualModels = existing.toList();
                  if (defaultModelController.text.trim().isEmpty) {
                    defaultModelController.text = models.first;
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
                } else if (msg.contains('timeout') ||
                    msg.contains('Timeout')) {
                  friendly = '连接超时，请检查地址是否正确';
                } else if (msg.contains('SocketException') ||
                    msg.contains('Connection')) {
                  friendly = '无法连接到服务，请检查网络或地址';
                } else {
                  friendly = '连接失败：$msg';
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Step 1: 快速选择 ──
                if (!isEditing) ...[
                  _buildSectionLabel('选择服务'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final p = _presets[i];
                        final isSelected = selectedPreset == i;
                        return GestureDetector(
                          onTap: () {
                            setLocalState(() {
                              selectedPreset = i;
                              if (p.baseUrl.isNotEmpty) {
                                baseUrlController.text = p.baseUrl;
                              }
                              if (nameController.text.trim().isEmpty ||
                                  _presets.any((pr) =>
                                      nameController.text.trim() ==
                                      pr.name)) {
                                nameController.text =
                                    i < _presets.length - 1 ? p.name : '';
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 80,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? p.color.withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? p.color
                                    : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(p.icon, color: p.color, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? p.color
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Step 2: 基础信息 ──
                _buildSectionLabel('基本信息'),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: AiTheme.inputDecoration(
                    labelText: '服务名称',
                    hintText: '例如：我的 GPT、DeepSeek',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baseUrlController,
                  decoration: AiTheme.inputDecoration(
                    labelText: '服务地址',
                    hintText: 'https://api.example.com/v1',
                  ).copyWith(
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
                const SizedBox(height: 12),
                TextField(
                  controller: apiKeyController,
                  obscureText: true,
                  decoration: AiTheme.inputDecoration(
                    labelText: 'API Key（密钥）',
                    hintText: 'sk-... 或留空（本地服务无需密钥）',
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
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
                  ),
                ),
                const SizedBox(height: 16),

                // ── 一键检测 ──
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AiBrandTokens.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: detecting ? null : runDetectAndTest,
                    icon: detecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_fix_high_rounded, size: 20),
                    label: Text(
                      detecting
                          ? '正在检测...'
                          : '自动检测并获取模型',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // 检测结果
                if (testResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (testSuccess == true
                              ? AiTheme.success
                              : AiTheme.danger)
                          .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AiTheme.radiusAiCard),
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
                              fontSize: 13,
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

                const SizedBox(height: 20),

                // ── 模型选择 ──
                _buildSectionLabel('可用模型'),
                const SizedBox(height: 4),
                Text(
                  '点击选择默认模型，或手动添加',
                  style: AiTheme.caption,
                ),
                const SizedBox(height: 10),

                // 模型芯片
                if (manualModels.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius:
                          BorderRadius.circular(AiTheme.radiusAiCard),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded,
                              size: 32, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            '暂无模型',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击上方「自动检测」获取模型列表',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: manualModels.map((m) {
                      final isDefault =
                          defaultModelController.text.trim() == m;
                      return GestureDetector(
                        onTap: () {
                          setLocalState(() {
                            defaultModelController.text = m;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDefault
                                ? AiBrandTokens.primary.withValues(alpha: 0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDefault
                                  ? AiBrandTokens.primary
                                  : Colors.grey.shade300,
                              width: isDefault ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDefault) ...[
                                Icon(Icons.star_rounded,
                                    size: 14,
                                    color: AiBrandTokens.primary),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                m,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isDefault
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isDefault
                                      ? AiBrandTokens.primary
                                      : AiBrandTokens.titleColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setLocalState(() {
                                    manualModels.remove(m);
                                    if (defaultModelController.text.trim() ==
                                        m) {
                                      defaultModelController.text =
                                          manualModels.isEmpty
                                              ? ''
                                              : manualModels.first;
                                    }
                                  });
                                },
                                child: Icon(Icons.close_rounded,
                                    size: 14,
                                    color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                // 手动添加模型
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: defaultModelController,
                        decoration: AiTheme.inputDecoration(
                          labelText: '添加模型',
                          hintText: '输入模型名称',
                        ),
                        onSubmitted: (v) {
                          final val = v.trim();
                          if (val.isNotEmpty &&
                              !manualModels.contains(val)) {
                            setLocalState(() {
                              manualModels.add(val);
                              defaultModelController.clear();
                              if (defaultModelController.text.isEmpty) {
                                defaultModelController.text = val;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AiBrandTokens.primary.withValues(alpha: 0.12),
                        foregroundColor: AiBrandTokens.primary,
                      ),
                      onPressed: () {
                        final val =
                            defaultModelController.text.trim();
                        if (val.isNotEmpty &&
                            !manualModels.contains(val)) {
                          setLocalState(() {
                            manualModels.add(val);
                            if (manualModels.length == 1) {
                              // 第一个自动设为默认
                            }
                            defaultModelController.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── 高级设置（折叠） ──
                GestureDetector(
                  onTap: () =>
                      setLocalState(() => showAdvanced = !showAdvanced),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius:
                          BorderRadius.circular(AiTheme.radiusAiCard),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined,
                            size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '高级设置',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        Icon(
                          showAdvanced
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ),
                ),

                if (showAdvanced) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('系统消息',
                        style: AiTheme.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('部分旧模型不支持，关闭后自动兼容',
                        style: AiTheme.caption),
                    value: supportsSystemMessages,
                    activeTrackColor: AiBrandTokens.primary,
                    onChanged: (v) => setLocalState(
                        () => supportsSystemMessages = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('流式输出',
                        style: AiTheme.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('逐字显示回复，体验更流畅',
                        style: AiTheme.caption),
                    value: supportsStreaming,
                    activeTrackColor: AiBrandTokens.primary,
                    onChanged: (v) => setLocalState(
                        () => supportsStreaming = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('图像理解',
                        style: AiTheme.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('支持发送图片给 AI 分析',
                        style: AiTheme.caption),
                    value: supportsVision,
                    activeTrackColor: AiBrandTokens.primary,
                    onChanged: (v) =>
                        setLocalState(() => supportsVision = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('工具调用',
                        style: AiTheme.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('允许 AI 调用记忆搜索等高级功能',
                        style: AiTheme.caption),
                    value: supportsToolCalls,
                    activeTrackColor: AiBrandTokens.primary,
                    onChanged: (v) =>
                        setLocalState(() => supportsToolCalls = v),
                  ),
                ],

                const SizedBox(height: 24),
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
    if (mounted) await _load();
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
    return AiScaffold(
      title: '模型服务',
      syncStatus: _syncingCloud ? AiSyncStatus.syncing : AiSyncStatus.idle,
      syncLabel: _syncingCloud ? '正在同步…' : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        backgroundColor: AiBrandTokens.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加服务'),
      ),
      body: _initialLoading
          ? const AiLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AiTheme.pagePadding),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AiSurfaceCard(
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 20,
                              color: AiBrandTokens.primary.withValues(alpha: 0.7)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '连接 AI 模型服务，支持 OpenAI / DeepSeek / OpenRouter 等',
                              style: AiTheme.body.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_profiles.where((p) => !p.isBuiltin).isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('已添加的服务',
                                style: AiTheme.title.copyWith(fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('点击编辑或删除', style: AiTheme.caption),
                          ],
                        ),
                      ),
                      ..._profiles
                          .where((p) => !p.isBuiltin)
                          .map(_buildCard),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}
