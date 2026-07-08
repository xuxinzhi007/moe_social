import 'package:flutter/material.dart';

import '../../models/ai_lorebook.dart';
import '../../models/ai_lorebook_entry.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../widgets/ai/ai_confirm_sheet.dart';
import '../../widgets/ai/ai_highlight_card.dart';
import '../../widgets/ai/ai_list_tile_card.dart';
import '../../widgets/ai/ai_scaffold.dart';
import '../../widgets/ai/ai_sheet.dart';
import '../../widgets/ai/ai_theme.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

class AiLorebookEditorPage extends StatefulWidget {
  const AiLorebookEditorPage({super.key, this.lorebook});

  final AiLorebook? lorebook;

  @override
  State<AiLorebookEditorPage> createState() => _AiLorebookEditorPageState();
}

class _AiLorebookEditorPageState extends State<AiLorebookEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  List<AiLorebookEntry> _entries = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.lorebook?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.lorebook?.description ?? '',
    );
    _loadEntries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final lorebook = widget.lorebook;
    if (lorebook == null) return;
    setState(() => _loading = true);
    try {
      final cloudEntries =
          await AiAgentCloudService().getLorebookEntries(lorebook.id);
      if (!mounted) return;
      setState(() {
        _entries = cloudEntries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      MoeToast.error(context, '加载设定条目失败：$e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final lorebook = AiLorebook(
        id: widget.lorebook?.id ?? now.millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: widget.lorebook?.createdAt ?? now,
        updatedAt: now,
      );
      final normalizedEntries = _entries
          .map((entry) =>
              entry.copyWith(lorebookId: lorebook.id, updatedAt: now))
          .toList();
      if (widget.lorebook == null) {
        await AiAgentCloudService().saveLorebook(lorebook, normalizedEntries);
      } else {
        await AiAgentCloudService().updateLorebook(lorebook, normalizedEntries);
      }
      if (!mounted) return;
      MoeToast.success(context, '世界书已保存');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      MoeToast.error(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showEntryEditor({AiLorebookEntry? initial}) async {
    final titleController = TextEditingController(text: initial?.title ?? '');
    final contentController =
        TextEditingController(text: initial?.content ?? '');
    final keywordsController = TextEditingController(
      text: (initial?.keywords ?? const <String>[]).join(', '),
    );
    var enabled = initial?.enabled ?? true;
    var alwaysEnabled = initial?.alwaysEnabled ?? false;
    var priority = (initial?.priority ?? 50).toDouble();

    await AiSheet.show<void>(
      context: context,
      title: initial == null ? '新增设定条目' : '编辑设定条目',
      child: StatefulBuilder(
        builder: (ctx, setLocalState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: AiTheme.inputDecoration(
                labelText: '标题',
                hintText: '例如：银月城',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keywordsController,
              decoration: AiTheme.inputDecoration(
                labelText: '触发关键词',
                hintText: '逗号或换行分隔',
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              minLines: 5,
              maxLines: 8,
              decoration: AiTheme.inputDecoration(
                labelText: '内容',
                hintText: '世界观设定、人物关系、规则等',
                alignLabelWithHint: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用条目'),
              value: enabled,
              onChanged: (v) => setLocalState(() => enabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('始终注入'),
              subtitle: const Text('忽略关键词，每次发送都带上'),
              value: alwaysEnabled,
              onChanged: (v) => setLocalState(() => alwaysEnabled = v),
            ),
            Text('优先级 ${priority.round()}', style: AiTheme.caption),
            Slider(
              min: 0,
              max: 100,
              divisions: 20,
              value: priority,
              label: '${priority.round()}',
              onChanged: (v) => setLocalState(() => priority = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: AiTheme.primaryButtonStyle(),
              onPressed: () {
                final content = contentController.text.trim();
                if (content.isEmpty) {
                  MoeToast.error(context, '设定内容不能为空');
                  return;
                }
                final now = DateTime.now();
                final entry = AiLorebookEntry(
                  id: initial?.id ?? now.microsecondsSinceEpoch.toString(),
                  lorebookId: widget.lorebook?.id ?? '',
                  title: titleController.text.trim(),
                  content: content,
                  keywords: _parseKeywords(keywordsController.text),
                  enabled: enabled,
                  alwaysEnabled: alwaysEnabled,
                  priority: priority.round(),
                  createdAt: initial?.createdAt ?? now,
                  updatedAt: now,
                );
                setState(() {
                  final idx =
                      _entries.indexWhere((item) => item.id == entry.id);
                  if (idx == -1) {
                    _entries = [..._entries, entry];
                  } else {
                    final next = [..._entries];
                    next[idx] = entry;
                    _entries = next;
                  }
                  _entries.sort((a, b) => b.priority.compareTo(a.priority));
                });
                Navigator.pop(ctx);
              },
              child: const Text('保存条目'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    contentController.dispose();
    keywordsController.dispose();
  }

  Future<void> _deleteEntry(AiLorebookEntry entry) async {
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '删除设定条目',
      message: '确定删除「${entry.title.isEmpty ? '未命名条目' : entry.title}」吗？',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (!confirmed) return;
    setState(() {
      _entries = _entries.where((item) => item.id != entry.id).toList();
    });
  }

  List<String> _parseKeywords(String raw) {
    return raw
        .split(RegExp(r'[\n,，]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.lorebook == null;
    return AiScaffold(
      title: isNew ? '新建世界书' : '编辑世界书',
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEntryEditor(),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('新增条目'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AiTheme.pagePadding),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: AiTheme.inputDecoration(
                labelText: '名称',
                hintText: '例如：赛博都市世界观',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: AiTheme.inputDecoration(
                labelText: '描述',
                hintText: '适用于哪些角色或场景',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            const AiHighlightCard(
              icon: Icons.tips_and_updates_outlined,
              title: '注入规则',
              body: '始终注入 > 关键词命中 > 优先级；聊天时自动挑选并写入系统提示词。',
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: MoeLoading()),
              )
            else if (_entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '还没有设定条目，先添加地点、角色关系、世界规则等内容。',
                  textAlign: TextAlign.center,
                  style: AiTheme.caption,
                ),
              )
            else
              ..._entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AiTheme.sectionGap),
                  child: AiListTileCard(
                    title: entry.title.isEmpty ? '未命名条目' : entry.title,
                    subtitle: [
                      if (entry.keywords.isNotEmpty)
                        '关键词：${entry.keywords.join(' / ')}',
                      '优先级 ${entry.priority}'
                          '${entry.alwaysEnabled ? ' · 始终注入' : ''}'
                          '${entry.enabled ? '' : ' · 已停用'}',
                      entry.content,
                    ].join('\n'),
                    tags: entry.keywords.take(3).toList(),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _showEntryEditor(initial: entry);
                        } else if (value == 'delete') {
                          await _deleteEntry(entry);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
