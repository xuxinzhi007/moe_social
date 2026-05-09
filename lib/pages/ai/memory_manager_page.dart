import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../auth_service.dart';
import '../../models/ai_agent.dart';
import '../../models/user_memory.dart';
import '../../models/user_memory_profile.dart';
import '../../services/api_service.dart';
import '../../services/llm_endpoint_config.dart';
import '../../services/memory_service.dart';
import '../../widgets/moe_toast.dart';

class MemoryManagerPage extends StatefulWidget {
  final AiAgent agent;

  const MemoryManagerPage({super.key, required this.agent});

  @override
  State<MemoryManagerPage> createState() => _MemoryManagerPageState();
}

class _MemoryManagerPageState extends State<MemoryManagerPage> {
  List<UserMemory> _memories = [];
  List<UserMemoryProfile> _profiles = [];
  Map<String, dynamic>? _llmConfig;
  bool _terminalModeEnabled = false;
  bool _isLoading = true;
  bool _isBuildingPrompt = false;
  bool _showFullPrompt = false;
  String _promptPreview = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getUserInfo();
      final paged = await MemoryService.getUserMemoriesPaged(user.id,
          limit: 100, offset: 0);
      final memories = (paged['items'] as List<UserMemory>? ?? const []);
      memories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final profiles = await MemoryService.getUserMemoryProfiles(user.id);
      final terminal = await LlmEndpointConfig.isTerminalModeEnabled();
      final llmConfig = await _loadLlmConfig();
      final preview = _buildPromptPreview(memories);
      if (mounted) {
        setState(() {
          _memories = memories;
          _profiles = profiles;
          _terminalModeEnabled = terminal;
          _llmConfig = llmConfig;
          _promptPreview = preview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (mounted) {
        MoeToast.error(context, '加载失败：$e');
      }
    }
  }

  Future<Map<String, dynamic>> _loadLlmConfig() async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/llm/config');
    ApiService.logDirectHttp('GET', uri);
    final response = await http
        .get(
          uri,
          headers: ApiService.mergeTunnelHeaders(uri, headers: {
            if (ApiService.token case final t?) 'Authorization': 'Bearer $t',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return const {};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! Map) return const {};
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  String _buildPromptPreview(List<UserMemory> memories) {
    final base = widget.agent.systemPrompt.isNotEmpty
        ? widget.agent.systemPrompt
        : '你是一位友好、智能的 AI 助手。';
    final lines = memories.take(8).map((m) {
      final type =
          (m.memoryType?.isNotEmpty == true) ? m.memoryType! : 'general';
      return '- [$type] ${m.value}';
    }).join('\n');
    if (lines.isEmpty) {
      return '$base\n\n（当前暂无可注入记忆）';
    }
    return '$base\n\n用户长期背景与偏好（后端注入示意）：\n$lines';
  }

  Future<void> _refreshPromptPreview({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isBuildingPrompt = true);
    try {
      final user = await AuthService.getUserInfo();
      final paged = await MemoryService.getUserMemoriesPaged(user.id,
          limit: 100, offset: 0);
      final memories = (paged['items'] as List<UserMemory>? ?? const []);
      memories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final profiles = await MemoryService.getUserMemoryProfiles(user.id);
      final prompt = _buildPromptPreview(memories);
      if (mounted) {
        setState(() {
          _memories = memories;
          _profiles = profiles;
          _promptPreview = prompt;
        });
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, '刷新提示词失败：$e');
      }
    } finally {
      if (showLoading && mounted) setState(() => _isBuildingPrompt = false);
    }
  }

  Future<void> _delete(UserMemory memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记忆'),
        content: Text('确定要删除这条记忆吗？\n\n"${memory.value}"'),
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
      await MemoryService.deleteUserMemoryByKey(memory.userId, memory.key);
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
      if (_memories.isEmpty) return;
      for (final m in _memories) {
        await MemoryService.deleteUserMemoryByKey(m.userId, m.key);
      }
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _llmConfig?['runtime'];
    final serverMemoryEnabled = runtime is Map
        ? runtime['server_memory_enabled'] == true
        : !_terminalModeEnabled;

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
      body: _isLoading
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
                    child: _buildRuntimeCard(serverMemoryEnabled),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildPromptPreviewCard(),
                  ),
                ),
                if (_memories.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildMemoryCard(_memories[i]),
                        childCount: _memories.length,
                      ),
                    ),
                  ),
              ],
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
            ],
          ),
          const SizedBox(height: 6),
          if (_profiles.isEmpty)
            Text(
              '还没有可展示画像。继续聊天后，后端会基于记忆逐步形成稳定画像。',
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
                          profile.memoryType,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '聚合条目 ${profile.itemCount}',
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

  Widget _buildRuntimeCard(bool serverMemoryEnabled) {
    final memoryBudget = _llmConfig?['memory_budget'];
    final maxItems = memoryBudget is Map
        ? '${memoryBudget['max_injected_memory_items'] ?? '-'}'
        : '-';
    final maxRunes = memoryBudget is Map
        ? '${memoryBudget['max_injected_memory_runes'] ?? '-'}'
        : '-';
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
              const Icon(Icons.settings_suggest_rounded, size: 18),
              const SizedBox(width: 8),
              const Text(
                '后端记忆运行状态',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildKV('终端同款(raw)模式', _terminalModeEnabled ? '已开启' : '已关闭'),
          _buildKV('服务端记忆生效', serverMemoryEnabled ? '是' : '否'),
          _buildKV('后端注入条数上限', maxItems),
          _buildKV('后端注入字符上限', maxRunes),
          const SizedBox(height: 8),
          Text(
            '说明：本页仅展示后端状态，聊天主链路已不再使用本地 SQLite 记忆注入。',
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildKV(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPromptPreviewCard() {
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
            '模型：${widget.agent.modelName}  ·  来源：后端用户记忆',
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
            '还没有任何账号记忆',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '和 AI 聊天时，后端会自动提取并保存记忆。',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(UserMemory memory) {
    final label = (memory.memoryType?.isNotEmpty == true)
        ? memory.memoryType!
        : 'general';
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
                color: _typeColor(label).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: const Text('🧠', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.value,
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
                          color: _typeColor(label).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style:
                              TextStyle(fontSize: 11, color: _typeColor(label)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (memory.confidence != null)
                        Text(
                          '置信度 ${(memory.confidence! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
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

  Color _typeColor(String type) {
    return switch (type) {
      'preference' => Colors.pinkAccent,
      'plan' => Colors.orange,
      'fact' => Colors.teal,
      'identity' => Colors.blue,
      _ => Colors.grey,
    };
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr.replaceFirst(' ', 'T'));
    if (date == null) return dateStr;
    final dt = date.toLocal();
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
