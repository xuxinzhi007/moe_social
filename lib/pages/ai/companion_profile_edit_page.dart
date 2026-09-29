import 'package:flutter/material.dart';

import '../../services/companion_character_card_import.dart';
import '../../services/companion_service.dart';
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
  late final TextEditingController _personaController;
  late final TextEditingController _agentIdController;
  late final TextEditingController _traitsController;
  late final TextEditingController _systemPromptController;
  late String _greetingStyle;
  late String _avatarUrl;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final current = widget.initial;
    _nameController = TextEditingController(text: current.name);
    _emojiController = TextEditingController(text: current.emoji);
    _personaController = TextEditingController(text: current.persona);
    _agentIdController = TextEditingController(text: current.agentId);
    _traitsController = TextEditingController(
      text: current.personalityTraits.join('，'),
    );
    _systemPromptController = TextEditingController(
      text: current.systemPromptOverride,
    );
    _greetingStyle =
        current.greetingStyle.isNotEmpty ? current.greetingStyle : 'warm';
    _avatarUrl = current.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _personaController.dispose();
    _agentIdController.dispose();
    _traitsController.dispose();
    _systemPromptController.dispose();
    super.dispose();
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
    if (draft.persona.isNotEmpty) {
      _personaController.text = draft.persona;
    }
    if (draft.personalityTraits.isNotEmpty) {
      _traitsController.text = draft.personalityTraits.join('，');
    }
    if (draft.systemPromptOverride.isNotEmpty) {
      _systemPromptController.text = draft.systemPromptOverride;
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
          '人设已填入，但头像上传失败：${e.toString().replaceFirst('Exception: ', '')}',
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
                  '仅写入名字 / 人设 / 性格 / 提示词；不导入世界书，不创建酒馆角色。',
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

  void _save() {
    if (_uploadingAvatar) return;
    final traits = _traitsController.text
        .split(RegExp(r'[，,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    Navigator.pop(
      context,
      widget.initial.copyWith(
        name: _nameController.text.trim(),
        emoji: _emojiController.text.trim().isEmpty
            ? '🐾'
            : _emojiController.text.trim(),
        avatarUrl: _avatarUrl.trim(),
        persona: _personaController.text.trim(),
        agentId: _agentIdController.text.trim(),
        personalityTraits: traits,
        greetingStyle: _greetingStyle,
        systemPromptOverride: _systemPromptController.text.trim(),
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
                  title: '怎么相处',
                  children: [
                    _ProfileField(
                      controller: _emojiController,
                      label: '表情',
                      hint: '没有头像时显示',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _ProfileField(
                      controller: _personaController,
                      label: '人设',
                      hint: '一句话描述气质',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '问候风格',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MoeTokens.hintText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GreetingChoices(
                      value: _greetingStyle,
                      onChanged: (value) =>
                          setState(() => _greetingStyle = value),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '进阶',
                  children: [
                    _ProfileField(
                      controller: _traitsController,
                      label: '性格标签',
                      hint: '温暖，好奇，幽默',
                    ),
                    const SizedBox(height: 12),
                    _ProfileField(
                      controller: _agentIdController,
                      label: 'Agent ID',
                      hint: '可选',
                      maxLength: 64,
                    ),
                    const SizedBox(height: 12),
                    _ProfileField(
                      controller: _systemPromptController,
                      label: '提示词',
                      hint: '留空则使用默认',
                      maxLines: 4,
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
                onTap: _save,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: AnimatedContainer(
                  duration: MoeTokens.motionFast,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient:
                        _uploadingAvatar ? null : MoeTokens.gradientPrimary,
                    color: _uploadingAvatar ? MoeTokens.softChipBg : null,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  ),
                  child: Text(
                    _uploadingAvatar ? '头像上传中…' : '保存',
                    style: TextStyle(
                      color:
                          _uploadingAvatar ? MoeTokens.hintText : Colors.white,
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
                hintText: '例如：啾啾',
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

class _GreetingChoices extends StatelessWidget {
  const _GreetingChoices({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = <(String, String)>[
    ('warm', '温暖'),
    ('playful', '俏皮'),
    ('calm', '沉静'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: MoePressable(
              onTap: () => onChanged(_options[i].$1),
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              child: AnimatedContainer(
                duration: MoeTokens.motionFast,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: value == _options[i].$1
                      ? MoeTokens.gradientPrimary
                      : null,
                  color: value == _options[i].$1 ? null : MoeTokens.softChipBg,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: Text(
                  _options[i].$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: value == _options[i].$1
                        ? Colors.white
                        : MoeTokens.hintText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MoeTokens.hintText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: MoeTokens.titleText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: const TextStyle(
              color: MoeTokens.hintText,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: MoeTokens.softChipBg,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
              borderSide: const BorderSide(color: MoeTokens.primary),
            ),
          ),
        ),
      ],
    );
  }
}
