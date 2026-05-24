import 'package:flutter/material.dart';

import '../../models/ai_provider_profile.dart';
import '../../services/ai_platform_local_provider.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_provider_service.dart';
import '../../pages/ai/ai_provider_profiles_page.dart';
import 'ai_brand_tokens.dart';
import 'ai_sheet.dart';
import 'ai_theme.dart';

/// 使用他人角色卡前：选择本账号的 API 来源与模型 ID。
class AiModelBindingSelection {
  const AiModelBindingSelection({
    required this.provider,
    required this.modelName,
  });

  final AiProviderProfile provider;
  final String modelName;
}

abstract final class AiModelBindingSheet {
  static Future<AiModelBindingSelection?> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String? suggestedModel,
  }) {
    return AiSheet.show<AiModelBindingSelection>(
      context: context,
      title: title,
      subtitle: subtitle ?? '选择你自己的 API 来源与模型，不会使用原作者的 Key',
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      child: _AiModelBindingSheetBody(suggestedModel: suggestedModel),
    );
  }
}

class _AiModelBindingSheetBody extends StatefulWidget {
  const _AiModelBindingSheetBody({this.suggestedModel});

  final String? suggestedModel;

  @override
  State<_AiModelBindingSheetBody> createState() =>
      _AiModelBindingSheetBodyState();
}

class _AiModelBindingSheetBodyState extends State<_AiModelBindingSheetBody> {
  final _modelController = TextEditingController();

  List<AiProviderProfile> _profiles = [
    AiPlatformLocalProvider.defaultBuiltinProfileSync(),
  ];
  String _profileId = AiPlatformLocalProvider.defaultBuiltinProviderId;
  List<String> _models = [];
  bool _loadingProfiles = true;
  bool _loadingModels = false;

  AiProviderProfile get _selectedProfile {
    return _profiles.firstWhere(
      (p) => p.id == _profileId,
      orElse: () => AiProviderProfile.builtinBackend(),
    );
  }

  @override
  void initState() {
    super.initState();
    final hint = widget.suggestedModel?.trim() ?? '';
    if (hint.isNotEmpty) {
      _modelController.text = hint;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final profiles = await AiProviderService().listProfiles();
      final lastId = await AiProviderService().readLastSelectedProfileId();
      var selected =
          lastId ?? AiPlatformLocalProvider.defaultBuiltinProviderId;
      if (!profiles.any((p) => p.id == selected)) {
        selected = AiPlatformLocalProvider.defaultBuiltinProviderId;
      }
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _profileId = selected;
        _models = _selectedProfile.effectiveModelIds;
        _loadingProfiles = false;
      });
      await _loadModels(background: _models.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _loadingProfiles = false);
    }
  }

  Future<void> _loadModels({bool background = false}) async {
    final profile = _selectedProfile;
    final localIds = profile.effectiveModelIds;
    if (!background && mounted && localIds.isNotEmpty) {
      setState(() => _models = localIds);
    }
    if (profile.isOpenAiCompatible &&
        localIds.isNotEmpty &&
        !background) {
      return;
    }

    if (mounted) setState(() => _loadingModels = true);
    try {
      final models = await AiChatGatewayService()
          .fetchModelsForProfile(profile)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        if (models.isNotEmpty) {
          _models = models;
        } else if (localIds.isNotEmpty) {
          _models = localIds;
        }
        final current = _modelController.text.trim();
        if (current.isEmpty && _models.isNotEmpty) {
          _modelController.text = _models.first;
        }
      });
    } catch (_) {
      if (mounted && _models.isEmpty && localIds.isNotEmpty) {
        setState(() => _models = localIds);
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  void _submit() {
    final model = _modelController.text.trim();
    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择或输入模型 ID')),
      );
      return;
    }
    Navigator.pop(
      context,
      AiModelBindingSelection(
        provider: _selectedProfile,
        modelName: model,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfiles) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final suggested = widget.suggestedModel?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggested.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AiBrandTokens.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: AiBrandTokens.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '作者推荐模型：$suggested',
                    style: AiTheme.caption.copyWith(
                      color: AiBrandTokens.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _profiles.any((p) => p.id == _profileId)
                    ? _profileId
                    : AiProviderProfile.builtinBackendId,
                isExpanded: true,
                decoration: AiTheme.inputDecoration(labelText: 'API 来源'),
                items: _profiles
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    _profileId = value;
                    _models = _selectedProfile.effectiveModelIds;
                  });
                  await AiProviderService().saveLastSelectedProfileId(value);
                  await _loadModels(background: true);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '管理 API 来源',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiProviderProfilesPage(),
                  ),
                );
                await _bootstrap();
              },
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _modelController,
          style: AiTheme.mono,
          decoration: AiTheme.inputDecoration(
            labelText: '绑定模型 ID',
            hintText: 'gpt-4o-mini / deepseek-chat',
          ),
          onFieldSubmitted: (_) => _submit(),
        ),
        if (_loadingModels)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AiBrandTokens.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text('加载模型列表…', style: AiTheme.caption),
              ],
            ),
          ),
        if (_models.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('快捷选择', style: AiTheme.caption),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _models.take(12).map((id) {
              final selected = _modelController.text.trim() == id;
              return FilterChip(
                label: Text(id, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) {
                  setState(() => _modelController.text = id);
                },
                selectedColor:
                    AiBrandTokens.primary.withValues(alpha: 0.15),
                checkmarkColor: AiBrandTokens.primary,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AiBrandTokens.primary,
                ),
                onPressed: _submit,
                child: const Text('开始聊天'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
