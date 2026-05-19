import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_agent.dart';
import '../../models/user_memory.dart';
import '../../models/user_memory_profile.dart';
import '../../models/ai_memory.dart';
import '../../models/ai_memory_profile.dart';
import '../../services/ai_memory_orchestrator.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_confirm_sheet.dart';
import '../../widgets/moe_toast.dart';

class MemoryManagerPage extends StatefulWidget {
  final AiAgent agent;

  const MemoryManagerPage({super.key, required this.agent});

  @override
  State<MemoryManagerPage> createState() => _MemoryManagerPageState();
}

class _MemoryManagerPageState extends State<MemoryManagerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<UserMemory> _memories = [];
  List<UserMemoryProfile> _profiles = [];
  List<AiMemory> _localMemories = [];
  List<AiMemoryProfile> _localProfiles = [];
  String _activeModeLabel = '未启用';
  String _activeModeDescription = '';
  Map<String, dynamic>? _llmConfig;
  bool _terminalModeEnabled = false;
  bool _isLoading = true;
  bool _isBuildingPrompt = false;
  bool _showFullPrompt = false;
  String _promptPreview = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final state = await AiMemoryOrchestrator().loadManagerState(widget.agent);
      if (mounted) {
        setState(() {
          _memories = state.accountMemories;
          _profiles = state.accountProfiles;
          _localMemories = state.localMemories;
          _localProfiles = state.localProfiles;
          _activeModeLabel = state.activeModeLabel;
          _activeModeDescription = state.activeModeDescription;
          _terminalModeEnabled = state.terminalModeEnabled;
          _llmConfig = state.llmConfig;
          _promptPreview = state.promptPreview;
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

  Future<void> _refreshPromptPreview({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isBuildingPrompt = true);
    try {
      final prompt = await AiMemoryOrchestrator().buildPromptPreview(
        agent: widget.agent,
        basePrompt: widget.agent.systemPrompt.isNotEmpty
            ? widget.agent.systemPrompt
            : '你是一位友好、智能的 AI 助手。',
      );
      if (mounted) {
        setState(() => _promptPreview = prompt);
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
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '删除记忆',
      message: '确定要删除这条记忆吗？\n\n"${memory.value}"',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (confirmed) {
      await AiMemoryOrchestrator().deleteAccountMemory(memory);
      await _load();
    }
  }

  Future<void> _deleteLocal(AiMemory memory) async {
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '删除本地记忆',
      message: '确定要删除这条本地记忆吗？\n\n"${memory.content}"',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (confirmed) {
      await AiMemoryOrchestrator().deleteLocalMemory(memory.id);
      await _load();
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '清空所有记忆',
      message:
          '确定要清空「${widget.agent.name}」的所有 ${_memories.length} 条记忆吗？\n此操作不可撤销。',
      confirmLabel: '全部清空',
      isDanger: true,
    );
    if (confirmed) {
      if (_tabController.index == 0) {
        if (_memories.isEmpty) return;
        await AiMemoryOrchestrator().clearAllAccountMemories(_memories);
      } else {
        if (_localMemories.isEmpty) return;
        for (final m in _localMemories) {
          await AiMemoryOrchestrator().deleteLocalMemory(m.id);
        }
      }
      await _load();
    }
  }

  Future<void> _clearAllLocal() async {
    if (_localMemories.isEmpty) return;
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '清空本地记忆',
      message: '确定清空 ${_localMemories.length} 条本地角色记忆吗？',
      confirmLabel: '全部清空',
      isDanger: true,
    );
    if (confirmed) {
      for (final m in _localMemories) {
        await AiMemoryOrchestrator().deleteLocalMemory(m.id);
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
      backgroundColor: AiBrandTokens.chatBackground,
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
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: '清空当前 Tab 记忆',
            onPressed: () {
              if (_tabController.index == 0) {
                _clearAll();
              } else {
                _clearAllLocal();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '账号记忆 (${_memories.length})'),
            Tab(text: '本地角色 (${_localMemories.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildModeCard(),
                  ),
                ),
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
                if (_tabController.index == 0)
                  if (_memories.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(account: true),
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
                    )
                else if (_localMemories.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(account: false),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildLocalMemoryCard(_localMemories[i]),
                        childCount: _localMemories.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildModeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1A7F7FD5), Color(0x1491EAE4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x337F7FD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前聊天记忆模式：$_activeModeLabel',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            _activeModeDescription,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesCard() {
    final isAccountTab = _tabController.index == 0;
    final profileCount =
        isAccountTab ? _profiles.length : _localProfiles.length;
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
                isAccountTab
                    ? '账号画像（$profileCount）'
                    : '本地画像（$profileCount）',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (profileCount == 0)
            Text(
              isAccountTab
                  ? '还没有可展示画像。继续聊天后，服务端会基于记忆逐步形成稳定画像。'
                  : '本地画像会在多轮对话后由系统自动整理。',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.5,
              ),
            )
          else if (isAccountTab)
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
                ))
          else
            ..._localProfiles.map(
              (profile) => Padding(
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
                        profile.title.isNotEmpty
                            ? profile.title
                            : profile.profileType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
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
              ),
            ),
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
            '说明：服务端记忆在聊天时自动注入；关闭 Provider「服务端记忆」时使用本机智能体记忆。',
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

  Widget _buildEmpty({required bool account}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧠', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            account ? '还没有任何账号记忆' : '还没有本地角色记忆',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            account
                ? '和 AI 聊天时，服务端会自动提取并保存账号记忆。'
                : '关闭服务端记忆时，对话会在此积累本机角色记忆。',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
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

  Widget _buildLocalMemoryCard(AiMemory memory) {
    final label = memory.category;
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _typeColor(label).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('📌', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _typeColor(label).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: _typeColor(label),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDateTime(memory.updatedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Colors.grey.shade400,
              ),
              onPressed: () => _deleteLocal(memory),
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
    return _formatDateTime(date);
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
