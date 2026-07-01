import 'package:flutter/material.dart';

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

  static const _apiAccent = Color(0xFF42A5F5);

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

  AiSyncStatus _statusFor(AiProviderProfile profile) {
    final state = _connectivity[profile.id];
    if (state == null) return AiSyncStatus.idle;
    return state.isSuccess ? AiSyncStatus.success : AiSyncStatus.error;
  }

  String? _statusLabelFor(AiProviderProfile profile) {
    final state = _connectivity[profile.id];
    if (state == null) return null;
    return state.isSuccess ? '已连通' : '连接失败';
  }

  String _shortUrl(String url) {
    if (url.length <= 46) return url;
    return '${url.substring(0, 22)}…${url.substring(url.length - 20)}';
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AiTheme.title.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: AiTheme.caption),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(label, style: AiTheme.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AiTheme.caption.copyWith(
                color: AiBrandTokens.titleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard({
    required AiProviderProfile profile,
    required IconData icon,
    required Color accent,
    required String description,
    required List<Widget> metaRows,
    required AiSyncStatus status,
    String? statusLabel,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return AiSurfaceCard(
      onTap: onTap,
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
            child: Icon(icon, color: accent, size: 22),
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
                Text(description, style: AiTheme.caption),
                ...metaRows,
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing,
          ] else if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(AiProviderProfile profile) {
    final status = _statusFor(profile);
    final statusLabel = _statusLabelFor(profile);

    final modelLine =
        profile.defaultModel.isEmpty ? '未设置默认模型' : profile.defaultModel;
    final manualLine = profile.manualModels.isEmpty
        ? ''
        : ' · 另有 ${profile.manualModels.length} 个手动模型';

    return _buildProviderCard(
      profile: profile,
      icon: Icons.api_rounded,
      accent: _apiAccent,
      description: 'OpenAI 兼容中转站',
      status: status,
      statusLabel: statusLabel,
      onTap: () => _showEditor(initial: profile),
      metaRows: [
        _metaRow('地址', _shortUrl(profile.baseUrl)),
        _metaRow('模型', '$modelLine$manualLine'),
      ],
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
        onSelected: (value) {
          if (value == 'edit') {
            _showEditor(initial: profile);
          } else if (value == 'delete') {
            _delete(profile);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedCards() {
    final custom = _profiles.where((p) => !p.isBuiltin);
    return [
      _sectionHeader('云端 API', 'OpenAI 兼容中转站（如 Xbai / OpenRouter）'),
      ...custom.map(_buildCard),
    ];
  }

  Future<void> _showEditor({AiProviderProfile? initial}) async {
    final isEditing = initial != null && !initial.isBuiltin;
    final nameController =
        TextEditingController(text: initial?.name ?? '我的中转站');
    final baseUrlController = TextEditingController(
      text: initial?.baseUrl ?? 'https://your-gateway/v1',
    );
    final defaultModelController =
        TextEditingController(text: initial?.defaultModel ?? '');
    final manualModelsController = TextEditingController(
      text: (initial?.manualModels ?? const <String>[]).join('\n'),
    );
    final apiKeyController = TextEditingController(
      text: initial == null
          ? ''
          : await AiProviderService().readApiKey(initial.id),
    );
    var providerType = initial?.providerType ?? AiProviderType.openAiCompatible;
    var supportsSystemMessages = initial?.supportsSystemMessages ?? true;
    var supportsStreaming = initial?.supportsStreaming ?? false;
    var supportsVision = initial?.supportsVision ?? false;
    var supportsToolCalls = initial?.supportsToolCalls ?? false;
    var testing = false;
    var detecting = false;
    String? testResult;
    bool? testSuccess;
    String? detectResult;
    bool? detectSuccess;

    if (!mounted) return;

    void disposeControllers() {
      nameController.dispose();
      baseUrlController.dispose();
      defaultModelController.dispose();
      manualModelsController.dispose();
      apiKeyController.dispose();
    }

    try {
      await AiSheet.show<void>(
        context: context,
        title: isEditing ? '编辑 Provider' : '新增 Provider',
        subtitle: 'OpenAI 兼容中转站 / OpenRouter / OneAPI 等',
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
                        MoeToast.error(context, '名称和 Base URL 不能为空');
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
                        manualModels: manualModelsController.text
                            .split('\n')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
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
                      if (testSuccess == true) {
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
            Future<void> runTest() async {
              setLocalState(() {
                testing = true;
                testResult = null;
                testSuccess = null;
              });
              const previewId = 'preview_provider_test';
              try {
                final temp = AiProviderProfile(
                  id: initial?.id ?? previewId,
                  name: nameController.text.trim().isEmpty
                      ? '预览 Provider'
                      : nameController.text.trim(),
                  providerType: providerType,
                  baseUrl: baseUrlController.text.trim(),
                  defaultModel: defaultModelController.text.trim(),
                  manualModels: manualModelsController.text
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
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
                final models =
                    await AiChatGatewayService().fetchModelsForProfile(temp);
                if (!ctx.mounted) return;
                testSuccess = true;
                if (initial?.id != null) {
                  await AiProviderConnectivityCache.saveSuccess(
                    initial!.id,
                    modelCount: models.length,
                  );
                }
                if (models.isNotEmpty) {
                  final existing = manualModelsController.text
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toSet();
                  existing.addAll(models);
                  manualModelsController.text = existing.join('\n');
                  if (defaultModelController.text.trim().isEmpty) {
                    defaultModelController.text = models.first;
                  }
                }
                setLocalState(() {
                  testResult = models.isEmpty
                      ? '连接成功，但未返回模型列表；已可填写默认/手动模型后保存'
                      : '连接成功，获取到 ${models.length} 个模型（已填入列表）';
                });
              } catch (e) {
                testSuccess = false;
                if (initial?.id != null) {
                  await AiProviderConnectivityCache.saveFailure(initial!.id);
                }
                if (ctx.mounted) {
                  setLocalState(() => testResult = '测试失败：$e');
                }
              } finally {
                if (initial == null) {
                  await AiProviderService().deleteApiKey(previewId);
                }
                if (ctx.mounted) {
                  setLocalState(() => testing = false);
                }
              }
            }

            Widget switchTile({
              required String title,
              required String subtitle,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(title,
                    style: AiTheme.body.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle, style: AiTheme.caption),
                value: value,
                activeColor: AiBrandTokens.primary,
                onChanged: onChanged,
              );
            }

            final resultColor = testSuccess == null
                ? AiTheme.bodyMuted
                : (testSuccess! ? AiTheme.success : AiTheme.danger);

            Future<void> runDetect() async {
              setLocalState(() {
                detecting = true;
                detectResult = null;
                detectSuccess = null;
              });
              try {
                final result = await AiProviderDetector.detect(
                  baseUrl: baseUrlController.text.trim(),
                  apiKey: apiKeyController.text.trim(),
                  previewProfileId: initial?.id,
                );
                if (!ctx.mounted) return;
                detectSuccess = result.success;
                baseUrlController.text = result.normalizedBaseUrl;
                providerType = result.suggestedType;
                if (result.suggestedName != null &&
                    (nameController.text.trim().isEmpty ||
                        nameController.text.trim() == '我的中转站')) {
                  nameController.text = result.suggestedName!;
                }
                if (result.models.isNotEmpty) {
                  final existing = manualModelsController.text
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toSet();
                  existing.addAll(result.models);
                  manualModelsController.text = existing.join('\n');
                  if (defaultModelController.text.trim().isEmpty) {
                    defaultModelController.text = result.models.first;
                  }
                }
                setLocalState(() => detectResult = result.message);
              } catch (e) {
                detectSuccess = false;
                if (ctx.mounted) {
                  setLocalState(() => detectResult = '识别失败：$e');
                }
              } finally {
                if (ctx.mounted) {
                  setLocalState(() => detecting = false);
                }
              }
            }

            final detectColor = detectSuccess == null
                ? AiTheme.bodyMuted
                : (detectSuccess! ? AiTheme.success : AiTheme.danger);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AiBrandTokens.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AiTheme.radiusAiCard),
                  ),
                  child: Text(
                    '连接成功但模型列表为空时：在下方填写「默认模型」或「手动模型」（一行一个），'
                    '即可创建角色卡。聊天时 App 会带着该模型 ID 调用中转站，无需在服务端新建模型。',
                    style: AiTheme.caption.copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AiProviderType>(
                  value: providerType,
                  decoration: AiTheme.inputDecoration(labelText: '类型'),
                  items: AiProviderType.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() => providerType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: AiTheme.inputDecoration(
                    labelText: '名称',
                    hintText: 'OpenRouter / NewAPI / OneAPI',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baseUrlController,
                  decoration: AiTheme.inputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://your-gateway 或 .../v1',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: detecting ? null : runDetect,
                  icon: detecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high_rounded),
                  label: Text(detecting ? '识别中…' : '智能识别 API 类型'),
                ),
                if (detectResult != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: detectColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AiTheme.radiusAiCard),
                    ),
                    child: Text(
                      detectResult!,
                      style: AiTheme.caption.copyWith(color: detectColor),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: apiKeyController,
                  obscureText: true,
                  decoration: AiTheme.inputDecoration(labelText: 'API Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: defaultModelController,
                  decoration: AiTheme.inputDecoration(
                    labelText: '默认模型 ID（必填其一）',
                    hintText: 'gpt-4o-mini / deepseek-chat',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '创建角色卡与聊天时优先使用；/models 为空时靠它工作',
                    style: AiTheme.caption,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: manualModelsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: AiTheme.inputDecoration(
                    labelText: '手动模型列表（可选，一行一个）',
                    hintText: 'gpt-4o\nclaude-3-5-sonnet\ndeepseek-chat',
                    alignLabelWithHint: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '智能识别或测试连接可自动填入；供「模型来源」Tab 展示',
                    style: AiTheme.caption,
                  ),
                ),
                const SizedBox(height: 8),
                Text('能力开关', style: AiTheme.title.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                switchTile(
                  title: 'System Message',
                  subtitle: '关闭时将系统提示词折叠进首条用户消息',
                  value: supportsSystemMessages,
                  onChanged: (v) =>
                      setLocalState(() => supportsSystemMessages = v),
                ),
                switchTile(
                  title: '流式输出',
                  subtitle: '即将支持；当前请保持关闭',
                  value: supportsStreaming,
                  onChanged: (v) => setLocalState(() => supportsStreaming = v),
                ),
                switchTile(
                  title: '图像输入',
                  subtitle: '预留多模态能力',
                  value: supportsVision,
                  onChanged: (v) => setLocalState(() => supportsVision = v),
                ),
                switchTile(
                  title: '高级：模型多轮工具检索',
                  subtitle:
                      '默认关闭。日常自动注入记忆（1 次聊天）。开启后模型可调用 memory_search/get/save/list 等工具，约多 1～3 轮中转，且需 API 支持 tools',
                  value: supportsToolCalls,
                  onChanged: (v) => setLocalState(() => supportsToolCalls = v),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: testing ? null : runTest,
                  icon: testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(testing ? '测试中…' : '测试连接'),
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AiTheme.radiusAiCard),
                    ),
                    child: Text(
                      testResult!,
                      style: AiTheme.caption.copyWith(color: resultColor),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
    } finally {
      // 等弹窗路由完全卸载后再 dispose，避免热重载/关闭瞬间 TextField 仍持有 controller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        disposeControllers();
      });
    }
    if (mounted) await _load();
  }

  Future<void> _delete(AiProviderProfile profile) async {
    final ok = await AiConfirmSheet.show(
      context: context,
      title: '删除 Provider',
      message: '确定删除「${profile.name}」吗？已引用它的角色需要重新选择来源。',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (!ok) return;
    await AiProviderService().deleteProfile(profile.id);
    await _load();
    if (mounted) {
      MoeToast.success(context, 'Provider 已删除');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AiScaffold(
      title: '模型来源',
      syncStatus: _syncingCloud ? AiSyncStatus.syncing : AiSyncStatus.idle,
      syncLabel: _syncingCloud ? '正在同步云端配置…' : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        backgroundColor: AiBrandTokens.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增 Provider'),
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
                      child: Text(
                        '新增 OpenAI 兼容中转站（OpenRouter / Xbai 等）。',
                        style: AiTheme.body,
                      ),
                    ),
                    ..._buildGroupedCards(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}
