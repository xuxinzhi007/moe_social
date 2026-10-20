import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/ai_cloud_config_service.dart';
import '../../services/companion_character_card_import.dart';
import '../../services/companion_service.dart';
import '../../services/llm_api_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/companion_avatar.dart';
import '../../widgets/moe_action_row.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_pressable.dart';
import 'companion_avatar_studio_page.dart';

/// 伙伴资料编辑页。从伙伴首页头像进入，保存后把更新后的资料带回上一页。
class CompanionProfileEditPage extends StatefulWidget {
  const CompanionProfileEditPage({super.key, required this.initial});

  final CompanionProfileData initial;

  @override
  State<CompanionProfileEditPage> createState() =>
      _CompanionProfileEditPageState();
}

class _CompanionProfileEditPageState extends State<CompanionProfileEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  late final TextEditingController _modelPromptController;
  late String _avatarUrl;
  bool _uploadingAvatar = false;
  bool _promptLoading = true;
  bool _promptEditable = false;
  bool _saving = false;
  String _modelName = '';
  String _promptNote = '正在读取当前模型的系统提示词';
  String _loadedPrompt = '';
  LlmManagedModel? _managed;

  @override
  void initState() {
    super.initState();
    final current = widget.initial;
    _nameController = TextEditingController(text: current.name);
    _emojiController = TextEditingController(text: current.emoji);
    _modelPromptController = TextEditingController();
    _avatarUrl = current.avatarUrl;
    unawaited(_loadModelPrompt());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _modelPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadModelPrompt() async {
    try {
      final snapshot = await AiCloudConfigService().fetch();
      final model =
          snapshot?.preferences['builtin_chat_model']?.toString().trim() ?? '';
      final catalog = await LlmApiService.fetchCatalog();
      LlmCatalogModel? current;
      for (final item in catalog) {
        if (item.name == model) {
          current = item;
          break;
        }
      }
      final derived = current?.derived == true;
      LlmManagedModel? managed;
      if (derived) {
        final owned = await LlmApiService.listManagedModels();
        for (final item in owned) {
          if (item.modelName == model && item.state == 'ready') {
            managed = item;
            break;
          }
        }
      }
      final card = model.isEmpty
          ? const LlmModelCard(systemPrompt: '', parameters: {})
          : await LlmApiService.fetchModelCard(model);
      if (!mounted) return;
      setState(() {
        _modelName = model;
        _managed = managed;
        _promptEditable = managed != null;
        _loadedPrompt = card.systemPrompt;
        _modelPromptController.text = card.systemPrompt;
        _promptLoading = false;
        _promptNote = model.isEmpty
            ? '还没有选模型。到聊天页顶栏切换。'
            : _promptEditable
                ? '这是你的派生模型，可以改。换模型在聊天页。'
                : '这是当前模型自带的系统提示词，这里不能改。换模型在聊天页。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _promptLoading = false;
        _promptEditable = false;
        _promptNote = '提示词没有读到：$error';
      });
    }
  }

  Future<void> _editName() async {
    final next = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: _nameController.text),
    );
    if (!mounted || next == null) return;
    setState(() => _nameController.text = next.trim());
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CompanionAvatarStudioPage(
          emoji: _emojiController.text,
          avatarUrl: _avatarUrl,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _avatarUrl = result);
  }

  Future<void> _applyCardDraft(CompanionCardImportDraft draft) async {
    _nameController.text = draft.name;
    final imported = draft.systemPromptOverride.trim().isNotEmpty
        ? draft.systemPromptOverride.trim()
        : draft.persona.trim();
    if (_promptEditable && imported.isNotEmpty) {
      _modelPromptController.text = imported;
    }
    setState(() {});

    final png = draft.avatarPngBytes;
    if (png != null && png.isNotEmpty) {
      setState(() => _uploadingAvatar = true);
      try {
        final url = await CompanionService().uploadAvatarBytes(
          png,
          filename: 'character_card.png',
        );
        if (!mounted) return;
        setState(() {
          _avatarUrl = url;
          _uploadingAvatar = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        MoeToast.error(
          context,
          '名字已填入，但头像上传失败：${e.toString().replaceFirst('Exception: ', '')}',
        );
        return;
      }
    }
    if (!mounted) return;
    MoeToast.success(context, '已从${draft.sourceLabel}填入，确认后点保存');
  }

  Future<void> _importFromFile() async {
    try {
      final draft = await CompanionCharacterCardImport.fromFilePicker();
      if (!mounted) return;
      await _applyCardDraft(draft);
    } on CompanionCardImportCancelled {
      return;
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _importFromPaste() async {
    final pasteController = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('粘贴角色卡 JSON'),
          content: TextField(
            controller: pasteController,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '粘贴 SillyTavern / Moe 角色卡 JSON',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, pasteController.text),
              child: const Text('解析'),
            ),
          ],
        );
      },
    );
    pasteController.dispose();
    if (raw == null || !mounted) return;
    try {
      final draft = CompanionCharacterCardImport.fromJsonString(raw);
      await _applyCardDraft(draft);
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _showImportPicker() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AiBrandTokens.pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '从角色卡导入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AiBrandTokens.titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '只更新名字和头像。派生模型才会把角色卡写进提示词。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: MoeTokens.spaceMd),
                MoeActionRow(
                  icon: Icons.folder_open_rounded,
                  title: '选择 JSON / PNG 文件',
                  iconColor: MoeTokens.primary,
                  onTap: () => Navigator.pop(ctx, 'file'),
                ),
                MoeActionRow(
                  icon: Icons.content_paste_rounded,
                  title: '粘贴 JSON',
                  iconColor: MoeTokens.primary,
                  onTap: () => Navigator.pop(ctx, 'paste'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'file') {
      await _importFromFile();
    } else if (action == 'paste') {
      await _importFromPaste();
    }
  }

  Future<void> _save() async {
    if (_uploadingAvatar || _saving) return;
    final nextPrompt = _modelPromptController.text.trim();
    if (_promptEditable &&
        _managed != null &&
        nextPrompt != _loadedPrompt.trim()) {
      setState(() => _saving = true);
      try {
        await LlmApiService.upsertAgentPrompt(
          agentId: _managed!.agentId,
          requestId: DateTime.now().microsecondsSinceEpoch.toString(),
          baseModel: _managed!.baseModel,
          systemPrompt: nextPrompt,
        );
      } catch (error) {
        if (!mounted) return;
        setState(() => _saving = false);
        MoeToast.error(context, '提示词没有保存：$error');
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      widget.initial.copyWith(
        name: _nameController.text.trim(),
        avatarUrl: _avatarUrl.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim().isEmpty
        ? '还没有名字'
        : _nameController.text.trim();
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('编辑伙伴'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: MoeTokens.titleText,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: '导入角色卡',
            onPressed: _uploadingAvatar ? null : _showImportPicker,
            icon: const Icon(Icons.badge_outlined, size: 22),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _IdentityCard(
              name: name,
              emoji: _emojiController.text,
              avatarUrl: _avatarUrl,
              uploading: _uploadingAvatar,
              onPickAvatar: _pickAvatar,
              onEditName: _editName,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                _SectionCard(
                  title: '模型提示词',
                  children: [
                    Text(
                      _modelName.isEmpty ? '当前没有选中的模型' : _modelName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _promptNote,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: MoeTokens.hintText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_promptLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      TextField(
                        controller: _modelPromptController,
                        readOnly: !_promptEditable,
                        maxLines: 8,
                        minLines: 4,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: _promptEditable
                              ? MoeTokens.titleText
                              : MoeTokens.hintText,
                        ),
                        decoration: InputDecoration(
                          hintText: '这个模型没有写系统提示词',
                          filled: true,
                          fillColor: MoeTokens.softChipBg,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(MoeTokens.radiusLg),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: MoePressable(
                onTap: (_uploadingAvatar || _saving) ? null : _save,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: AnimatedContainer(
                  duration: MoeTokens.motionFast,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: (_uploadingAvatar || _saving)
                        ? null
                        : MoeTokens.gradientPrimary,
                    color: (_uploadingAvatar || _saving)
                        ? MoeTokens.softChipBg
                        : null,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  ),
                  child: Text(
                    _saving
                        ? '保存中…'
                        : _uploadingAvatar
                            ? '头像上传中…'
                            : '保存',
                    style: TextStyle(
                      color: (_uploadingAvatar || _saving)
                          ? MoeTokens.hintText
                          : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.emoji,
    required this.avatarUrl,
    required this.uploading,
    required this.onPickAvatar,
    required this.onEditName,
  });

  final String name;
  final String emoji;
  final String avatarUrl;
  final bool uploading;
  final VoidCallback onPickAvatar;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFE7FF), Color(0xFFFBE8F0), Color(0xFFF8F3E7)],
        ),
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          MoePressable(
            onTap: uploading ? null : onPickAvatar,
            borderRadius: BorderRadius.circular(18),
            child: CompanionAvatar(
              emoji: emoji,
              avatarUrl: avatarUrl,
              size: 56,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MoePressable(
              onTap: onEditName,
              borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.titleText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MoeTokens.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '名称',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MoeTokens.titleText,
              ),
              decoration: InputDecoration(
                hintText: '例如：小星',
                isDense: true,
                filled: true,
                fillColor: MoeTokens.softChipBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submit,
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: MoeTokens.titleText,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
