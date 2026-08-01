import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/companion_chat_launcher.dart';
import '../../services/companion_service.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import 'companion_memories_viewmodel.dart';

/// TA 记得的事 — 记忆列表（从关系首页进入）。
class CompanionMemoriesPage extends StatefulWidget {
  const CompanionMemoriesPage({super.key, this.focusMemoryId});

  final int? focusMemoryId;

  @override
  State<CompanionMemoriesPage> createState() => _CompanionMemoriesPageState();
}

class _CompanionMemoriesPageState extends State<CompanionMemoriesPage> {
  late final CompanionMemoriesViewModel _vm;
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _vm = CompanionMemoriesViewModel(focusMemoryId: widget.focusMemoryId);
    _vm.addListener(_onVm);
    unawaited(_vm.load().then((_) => _scrollToFocus()));
  }

  void _onVm() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onVm);
    _vm.dispose();
    super.dispose();
  }

  Future<void> _scrollToFocus() async {
    final id = widget.focusMemoryId;
    if (id == null || id <= 0) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      alignment: 0.15,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openChat() async {
    try {
      await CompanionChatLauncher.openChat(context);
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _togglePin(CompanionMemoryData memory) async {
    try {
      final updated = await _vm.togglePinned(memory);
      if (!mounted) return;
      MoeToast.success(
        context,
        updated.pinned ? '已置顶，不会过期' : '已取消置顶',
      );
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _editContent(CompanionMemoryData memory) async {
    final controller = TextEditingController(text: memory.content);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑这段记忆'),
          content: TextField(
            controller: controller,
            maxLines: 6,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '写下更准确的说法',
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
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (next == null || !mounted) return;
    if (next.isEmpty) {
      MoeToast.error(context, '记忆内容不能为空');
      return;
    }
    if (next == memory.content.trim()) return;
    try {
      await _vm.updateContent(memory, next);
      if (!mounted) return;
      MoeToast.success(context, '记忆已更新');
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _confirmMemory(CompanionMemoryData memory) async {
    try {
      await _vm.confirmMemory(memory);
      if (!mounted) return;
      MoeToast.success(context, '已确认，TA 会更放心地记住这件事');
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _confirmDelete(CompanionMemoryData memory) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('忘记这件事？'),
          content: Text(
            memory.content.trim().isEmpty
                ? '删除后不可恢复。'
                : '「${memory.content.trim()}」\n删除后不可恢复。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await _vm.deleteMemory(memory.id);
      if (!mounted) return;
      MoeToast.success(context, '已从记忆中移除');
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showDetail(CompanionMemoryData memory) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: AiBrandTokens.pageBackground,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _TypeChip(type: memory.memoryType),
                    const SizedBox(width: 8),
                    _ImportanceChip(importance: memory.importance),
                    if (memory.pinned) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: AiBrandTokens.primary,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatTime(memory.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  memory.content.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF5D4E6E),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_openChat());
                  },
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('和 TA 聊聊这件事'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AiBrandTokens.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _vm.isMutating
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_editContent(memory));
                        },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('编辑这段记忆'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _vm.isMutating
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_togglePin(memory));
                        },
                  icon: Icon(
                    memory.pinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                  ),
                  label: Text(memory.pinned ? '取消置顶' : '置顶（永久记住）'),
                ),
                if (!memory.userConfirmed) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _vm.isMutating
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            unawaited(_confirmMemory(memory));
                          },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('确认 TA 记得没错'),
                  ),
                ],
                TextButton.icon(
                  onPressed: _vm.isMutating
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_confirmDelete(memory));
                        },
                  icon: Icon(Icons.delete_outline_rounded,
                      color: Colors.red.shade400),
                  label: Text(
                    '忘记这件事',
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: const Text('TA 记得的事'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AiBrandTokens.titleColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _vm.isLoading ? null : _vm.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('去聊天，留下新记忆'),
            style: FilledButton.styleFrom(
              backgroundColor: AiBrandTokens.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_vm.error != null && _vm.items.isEmpty) {
      return MoeErrorState.fromError(
        _vm.error,
        scene: MoeErrorScene.generic,
        onRetry: _vm.load,
      );
    }
    if (_vm.isLoading && _vm.items.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_vm.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_alt_rounded,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                '还没有记住什么',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AiBrandTokens.titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '多和 TA 聊聊日常，重要的事会被慢慢记住。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _vm.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _vm.items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              '这些是 TA 从聊天里留下的印象，会用于下次对话。',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            );
          }
          final memory = _vm.items[index - 1];
          final key = _itemKeys.putIfAbsent(memory.id, GlobalKey.new);
          final focused =
              widget.focusMemoryId != null && widget.focusMemoryId == memory.id;
          return _MemoryCard(
            key: key,
            memory: memory,
            highlighted: focused,
            onTap: () => _showDetail(memory),
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    super.key,
    required this.memory,
    required this.onTap,
    this.highlighted = false,
  });

  final CompanionMemoryData memory;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? AiBrandTokens.primary.withValues(alpha: 0.45)
                  : const Color(0xFFE8E0F2),
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeChip(type: memory.memoryType),
                  const SizedBox(width: 8),
                  _ImportanceChip(importance: memory.importance),
                  if (memory.pinned) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: AiBrandTokens.primary.withValues(alpha: 0.85),
                    ),
                  ],
                  if (memory.userConfirmed) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Colors.green.shade500,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatTime(memory.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                memory.content.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AiBrandTokens.titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        companionMemoryTypeLabel(type),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7A5A9A),
        ),
      ),
    );
  }
}

class _ImportanceChip extends StatelessWidget {
  const _ImportanceChip({required this.importance});

  final int importance;

  @override
  Widget build(BuildContext context) {
    final label = companionMemoryImportanceLabel(importance);
    final color = importance >= 2
        ? const Color(0xFFE97891)
        : importance == 1
            ? const Color(0xFFE2A54A)
            : const Color(0xFF8A9BB0);
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

String _formatTime(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
