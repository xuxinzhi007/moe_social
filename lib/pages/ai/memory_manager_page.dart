import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../models/ai_agent.dart';
import '../../models/ai_memory.dart';
import '../../models/ai_memory_profile.dart';
import '../../models/ai_memory_settings.dart';
import '../../services/ai_db_service.dart';
import '../../services/api_service.dart';
import '../../services/llm_endpoint_config.dart';
import '../../services/memory_agent_service.dart';
import '../../widgets/moe_toast.dart';

class MemoryManagerPage extends StatefulWidget {
  final AiAgent agent;

  const MemoryManagerPage({super.key, required this.agent});

  @override
  State<MemoryManagerPage> createState() => _MemoryManagerPageState();
}

class _MemoryManagerPageState extends State<MemoryManagerPage> {
  List<AiMemory> _memories = [];
  List<AiMemoryProfile> _profiles = [];
  AiMemorySettings? _settings;
  List<String> _models = [];
  bool _isLoading = true;
  bool _isSavingSettings = false;
  bool _isCurating = false;
  bool _isBuildingPrompt = false;
  bool _showFullPrompt = false;
  String _filterCategory = 'all';
  String _promptPreview = '';

  final _categories = [
    ('all', '全部', '📋'),
    ('preference', '偏好', '❤️'),
    ('habit', '习惯', '🔄'),
    ('reminder', '提醒', '⏰'),
    ('personal', '个人信息', '👤'),
    ('general', '一般', '📝'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = AiDbService();
    final memoryAgent = MemoryAgentService();
    final list = await db.getMemories(widget.agent.id);
    final profiles = await db.getMemoryProfiles(widget.agent.id);
    final settings = await memoryAgent.getOrCreateSettings(widget.agent);
    final models = await _loadModels();
    final promptPreview = await memoryAgent.buildInjectedPrompt(widget.agent);
    if (mounted) {
      setState(() {
        _memories = list;
        _profiles = profiles;
        _settings = settings;
        _models = models;
        _promptPreview = promptPreview;
        _isLoading = false;
      });
    }
  }

  Future<List<String>> _loadModels() async {
    try {
      final uri = await LlmEndpointConfig.modelsUri();
      ApiService.logDirectHttp('GET', uri);
      final response = await http
          .get(uri, headers: ApiService.mergeTunnelHeaders(uri))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [widget.agent.modelName];
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data['models'] is List) {
        final raw = data['models'] as List;
        final list = raw.whereType<String>().isNotEmpty
            ? raw.whereType<String>().toList()
            : raw
                .whereType<Map>()
                .map((m) => m['name'])
                .whereType<String>()
                .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [widget.agent.modelName];
  }

  Future<void> _persistSettings(AiMemorySettings settings) async {
    setState(() => _isSavingSettings = true);
    await AiDbService().upsertMemorySettings(
      settings.copyWith(updatedAt: DateTime.now()),
    );
    if (mounted) {
      setState(() {
        _settings = settings.copyWith(updatedAt: DateTime.now());
        _isSavingSettings = false;
      });
    }
    await _refreshPromptPreview(showLoading: false);
  }

  Future<void> _refreshPromptPreview({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isBuildingPrompt = true);
    }
    try {
      final prompt =
          await MemoryAgentService().buildInjectedPrompt(widget.agent);
      if (mounted) {
        setState(() {
          _promptPreview = prompt;
        });
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, '刷新提示词失败：$e');
      }
    } finally {
      if (showLoading && mounted) {
        setState(() => _isBuildingPrompt = false);
      }
    }
  }

  Future<void> _curateNow() async {
    if (_isCurating) return;
    setState(() => _isCurating = true);
    try {
      await MemoryAgentService().curateProfiles(agent: widget.agent);
      await _load();
      if (!mounted) return;
      MoeToast.success(context, '记忆画像已重新整理');
    } catch (e) {
      if (!mounted) return;
      MoeToast.error(context, '整理失败：$e');
    } finally {
      if (mounted) setState(() => _isCurating = false);
    }
  }

  List<AiMemory> get _filtered {
    if (_filterCategory == 'all') return _memories;
    return _memories.where((m) => m.category == _filterCategory).toList();
  }

