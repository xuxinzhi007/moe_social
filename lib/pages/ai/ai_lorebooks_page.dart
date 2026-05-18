import 'package:flutter/material.dart';

import '../../models/ai_lorebook.dart';
import '../../models/ai_lorebook_entry.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

class AiLorebooksPage extends StatefulWidget {
  const AiLorebooksPage({super.key});

  @override
  State<AiLorebooksPage> createState() => _AiLorebooksPageState();
}

class _AiLorebooksPageState extends State<AiLorebooksPage> {
  List<AiLorebook> _lorebooks = [];
  Map<String, int> _entryCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cloudLorebooks = await AiAgentCloudService().getLorebooks();
      final counts = <String, int>{};
      for (final lorebook in cloudLorebooks) {
        counts[lorebook.id] =
            (await AiAgentCloudService().getLorebookEntries(lorebook.id)).length;
      }
      if (!mounted) return;
      setState(() {
        _lorebooks = cloudLorebooks;
        _entryCounts = counts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      MoeToast.error(context, '加载 Lorebook 失败：$e');
    }
  }

  Future<void> _deleteLorebook(AiLorebook lorebook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Lorebook'),
        content: Text('确定删除「${lorebook.name}」及其全部设定条目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AiAgentCloudService().deleteLorebook(lorebook.id);
    if (!mounted) return;
    MoeToast.success(context, 'Lorebook 已删除');
    await _load();
  }

  Future<void> _openEditor({AiLorebook? lorebook}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AiLorebookEditorPage(lorebook: lorebook),
      ),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _applyStarterLorebookTemplate() async {
    final template = await showModalBottomSheet<AiStarterLorebookTemplate>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '选择世界书模板',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '模板会预置世界观、地点、规则与关键词，便于用户参考。',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ...AiStarterTemplates.lorebookTemplates.map(
                (item) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        item.description,
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, item),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (template == null) return;
    final lorebook = AiStarterTemplates.buildLorebookFromTemplate(template);
    final entries = AiStarterTemplates.buildLorebookEntriesFromTemplate(
      template,
      lorebookId: lorebook.id,
    );
    await AiAgentCloudService().saveLorebook(lorebook, entries);
    if (!mounted) return;
    MoeToast.success(context, '默认世界书模板已创建');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lorebook 世界书'),
        actions: [
          TextButton.icon(
            onPressed: _applyStarterLorebookTemplate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('默认模板'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建'),
      ),
      body: _loading
          ? const Center(child: MoeLoading())
          : _lorebooks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '还没有 Lorebook',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '为角色补充世界观、地点、人物关系和规则设定。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lorebooks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lorebook = _lorebooks[index];
                    final count = _entryCounts[lorebook.id] ?? 0;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        onTap: () => _openEditor(lorebook: lorebook),
                        title: Text(
                          lorebook.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            lorebook.description.trim().isEmpty
                                ? '$count 条设定'
                                : '${lorebook.description}\n$count 条设定',
                            style: const TextStyle(height: 1.4),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _openEditor(lorebook: lorebook);
                            } else if (value == 'delete') {
                              await _deleteLorebook(lorebook);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class AiLorebookEditorPage extends StatefulWidget {
  final AiLorebook? lorebook;

  const AiLorebookEditorPage({super.key, this.lorebook});

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
          .map(
            (entry) => entry.copyWith(
              lorebookId: lorebook.id,
              updatedAt: now,
            ),
          )
          .toList();
      if (widget.lorebook == null) {
        await AiAgentCloudService().saveLorebook(lorebook, normalizedEntries);
      } else {
        await AiAgentCloudService().updateLorebook(lorebook, normalizedEntries);
      }
      if (!mounted) return;
      MoeToast.success(context, 'Lorebook 已保存');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      MoeToast.error(context, '保存失败：$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(initial == null ? '新增设定条目' : '编辑设定条目'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '例如：银月城',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keywordsController,
                    decoration: const InputDecoration(
                      labelText: '触发关键词',
                      hintText: '用逗号或换行分隔，例如：银月城, 月港, 首都',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      hintText: '写入需要在对话中被引用的世界观设定、人物关系、规则等',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用条目'),
                    value: enabled,
                    onChanged: (value) {
                      setLocalState(() => enabled = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('始终注入'),
                    subtitle: const Text('忽略关键词，当前会话内每次发送都带上'),
                    value: alwaysEnabled,
                    onChanged: (value) {
                      setLocalState(() => alwaysEnabled = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('优先级 ${priority.round()}'),
                  ),
                  Slider(
                    min: 0,
                    max: 100,
                    divisions: 20,
                    value: priority,
                    label: '${priority.round()}',
                    onChanged: (value) {
                      setLocalState(() => priority = value);
                    },
                  ),
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
                  final idx = _entries.indexWhere((item) => item.id == entry.id);
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
              child: const Text('保存'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除设定条目'),
        content: Text('确定删除「${entry.title.isEmpty ? '未命名条目' : entry.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lorebook == null ? '新建 Lorebook' : '编辑 Lorebook'),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEntryEditor(),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('新增条目'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：赛博都市世界观',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '说明这个 Lorebook 适用于哪些角色或场景',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7F7FD5).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '触发规则：启用条目会按“始终注入 > 关键词命中 > 优先级”排序，聊天时自动挑选并注入到系统提示词。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: MoeLoading()),
              )
            else if (_entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '还没有设定条目，先添加地点、角色关系、世界规则等内容。',
                  style: TextStyle(height: 1.5),
                ),
              )
            else
              ..._entries.map(
                (entry) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      entry.title.isEmpty ? '未命名条目' : entry.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        [
                          if (entry.keywords.isNotEmpty)
                            '关键词：${entry.keywords.join(' / ')}',
                          '优先级：${entry.priority}'
                              '${entry.alwaysEnabled ? ' · 始终注入' : ''}'
                              '${entry.enabled ? '' : ' · 已停用'}',
                          entry.content,
                        ].join('\n'),
                        style: const TextStyle(height: 1.45),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _showEntryEditor(initial: entry);
                        } else if (value == 'delete') {
                          await _deleteEntry(entry);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('编辑'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('删除'),
                        ),
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
