import 'package:flutter/material.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/models/gift_purchase_order.dart';
import 'package:moe_social/models/vip_order.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/widgets/moe_toast.dart';
import 'package:moe_social/pages/commerce/wallet_page.dart';

/// 订单中心：礼物购买订单、VIP 订单、钱包流水摘要
class OrderCenterPage extends StatefulWidget {
  const OrderCenterPage({super.key});

  @override
  State<OrderCenterPage> createState() => _OrderCenterPageState();
}

class _OrderCenterPageState extends State<OrderCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('订单中心', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF7F7FD5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF7F7FD5),
          tabs: const [
            Tab(text: '礼物订单'),
            Tab(text: 'VIP订单'),
            Tab(text: '钱包流水'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _GiftPurchaseOrdersTab(),
          _VipOrdersTab(),
          _WalletTransactionsTab(),
        ],
      ),
    );
  }
}

class _GiftPurchaseOrdersTab extends StatefulWidget {
  const _GiftPurchaseOrdersTab();

  @override
  State<_GiftPurchaseOrdersTab> createState() => _GiftPurchaseOrdersTabState();
}

class _GiftPurchaseOrdersTabState extends State<_GiftPurchaseOrdersTab> {
  final List<GiftPurchaseOrder> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    final uid = AuthService.currentUser;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    if (refresh) {
      _page = 1;
      _items.clear();
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;

    setState(() => _loading = true);
    try {
      final r = await ApiService.getGiftPurchaseOrders(uid,
          page: _page, pageSize: _pageSize);
      final list = r['orders'] as List<GiftPurchaseOrder>;
      final total = r['total'] as int;
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _items
            ..clear()
            ..addAll(list);
        } else {
          _items.addAll(list);
        }
        _total = total;
        _hasMore = _items.length < _total;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        MoeToast.error(context, '加载失败: $e');
      }
    }
  }

  Future<void> _more() async {
    if (!_hasMore || _loading) return;
    _page++;
    await _load(refresh: false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser;
    if (uid == null) {
      return const Center(child: Text('请先登录'));
    }
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.card_giftcard, size: 56, color: Color(0xFFCCCCCC)),
            SizedBox(height: 12),
            Center(child: Text('暂无礼物购买订单')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: _more,
                  child: const Text('加载更多'),
                ),
              ),
            );
          }
          final o = _items[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.giftName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '¥${o.totalAmount.toStringAsFixed(o.totalAmount == o.totalAmount.roundToDouble() ? 0 : 2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.pink[400],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('订单号 ${o.orderNo}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(
                    '单价 ¥${o.unitPrice.toStringAsFixed(2)} × ${o.quantity}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        o.payMethod == 'wallet' ? '心意支付' : o.payMethod,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        o.createdAt,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VipOrdersTab extends StatefulWidget {
  const _VipOrdersTab();

  @override
  State<_VipOrdersTab> createState() => _VipOrdersTabState();
}

class _VipOrdersTabState extends State<_VipOrdersTab> {
  final List<VipOrder> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _hasMore = true;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    final uid = AuthService.currentUser;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    if (refresh) {
      _page = 1;
      _items.clear();
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;

    setState(() => _loading = true);
    try {
      final r = await ApiService.getVipOrders(uid, page: _page, pageSize: _pageSize);
      final list = r['orders'] as List<VipOrder>;
      final total = r['total'] as int;
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _items
            ..clear()
            ..addAll(list);
        } else {
          _items.addAll(list);
        }
        _total = total;
        _hasMore = _items.length < _total;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        MoeToast.error(context, '加载失败: $e');
      }
    }
  }

  Future<void> _more() async {
    if (!_hasMore || _loading) return;
    _page++;
    await _load(refresh: false);
  }

  String _statusText(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return '待支付';
      case 'paid':
        return '已支付';
      case 'cancelled':
        return '已取消';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser;
    if (uid == null) {
      return const Center(child: Text('请先登录'));
    }
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.workspace_premium_outlined,
                size: 56, color: Color(0xFFCCCCCC)),
            SizedBox(height: 12),
            Center(child: Text('暂无 VIP 订单')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: _more,
                  child: const Text('加载更多'),
                ),
              ),
            );
          }
          final o = _items[i];
          final on = (o.orderNo ?? '').trim();
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.planName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusText(o.status),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    on.isNotEmpty ? '订单号 $on' : '订单编号 ${o.id}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¥${o.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        o.createdAt,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WalletTransactionsTab extends StatefulWidget {
  const _WalletTransactionsTab();

  @override
  State<_WalletTransactionsTab> createState() => _WalletTransactionsTabState();
}

class _WalletTransactionsTabState extends State<_WalletTransactionsTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.currentUser;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ApiService.getTransactions(uid, page: 1, pageSize: 30);
      final raw = r['data'] as List;
      final parsed = raw.map((t) {
        final m = Map<String, dynamic>.from(t as Map);
        final a = m['amount'];
        if (a is int) m['amount'] = a.toDouble();
        if (a is String) m['amount'] = double.tryParse(a) ?? 0.0;
        return m;
      }).toList();
      if (mounted) {
        setState(() {
          _rows = parsed;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        MoeToast.error(context, '加载失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser;
    if (uid == null) {
      return const Center(child: Text('请先登录'));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const WalletPage(),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
              label: const Text('打开完整钱包与充值'),
            ),
          ),
        ),
        Expanded(
          child: _rows.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      Center(child: Text('暂无流水')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = _rows[i];
                      final type = t['type'] as String? ?? '';
                      final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
                      final desc =
                          t['description'] as String? ?? (type == 'recharge' ? '充值' : '消费');
                      final sign = type == 'recharge' ? '+' : '-';
                      return Card(
                        child: ListTile(
                          title: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(t['created_at'] as String? ?? ''),
                          trailing: Text(
                            '$sign${amt.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: type == 'recharge'
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
