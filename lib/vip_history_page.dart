import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/vip_record.dart';

class VipHistoryPage extends StatefulWidget {
  const VipHistoryPage({super.key});

  @override
  State<VipHistoryPage> createState() => _VipHistoryPageState();
}

class _VipHistoryPageState extends State<VipHistoryPage> {
  List<VipRecord> _records = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _pageSize = 10;
  int _total = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _records = [];
        _hasMore = true;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getVipHistory(
        userId,
        page: _currentPage,
        pageSize: _pageSize,
      );

      setState(() {
        if (refresh) {
          _records = result['records'] as List<VipRecord>;
        } else {
          _records.addAll(result['records'] as List<VipRecord>);
        }
        _total = result['total'] as int;
        _hasMore = _records.length < _total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载历史记录失败: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    setState(() {
      _currentPage++;
    });
    await _loadHistory();
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return '生效中';
      case 'expired':
        return '已过期';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VIP历史记录'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadHistory(refresh: true),
        child: _isLoading && _records.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          '暂无历史记录',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _records.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _records.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: _loadMore,
                                    child: const Text('加载更多'),
                                  ),
                          ),
                        );
                      }

                      final record = _records[index];
                      return _buildRecordCard(record);
                    },
                  ),
      ),
    );
  }

  Widget _buildRecordCard(VipRecord record) {
    final isActive = record.isActive;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.planName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '记录ID: ${record.id}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(record.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        _getStatusText(record.status),
                        style: TextStyle(
                          color: _getStatusColor(record.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '开始时间',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.startAtDateTime != null
                            ? '${record.startAtDateTime!.year}-${record.startAtDateTime!.month.toString().padLeft(2, '0')}-${record.startAtDateTime!.day.toString().padLeft(2, '0')}'
                            : record.startAt,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '结束时间',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.endAtDateTime != null
                            ? '${record.endAtDateTime!.year}-${record.endAtDateTime!.month.toString().padLeft(2, '0')}-${record.endAtDateTime!.day.toString().padLeft(2, '0')}'
                            : record.endAt,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (record.createdAtDateTime != null) ...[
              const SizedBox(height: 12),
              Text(
                '创建时间: ${record.createdAtDateTime!.year}-${record.createdAtDateTime!.month.toString().padLeft(2, '0')}-${record.createdAtDateTime!.day.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

