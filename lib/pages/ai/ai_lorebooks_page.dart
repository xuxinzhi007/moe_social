import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_lorebook.dart';
import '../../models/ai_lorebook_entry.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_db_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_confirm_sheet.dart';
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
  bool _syncingCloud = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _loadLocalFirst();
    _syncFromCloud();
  }

  Future<void> _loadLocalFirst() async {
    try {
      final local = await AiDbService().getLorebooks();
      if (local.isEmpty) {
        if (!mounted) return;
        setState(() {
          _lorebooks = local;
          _entryCounts = {};
        });
        return;
      }
      final counts = await Future.wait(
        local.map((lorebook) async {
          final entries = await AiDbService().getLorebookEntries(lorebook.id);
          return MapEntry(lorebook.id, entries.length);
        }),
      );
      if (!mounted) return;
      setState(() {
        _lorebooks = local;
        _entryCounts = Map<String, int>.fromEntries(counts);
      });
    } catch (_) {
      // 本地读取失败不阻塞页面，云端同步仍会尝试
    }
  }

  Future<void> _syncFromCloud() async {
    if (!mounted) return;
    setState(() {
      _syncingCloud = true;
      _syncError = null;
    });
    try {
      final snapshot = await AiAgentCloudService().syncLorebooksFromCloud();
      if (!mounted) return;
      setState(() {
        _lorebooks = snapshot.lorebooks;
        _entryCounts = snapshot.entryCounts;
        _syncingCloud = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncingCloud = false;
        _syncError = e.toString();
      });
    }
  }

  Future<void> _load() async {
    await _loadLocalFirst();
    await _syncFromCloud();
  }

  Future<void> _deleteLorebook(AiLorebook lorebook) async {
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '删除 Lorebook',
      message: '确定删除「${lorebook.name}」及其全部设定条目吗？',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (!confirmed) return;
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

  Future<void> _applyStarterLorebookTemplate({
    AiStarterLorebookTemplate? preset,
  }) async {
    if (preset != null) {
      await _createLorebookFromTemplate(preset);
      return;
    }
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
    await _createLorebookFromTemplate(template);
  }

  Future<void> _createLorebookFromTemplate(
    AiStarterLorebookTemplate template,
  ) async {
    HapticFeedback.lightImpact();
    final lorebook = AiStarterTemplates.buildLorebookFromTemplate(template);
    final entries = AiStarterTemplates.buildLorebookEntriesFromTemplate(
      template,
      lorebookId: lorebook.id,
    );
    await AiAgentCloudService().saveLorebook(lorebook, entries);
    if (!mounted) return;
    MoeToast.success(context, '已创建「${template.name}」');
    await _load();
  }

  Widget _buildStarterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '默认可用模板',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AiBrandTokens.titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '无需等待云端同步，点一下即可创建完整世界书。',
          style:
              TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 12),
        ...AiStarterTemplates.lorebookTemplates.map((template) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _applyStarterLorebookTemplate(preset: template),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AiBrandTokens.primary.withValues(alpha: 0.18),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        AiBrandTokens.primary.withValues(alpha: 0.06),
                        AiBrandTokens.accent.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AiBrandTokens.heroGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${template.description} · ${template.entries.length} 条设定',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.add_circle_outline_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSyncBanner() {
    if (_syncingCloud) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AiBrandTokens.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AiBrandTokens.primary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '正在同步云端世界书…',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }
    if (_syncError != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 18, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '云端同步失败，已显示本地数据。可下拉刷新重试。',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
            ),
            TextButton(
              onPressed: _syncFromCloud,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: const Text('Lorebook 世界书'),
        backgroundColor: AiBrandTokens.pageBackground,
        actions: [
          TextButton.icon(
            onPressed: _applyStarterLorebookTemplate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('更多模板'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildSyncBanner(),
            _buildStarterSection(),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  '我的世界书',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AiBrandTokens.titleColor,
                  ),
                ),
                const Spacer(),
                if (_lorebooks.isNotEmpty)
                  Text(
                    '${_lorebooks.length} 本',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lorebooks.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '还没有自建 Lorebook',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '可从上方模板一键创建，或使用右下角「新建」。',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              )
            else
              ..._lorebooks.map((lorebook) {
                final count = _entryCounts[lorebook.id] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    margin: EdgeInsets.zero,
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
                          PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 72),
          ],
        ),
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
