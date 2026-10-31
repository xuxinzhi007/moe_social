import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../models/vip_order.dart';
import '../../services/commerce_service.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/moe_button.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

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
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders({bool refresh = false}) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _orders = [];
        _hasMore = true;
        _error = null;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CommerceService.getVipOrders(
        userId,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _orders = result['orders'] as List<VipOrder>;
        } else {
          _orders.addAll(result['orders'] as List<VipOrder>);
        }
        _total = result['total'] as int;
        _hasMore = _orders.length < _total;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
      if (_orders.isNotEmpty) {
        MoeToast.error(context, '加载订单失败: $e');
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
        return MoeTokens.warning;
      case 'paid':
        return MoeTokens.success;
      case 'cancelled':
        return MoeTokens.hintText;
      case 'expired':
        return MoeTokens.danger;
      default:
        return MoeTokens.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      title: 'VIP 订单',
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: () => _loadOrders(refresh: true),
        child: _isLoading && _orders.isEmpty
            ? const Center(child: MoeLoading())
            : _error != null && _orders.isEmpty
                ? Center(
                    child: MoeErrorState.fromError(
                      _error,
                      scene: MoeErrorScene.generic,
                      onRetry: () => _loadOrders(refresh: true),
                    ),
                  )
                : _orders.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          MoeEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: '暂无 VIP 订单',
                            subtitle: '开通会员后的订单详情会展示在这里',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _orders.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _orders.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: _isLoading
                                    ? const MoeSmallLoading()
                                    : MoeSecondaryButton(
                                        label: '加载更多',
                                        onPressed: _loadMore,
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
    final statusColor = _getStatusColor(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowCard(),
      ),
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
                        fontSize: MoeTokens.textMd,
                        fontWeight: FontWeight.w700,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (order.orderNo != null &&
                              order.orderNo!.trim().isNotEmpty)
                          ? '订单号: ${order.orderNo}'
                          : '订单编号: ${order.id}',
                      style: const TextStyle(
                        color: MoeTokens.inkMuted,
                        fontSize: MoeTokens.textXs,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: Text(
                  _getStatusText(order.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: MoeTokens.textXs,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: MoeTokens.lineSoft),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '订单金额',
                    style: TextStyle(
                        color: MoeTokens.hintText, fontSize: MoeTokens.textXs),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${order.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: MoeTokens.textXl,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '创建时间',
                    style: TextStyle(
                        color: MoeTokens.hintText, fontSize: MoeTokens.textXs),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.createdAtDateTime != null
                        ? '${order.createdAtDateTime!.year}-${order.createdAtDateTime!.month.toString().padLeft(2, '0')}-${order.createdAtDateTime!.day.toString().padLeft(2, '0')}'
                        : order.createdAt,
                    style: const TextStyle(
                      fontSize: MoeTokens.textSm,
                      color: MoeTokens.bodyText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
