import 'package:flutter/material.dart';
import '../../models/user_memory.dart';
import '../../models/user_memory_profile.dart';
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
  List<UserMemory> _memories = [];
  List<UserMemoryProfile> _profiles = [];
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
      final paged = await MemoryService.getUserMemoriesPaged(
        user.id,
        limit: 100,
        offset: 0,
      );
      final rawMemories = (paged['items'] as List<UserMemory>? ?? const []);
      final memories = MemoryService.filterUserFacingMemories(rawMemories);
      final profiles = await MemoryService.getUserMemoryProfiles(user.id);
      // Sort memories by created_at descending (newest first)
      memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _memories = memories;
        _profiles = profiles;
        _hasMore = paged['has_more'] == true;
        _total = memories.length;
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
        content: Text('确定要删除这条记忆吗？\nKey: ${memory.key}'),
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
            const Text('模型记忆线', style: TextStyle(fontWeight: FontWeight.bold)),
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

    if (_memories.isEmpty && _profiles.isEmpty) {
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
        _buildProfileCard(_profiles),
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

  Widget _buildProfileCard(List<UserMemoryProfile> profiles) {
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
                  '账号画像摘要（后端记忆聚合）',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '当前账号的画像由数据库记忆实时聚合，跨端共享，不依赖本地缓存。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
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
                          '${p.memoryType} · ${p.itemCount}条',
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
            Text(
              _hasMore
                  ? '已加载 ${_memories.length}/$_total 条，更多请分页查看。'
                  : '共 $_total 条账号记忆。',
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
                Icon(Icons.vpn_key_rounded,
                    size: 16, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    memory.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
            if ((memory.source?.isNotEmpty == true) ||
                (memory.sessionId?.isNotEmpty == true) ||
                (memory.sourceMsgId?.isNotEmpty == true)) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (memory.source?.isNotEmpty == true) '来源: ${memory.source}',
                  if (memory.sessionId?.isNotEmpty == true)
                    '会话: ${memory.sessionId}',
                  if (memory.sourceMsgId?.isNotEmpty == true)
                    '消息: ${memory.sourceMsgId}',
                ].join('  |  '),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (memory.memoryType != null && memory.memoryType!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      memory.memoryType!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF4F46E5)),
                    ),
                  ),
                const SizedBox(width: 8),
                if (memory.confidence != null)
                  Text(
                    '置信度 ${(memory.confidence! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
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
