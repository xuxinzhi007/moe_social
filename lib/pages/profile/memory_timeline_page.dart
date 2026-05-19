import 'package:flutter/material.dart';
import '../../models/user_memory.dart';
import '../../models/user_memory_display.dart';
import '../../services/memory_service.dart';
import '../../auth_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/moe_toast.dart';

class MemoryTimelinePage extends StatefulWidget {
  const MemoryTimelinePage({super.key});

  @override
  State<MemoryTimelinePage> createState() => _MemoryTimelinePageState();
}

class _MemoryTimelinePageState extends State<MemoryTimelinePage> {
  UserMemoryDisplayData? _display;
  List<UserMemory> _memories = [];
  bool _isLoading = true;
  String? _error;
  bool _hasMore = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = await AuthService.getUserInfo();
      final display = await MemoryService.getUserMemoriesDisplay(user.id);
      final memories = display.items
          .map(
            (item) => UserMemory(
              id: item.id,
              userId: user.id,
              key: item.key,
              value: item.content,
              memoryType: item.category,
              createdAt: item.updatedAt,
              updatedAt: item.updatedAt,
            ),
          )
          .toList();
      setState(() {
        _display = display;
        _memories = memories;
        _hasMore = false;
        _total = display.total;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMemory(UserMemory memory) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记忆'),
        content: Text('确定要删除「${memory.value}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await MemoryService.deleteUserMemoryByKey(memory.userId, memory.key);
        if (mounted) {
          MoeToast.success(context, '记忆已删除');
          _loadMemories(); // Reload list
        }
      } catch (e) {
        if (mounted) {
          MoeToast.error(context, '删除失败: $e');
        }
      }
    }
  }

  Future<void> _feedbackMemory(
    UserMemory memory, {
    required String feedbackType,
    String? correctedValue,
    String? reason,
  }) async {
    try {
      await MemoryService.submitUserMemoryFeedback(
        userId: memory.userId,
        key: memory.key,
        feedbackType: feedbackType,
        correctedValue: correctedValue,
        reason: reason,
      );
      if (!mounted) return;
      switch (feedbackType) {
        case 'accept':
          MoeToast.success(context, '已标记为有效记忆');
          break;
        case 'reject':
          MoeToast.success(context, '已标记为低质量记忆');
          break;
        case 'correct':
          MoeToast.success(context, '记忆已纠正');
          break;
      }
      await _loadMemories();
    } catch (e) {
      if (mounted) MoeToast.error(context, '反馈失败: $e');
    }
  }

  Future<void> _showCorrectDialog(UserMemory memory) async {
    final valueController = TextEditingController(text: memory.value);
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('纠正记忆'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('键：${memory.key}'),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '正确记忆值',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '说明（可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('提交纠正'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final corrected = valueController.text.trim();
    if (corrected.isEmpty) {
      if (mounted) MoeToast.error(context, '纠正内容不能为空');
      return;
    }
    await _feedbackMemory(
      memory,
      feedbackType: 'correct',
      correctedValue: corrected,
      reason: reasonController.text.trim(),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final normalized = dateStr.replaceFirst(' ', 'T');
      final date = DateTime.parse(normalized).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title:
            const Text('关于你的记忆', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMemories,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMemories,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final profiles = _display?.profiles ?? const [];
    if (_memories.isEmpty && profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.memory, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无记忆', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_display?.headline.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _display!.headline,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        _buildProfileCard(profiles),
        const SizedBox(height: 12),
        if (_memories.isEmpty)
          Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '暂无可展示的模型记忆（设备同步类记录已自动隐藏）',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ..._memories.map(_buildMemoryCard),
      ],
    );
  }

  Widget _buildProfileCard(List<UserMemoryDisplayProfile> profiles) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_alt_rounded,
                    size: 18, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'AI 对你的了解',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 10),
            if (profiles.isEmpty)
              Text(
                '暂无可聚合画像，继续聊天后会逐步形成。',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              )
            else
              ...profiles.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.summary,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            if (_total > 0)
              Text(
                '共 $_total 条',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(UserMemory memory) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    memory.memoryType ?? '了解',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.grey, size: 20),
                  onPressed: () => _deleteMemory(memory),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              memory.value,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                  tooltip: '认可',
                  onPressed: () =>
                      _feedbackMemory(memory, feedbackType: 'accept'),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                  tooltip: '驳回',
                  onPressed: () =>
                      _feedbackMemory(memory, feedbackType: 'reject'),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: '纠正',
                  onPressed: () => _showCorrectDialog(memory),
                  visualDensity: VisualDensity.compact,
                ),
                Icon(Icons.access_time_rounded,
                    size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(memory.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
