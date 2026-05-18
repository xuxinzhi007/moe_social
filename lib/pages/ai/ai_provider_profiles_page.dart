import 'package:flutter/material.dart';

import '../../models/ai_provider_profile.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_provider_service.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

class AiProviderProfilesPage extends StatefulWidget {
  const AiProviderProfilesPage({super.key});

  @override
  State<AiProviderProfilesPage> createState() => _AiProviderProfilesPageState();
}

class _AiProviderProfilesPageState extends State<AiProviderProfilesPage> {
  List<AiProviderProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profiles = await AiProviderService().listProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _showEditor({AiProviderProfile? initial}) async {
    final isEditing = initial != null && !initial.isBuiltinBackend;
    final nameController =
        TextEditingController(text: initial?.name ?? '我的中转站');
    final baseUrlController =
        TextEditingController(text: initial?.baseUrl ?? 'https://your-gateway/v1');
    final defaultModelController =
        TextEditingController(text: initial?.defaultModel ?? '');
    final manualModelsController = TextEditingController(
      text: (initial?.manualModels ?? const <String>[]).join('\n'),
    );
    final apiKeyController = TextEditingController(
      text: initial == null ? '' : await AiProviderService().readApiKey(initial.id),
    );
    var providerType = initial?.providerType ?? AiProviderType.openAiCompatible;
    var useServerMemory = initial?.useServerMemory ?? false;
    var supportsSystemMessages = initial?.supportsSystemMessages ?? true;
    var supportsStreaming = initial?.supportsStreaming ?? true;
    var supportsVision = initial?.supportsVision ?? false;
    var supportsToolCalls = initial?.supportsToolCalls ?? false;
    var testing = false;
    String? testResult;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> runTest() async {
              setLocalState(() {
                testing = true;
                testResult = null;
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
                  useServerMemory: useServerMemory,
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
                setLocalState(() {
                  testResult = models.isEmpty
                      ? '连接成功，但未返回模型列表；可改用手动模型列表'
                      : '连接成功，获取到 ${models.length} 个模型';
                });
              } catch (e) {
                setLocalState(() => testResult = '测试失败：$e');
              } finally {
                if (initial == null) {
                  await AiProviderService().deleteApiKey(previewId);
                }
                setLocalState(() => testing = false);
              }
            }

            return AlertDialog(
              title: Text(isEditing ? '编辑 Provider' : '新增 Provider'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<AiProviderType>(
                        value: providerType,
                        decoration: const InputDecoration(
                          labelText: '类型',
                          border: OutlineInputBorder(),
                        ),
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
                        decoration: const InputDecoration(
                          labelText: '名称',
                          hintText: '例如：OpenRouter / NewAPI / OneAPI',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          hintText: '例如：https://your-gateway/v1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: defaultModelController,
                        decoration: const InputDecoration(
                          labelText: '默认模型',
                          hintText: '例如：gpt-4o-mini / deepseek-chat',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: manualModelsController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: '手动模型列表',
                          hintText: '一行一个模型 ID；当 /models 不可用时回退使用',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用服务端记忆（预留）'),
                        subtitle: const Text('当前仅内置后端 Ollama 会实际使用'),
                        value: useServerMemory,
                        onChanged: (value) {
                          setLocalState(() => useServerMemory = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('支持 System Message'),
                        subtitle: const Text('若关闭，将把系统提示词折叠进首条对话上下文'),
                        value: supportsSystemMessages,
                        onChanged: (value) {
                          setLocalState(() => supportsSystemMessages = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('支持流式输出'),
                        subtitle: const Text('当前主要用于记录 Provider 能力，后续可接入流式 UI'),
                        value: supportsStreaming,
                        onChanged: (value) {
                          setLocalState(() => supportsStreaming = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('支持图像输入'),
                        subtitle: const Text('用于后续多模态能力判断'),
                        value: supportsVision,
                        onChanged: (value) {
                          setLocalState(() => supportsVision = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('支持工具调用'),
                        subtitle: const Text('用于后续 function/tool calls 扩展'),
                        value: supportsToolCalls,
                        onChanged: (value) {
                          setLocalState(() => supportsToolCalls = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: testing ? null : runTest,
                          icon: testing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering_rounded),
                          label: Text(testing ? '测试中...' : '测试连接'),
                        ),
                      ),
                      if (testResult != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F7FD5).withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            testResult!,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final baseUrl = baseUrlController.text.trim();
                    if (name.isEmpty || baseUrl.isEmpty) {
                      MoeToast.error(context, '名称和 Base URL 不能为空');
                      return;
                    }
                    final now = DateTime.now();
                    final profile = AiProviderProfile(
                      id: initial?.id ?? now.millisecondsSinceEpoch.toString(),
                      name: name,
                      providerType: providerType,
                      baseUrl: baseUrl,
                      defaultModel: defaultModelController.text.trim(),
                      manualModels: manualModelsController.text
                          .split('\n')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      useServerMemory: useServerMemory,
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
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
    await _load();
  }

  Future<void> _delete(AiProviderProfile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Provider'),
        content: Text('确定删除 "${profile.name}" 吗？已引用它的智能体需要重新选择 Provider。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AiProviderService().deleteProfile(profile.id);
    await _load();
    if (mounted) {
      MoeToast.success(context, 'Provider 已删除');
    }
  }

  Widget _buildCard(AiProviderProfile profile) {
    final typeLabel = profile.providerType.label;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: profile.isBuiltinBackend
              ? const Color(0xFF7F7FD5).withOpacity(0.12)
              : const Color(0xFF86A8E7).withOpacity(0.14),
          child: Icon(
            profile.isBuiltinBackend ? Icons.hub_rounded : Icons.api_rounded,
            color: profile.isBuiltinBackend
                ? const Color(0xFF7F7FD5)
                : const Color(0xFF1976D2),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                profile.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF7F7FD5).withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                typeLabel,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            profile.isBuiltinBackend
                ? '使用当前后端 LLM 配置与记忆链路'
                : 'Base URL: ${profile.baseUrl}\n默认模型: ${profile.defaultModel.isEmpty ? '未设置' : profile.defaultModel}',
            style: const TextStyle(height: 1.4),
          ),
        ),
        trailing: profile.isBuiltinBackend
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditor(initial: profile);
                    return;
                  }
                  if (value == 'delete') {
                    _delete(profile);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('AI Provider 管理'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增 Provider'),
      ),
      body: _loading
          ? const Center(child: MoeLoading())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    '当前第一阶段支持：\n'
                    '1. 内置后端 Ollama\n'
                    '2. OpenAI 兼容接口（中转站 / OpenRouter / OneAPI / NewAPI 等）\n\n'
                    '后续再补世界书、角色卡导入导出、分支会话。',
                    style: TextStyle(height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                ..._profiles.map(_buildCard),
              ],
            ),
    );
  }
}
