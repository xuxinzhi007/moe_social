import 'package:flutter/material.dart';

import '../../models/ai_agent.dart';
import '../../models/user_memory.dart';
import '../../models/user_memory_display.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_confirm_sheet.dart';
import '../../widgets/ai/ai_highlight_card.dart';
import '../../widgets/ai/ai_scaffold.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import 'state/memory_manager_controller.dart';

class MemoryManagerPage extends StatefulWidget {
  final AiAgent agent;

  const MemoryManagerPage({super.key, required this.agent});

  @override
  State<MemoryManagerPage> createState() => _MemoryManagerPageState();
}

class _MemoryManagerPageState extends State<MemoryManagerPage> {
  late final MemoryManagerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MemoryManagerController(widget.agent);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _controller.load();
    } catch (e) {
      if (mounted) MoeToast.error(context, '加载失败：$e');
    }
  }

  Future<void> _delete(UserMemory memory) async {
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '删除这条记忆',
      message: '确定删除「${memory.value}」吗？',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (confirmed) {
      await _controller.deleteAccountMemory(memory);
    }
  }

  Future<void> _clearAll() async {
    final count = _controller.displayItems.length;
    if (count == 0) return;
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '清空全部记忆',
      message: '确定清空全部 $count 条记忆吗？此操作不可撤销。',
      confirmLabel: '全部清空',
      isDanger: true,
    );
    if (confirmed) {
      await _controller.clearAccountMemories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return AiScaffold(
          title: '关于你的记忆',
          subtitle: widget.agent.name,
          backgroundColor: AiBrandTokens.pageBackground,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: '清空全部',
              onPressed: c.displayItems.isEmpty ? null : _clearAll,
            ),
          ],
          body: c.isLoading
              ? const Center(child: MoeLoading())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: AiHighlightCard(
                            icon: Icons.favorite_rounded,
                            title: c.headline.isNotEmpty
                                ? c.headline
                                : '关于你的记忆',
                            body: c.memoryPaused
                                ? '当前为开发者调试模式，记忆已暂停。正常使用时无需任何设置。'
                                : '这些内容会在聊天时自动被 AI 参考。你可以删除不准确的项目。',
                          ),
                        ),
                      ),
                      if (c.displayProfiles.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _buildProfilesSection(c.displayProfiles),
                          ),
                        ),
                      if (c.displayItems.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmpty(c.memoryPaused),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final item = c.displayItems[i];
                                final memory = i < c.accountMemories.length
                                    ? c.accountMemories[i]
                                    : null;
                                return _buildDisplayCard(
                                  item,
                                  onDelete: memory == null
                                      ? null
                                      : () => _delete(memory),
                                );
                              },
                              childCount: c.displayItems.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildProfilesSection(List<UserMemoryDisplayProfile> profiles) {
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
          const Text(
            'AI 对你的了解',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...profiles.map(
            (p) => Padding(
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
                      p.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.summary,
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

  Widget _buildEmpty(bool paused) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧠', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              paused ? '记忆功能已暂停' : '还没有记住的内容',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              paused
                  ? '关闭开发者调试模式后即可恢复。'
                  : '多聊几句，AI 会自动记住你的偏好、称呼和重要信息。',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayCard(
    UserMemoryDisplayItem item, {
    VoidCallback? onDelete,
  }) {
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AiBrandTokens.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: AiBrandTokens.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(item.updatedAt),
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
            if (onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
                onPressed: onDelete,
                tooltip: '删除',
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr.replaceFirst(' ', 'T'));
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.month}/${local.day}';
  }
}