  Future<void> _delete(AiMemory memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记忆'),
        content: Text('确定要删除这条记忆吗？\n\n"${memory.content}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AiDbService().deleteMemory(memory.id);
      await _load();
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有记忆'),
        content: Text(
            '确定要清空「${widget.agent.name}」的所有 ${_memories.length} 条记忆吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('全部清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AiDbService().clearMemories(widget.agent.id);
      await _load();
    }
  }

  Future<void> _addManually() async {
    final controller = TextEditingController();
    String selectedCategory = 'general';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          return AlertDialog(
            title: const Text('手动添加记忆'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '记忆内容',
                    hintText: '例如：用户喜欢晚上10点后聊天',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _categories
                      .where((c) => c.$1 != 'all')
                      .map((c) => DropdownMenuItem(
                            value: c.$1,
                            child: Text('${c.$3} ${c.$2}'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedCategory = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('添加')),
            ],
          );
        });
      },
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      final now = DateTime.now();
      final mem = AiMemory(
        id: now.millisecondsSinceEpoch.toString(),
        agentId: widget.agent.id,
        content: controller.text.trim(),
        category: selectedCategory,
        importance: 3,
        createdAt: now,
        updatedAt: now,
      );
      await AiDbService().insertMemory(mem);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final settings = _settings;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('记忆库', style: TextStyle(fontSize: 16)),
            Text(
              widget.agent.name,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_memories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: '清空全部记忆',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading || settings == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildProfilesCard(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildSettingsCard(settings),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildPromptPreviewCard(settings),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      children: _categories.map((c) {
                        final (id, label, emoji) = c;
                        final count = id == 'all'
                            ? _memories.length
                            : _memories.where((m) => m.category == id).length;
                        if (count == 0 && id != 'all') {
                          return const SizedBox.shrink();
                        }
                        final selected = _filterCategory == id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('$emoji $label ($count)'),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _filterCategory = id),
                            selectedColor: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.2),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildMemoryCard(filtered[i]),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "memory_manager_add_button",
        onPressed: _addManually,
        icon: const Icon(Icons.add),
        label: const Text('手动添加'),
      ),
    );
  }

  Widget _buildProfilesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                '长期画像（${_profiles.length}）',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isCurating ? null : _curateNow,
                icon: _isCurating
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('整理'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_profiles.isEmpty)
            Text(
              '还没有整理后的用户画像。新增几条记忆后，点击“整理”即可生成更稳定的长期摘要。',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.5,
              ),
            )
          else
            ..._profiles.map((profile) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                profile.profileType,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '置信度 ${(profile.confidence * 100).clamp(0, 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.summary,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(AiMemorySettings settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18),
              const SizedBox(width: 8),
              const Text(
                '记忆设置',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_isSavingSettings)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: settings.extractModel,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '记忆提取模型',
              border: OutlineInputBorder(),
            ),
            items: _models
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              _persistSettings(settings.copyWith(extractModel: v));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: settings.curateModel,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '记忆整理模型',
              border: OutlineInputBorder(),
            ),
            items: _models
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              _persistSettings(settings.copyWith(curateModel: v));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: settings.injectMode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '记忆注入模式',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'profile_plus_top_raw',
                child: Text('画像 + 高优先级原始记忆'),
              ),
              DropdownMenuItem(
                value: 'profile_only',
                child: Text('仅画像摘要'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              _persistSettings(settings.copyWith(injectMode: v));
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '原始记忆注入条数上限',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${settings.maxInjectedRawItems}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: 12,
            divisions: 12,
            value: settings.maxInjectedRawItems.toDouble().clamp(0, 12),
            onChanged: settings.injectMode == 'profile_only'
                ? null
                : (value) {
                    _persistSettings(
                      settings.copyWith(maxInjectedRawItems: value.round()),
                    );
                  },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动提取记忆'),
            value: settings.autoExtract,
            onChanged: (v) =>
                _persistSettings(settings.copyWith(autoExtract: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动整理画像'),
            subtitle: const Text('每累计一定数量的新记忆时自动执行'),
            value: settings.autoCurate,
            onChanged: (v) =>
                _persistSettings(settings.copyWith(autoCurate: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptPreviewCard(AiMemorySettings settings) {
    final preview = _promptPreview.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_snippet_rounded, size: 18),
              const SizedBox(width: 8),
              const Text(
                '当前生效提示词',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed:
                    _isBuildingPrompt ? null : () => _refreshPromptPreview(),
                tooltip: '刷新预览',
                icon: _isBuildingPrompt
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
              ),
              IconButton(
                onPressed: preview.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: preview));
                        if (!mounted) return;
                        MoeToast.success(context, '提示词已复制');
                      },
                tooltip: '复制',
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '模型：${widget.agent.modelName}  ·  注入模式：${settings.injectMode}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              preview.isEmpty ? '暂无提示词预览，点击右上角刷新。' : preview,
              maxLines: _showFullPrompt ? null : 12,
              overflow:
                  _showFullPrompt ? TextOverflow.visible : TextOverflow.fade,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _showFullPrompt = !_showFullPrompt);
              },
              child: Text(_showFullPrompt ? '收起' : '展开全部'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧠', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            _filterCategory == 'all' ? '还没有任何记忆' : '该分类暂无记忆',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _filterCategory == 'all' ? '和 AI 聊天时，它会自动记住重要信息' : '切换到"全部"查看所有记忆',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(AiMemory memory) {
    final (label, emoji) = AiMemory.categoryMeta(memory.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类别 emoji
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _categoryColor(memory.category).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.content,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _categoryColor(memory.category)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                              fontSize: 11,
                              color: _categoryColor(memory.category)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 重要性星星
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < memory.importance
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 11,
                            color: i < memory.importance
                                ? Colors.amber
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(memory.updatedAt),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 删除按钮
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.grey.shade400),
              onPressed: () => _delete(memory),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    return switch (category) {
      'preference' => Colors.pink,
      'reminder' => Colors.orange,
      'habit' => Colors.teal,
      'personal' => Colors.blue,
      _ => Colors.grey,
    };
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
