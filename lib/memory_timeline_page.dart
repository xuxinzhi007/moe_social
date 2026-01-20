import 'package:flutter/material.dart';
import 'models/user_memory.dart';
import 'models/user.dart';
import 'services/memory_service.dart';
import 'auth_service.dart';
import 'package:intl/intl.dart';

class MemoryTimelinePage extends StatefulWidget {
  const MemoryTimelinePage({super.key});

  @override
  State<MemoryTimelinePage> createState() => _MemoryTimelinePageState();
}

class _MemoryTimelinePageState extends State<MemoryTimelinePage> {
  List<UserMemory> _memories = [];
  bool _isLoading = true;
  String? _error;

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
      if (user != null) {
        final memories = await MemoryService.getUserMemories(user.id);
        // Sort memories by created_at descending (newest first)
        memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _memories = memories;
        });
      } else {
        setState(() {
          _error = '未登录';
        });
      }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('记忆已删除')),
          );
          _loadMemories(); // Reload list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
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
        title: const Text('模型记忆线', style: TextStyle(fontWeight: FontWeight.bold)),
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

    if (_memories.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _memories.length,
      itemBuilder: (context, index) {
        final memory = _memories[index];
        return _buildMemoryCard(memory);
      },
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
                Icon(Icons.vpn_key_rounded, size: 16, color: Theme.of(context).primaryColor),
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
                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
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
