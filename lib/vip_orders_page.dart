import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/vip_order.dart';

class VipOrdersPage extends StatefulWidget {
  const VipOrdersPage({super.key});

  @override
  State<VipOrdersPage> createState() => _VipOrdersPageState();
}

class _VipOrdersPageState extends State<VipOrdersPage> {
  List<VipOrder> _orders = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _pageSize = 10;
  int _total = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders({bool refresh = false}) async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _orders = [];
        _hasMore = true;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getVipOrders(
        userId,
        page: _currentPage,
        pageSize: _pageSize,
      );

      setState(() {
        if (refresh) {
          _orders = result['orders'] as List<VipOrder>;
        } else {
          _orders.addAll(result['orders'] as List<VipOrder>);
        }
        _total = result['total'] as int;
        _hasMore = _orders.length < _total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载订单失败: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    setState(() {
      _currentPage++;
    });
    await _loadOrders();
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '待支付';
      case 'paid':
        return '已支付';
      case 'cancelled':
        return '已取消';
      case 'expired':
        return '已过期';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      case 'expired':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VIP订单'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadOrders(refresh: true),
        child: _isLoading && _orders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          '暂无订单',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _orders.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _orders.length) {
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

                      final order = _orders[index];
                      return _buildOrderCard(order);
                    },
                  ),
      ),
    );
  }

  Widget _buildOrderCard(VipOrder order) {
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
                        order.planName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '订单号: ${order.id}',
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
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '订单金额',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${order.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '创建时间',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.createdAtDateTime != null
                          ? '${order.createdAtDateTime!.year}-${order.createdAtDateTime!.month.toString().padLeft(2, '0')}-${order.createdAtDateTime!.day.toString().padLeft(2, '0')}'
                          : order.createdAt,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (order.paidAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '支付时间: ${order.paidAtDateTime != null ? '${order.paidAtDateTime!.year}-${order.paidAtDateTime!.month.toString().padLeft(2, '0')}-${order.paidAtDateTime!.day.toString().padLeft(2, '0')}' : order.paidAt}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

