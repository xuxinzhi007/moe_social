import 'package:flutter/material.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/models/gift_purchase_order.dart';
import 'package:moe_social/models/vip_order.dart';
import 'package:moe_social/services/commerce_service.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/moe_button.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

/// 订单中心：礼物购买订单、VIP 订单、钱包流水摘要
class OrderCenterPage extends StatefulWidget {
  const OrderCenterPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<OrderCenterPage> createState() => _OrderCenterPageState();
}

class _OrderCenterPageState extends State<OrderCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    return AdaptivePageScaffold(
      template: PageTemplate.fullscreen,
      backgroundColor: moe.pageBackground,
      body: Scaffold(
        backgroundColor: moe.pageBackground,
        appBar: AppBar(
          title: const Text('订单与明细'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: MoeTokens.softChipBg,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  border: Border.all(color: MoeTokens.surfaceBorder),
                ),
                child: TabBar(
                  controller: _tab,
                  dividerHeight: 0,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: MoeTokens.surface1,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    boxShadow: MoeTokens.shadowSm(),
                  ),
                  labelColor: moe.primary,
                  unselectedLabelColor: MoeTokens.hintText,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: MoeTokens.textSm,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: MoeTokens.textSm,
                  ),
                  tabs: const [
                    Tab(height: 36, text: '礼物订单'),
                    Tab(height: 36, text: '会员订单'),
                    Tab(height: 36, text: '钱包流水'),
                  ],
                ),
              ),
            ),
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
  Object? _error;
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
      _error = null;
    }
    if (!_hasMore && !refresh) return;

    setState(() => _loading = true);
    try {
      final r = await CommerceService.getGiftPurchaseOrders(uid,
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
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
        if (_items.isNotEmpty) {
          MoeToast.error(context, '加载失败: $e');
        }
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
      return const MoeEmptyState(
        icon: Icons.lock_outline_rounded,
        title: '请先登录',
        subtitle: '登录后可查看礼物购买记录',
      );
    }
    if (_loading && _items.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: MoeErrorState.fromError(
          _error,
          scene: MoeErrorScene.generic,
          onRetry: () => _load(refresh: true),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 60),
            MoeEmptyState(
              icon: Icons.card_giftcard_rounded,
              title: '暂无礼物购买订单',
              subtitle: '在好友互动中选购的礼物订单会展示在这里',
            ),
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
                child: _loading
                    ? const MoeSmallLoading()
                    : MoeSecondaryButton(
                        label: '加载更多',
                        onPressed: _more,
                      ),
              ),
            );
          }
          final o = _items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                  children: [
                    Expanded(
                      child: Text(
                        o.giftName,
                        style: const TextStyle(
                          fontSize: MoeTokens.textMd,
                          fontWeight: FontWeight.w700,
                          color: MoeTokens.titleText,
                        ),
                      ),
                    ),
                    Text(
                      '¥${o.totalAmount.toStringAsFixed(o.totalAmount == o.totalAmount.roundToDouble() ? 0 : 2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MoeTokens.primary,
                        fontSize: MoeTokens.textLg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '订单号 ${o.orderNo}',
                  style: const TextStyle(
                    fontSize: MoeTokens.textSm,
                    color: MoeTokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '单价 ¥${o.unitPrice.toStringAsFixed(2)} × ${o.quantity}',
                  style: const TextStyle(
                    fontSize: MoeTokens.textSm,
                    color: MoeTokens.caption,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      o.payMethod == 'wallet' ? '余额支付' : o.payMethod,
                      style: const TextStyle(
                        fontSize: MoeTokens.textXs,
                        color: MoeTokens.hintText,
                      ),
                    ),
                    Text(
                      o.createdAt,
                      style: const TextStyle(
                        fontSize: MoeTokens.textXs,
                        color: MoeTokens.hintText,
                      ),
                    ),
                  ],
                ),
              ],
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
  Object? _error;
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
      _error = null;
    }
    if (!_hasMore && !refresh) return;

    setState(() => _loading = true);
    try {
      final r = await CommerceService.getVipOrders(uid,
          page: _page, pageSize: _pageSize);
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
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
        if (_items.isNotEmpty) {
          MoeToast.error(context, '加载失败: $e');
        }
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

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return MoeTokens.success;
      case 'pending':
        return MoeTokens.warning;
      case 'cancelled':
        return MoeTokens.hintText;
      default:
        return MoeTokens.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser;
    if (uid == null) {
      return const MoeEmptyState(
        icon: Icons.lock_outline_rounded,
        title: '请先登录',
        subtitle: '登录后可查看会员订单',
      );
    }
    if (_loading && _items.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: MoeErrorState.fromError(
          _error,
          scene: MoeErrorScene.generic,
          onRetry: () => _load(refresh: true),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 60),
            MoeEmptyState(
              icon: Icons.workspace_premium_outlined,
              title: '暂无会员订单',
              subtitle: '开通或续费会员后的订单会展示在这里',
            ),
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
                child: _loading
                    ? const MoeSmallLoading()
                    : MoeSecondaryButton(
                        label: '加载更多',
                        onPressed: _more,
                      ),
              ),
            );
          }
          final o = _items[i];
          final on = (o.orderNo ?? '').trim();
          final sc = _statusColor(o.status);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                  children: [
                    Expanded(
                      child: Text(
                        o.planName,
                        style: const TextStyle(
                          fontSize: MoeTokens.textMd,
                          fontWeight: FontWeight.w700,
                          color: MoeTokens.titleText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusFull),
                      ),
                      child: Text(
                        _statusText(o.status),
                        style: TextStyle(
                          color: sc,
                          fontWeight: FontWeight.w600,
                          fontSize: MoeTokens.textXs,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  on.isNotEmpty ? '订单号 $on' : '订单编号 ${o.id}',
                  style: const TextStyle(
                    fontSize: MoeTokens.textSm,
                    color: MoeTokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '¥${o.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MoeTokens.titleText,
                        fontSize: MoeTokens.textLg,
                      ),
                    ),
                    Text(
                      o.createdAt,
                      style: const TextStyle(
                        fontSize: MoeTokens.textXs,
                        color: MoeTokens.hintText,
                      ),
                    ),
                  ],
                ),
              ],
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
  Object? _error;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r =
          await CommerceService.getTransactions(uid, page: 1, pageSize: 30);
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
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser;
    if (uid == null) {
      return const MoeEmptyState(
        icon: Icons.lock_outline_rounded,
        title: '请先登录',
        subtitle: '登录后可查看钱包流水',
      );
    }
    if (_loading) {
      return const Center(child: MoeLoading());
    }
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: MoeErrorState.fromError(
          _error,
          scene: MoeErrorScene.generic,
          onRetry: _load,
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: MoeSecondaryButton(
            expand: true,
            icon: Icons.account_balance_wallet_outlined,
            label: '打开完整钱包与充值',
            onPressed: () {
              Navigator.pushNamed(context, '/wallet');
            },
          ),
        ),
        Expanded(
          child: _rows.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 60),
                      MoeEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: '暂无钱包流水',
                        subtitle: '充值与消费记录会展示在这里',
                      ),
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
                      final desc = t['description'] as String? ??
                          (type == 'recharge' ? '充值' : '消费');
                      final isRecharge = type == 'recharge';
                      final sign = isRecharge ? '+' : '-';
                      final amtColor = isRecharge
                          ? MoeTokens.pastelTeal
                          : MoeTokens.titleText;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: MoeTokens.surface1,
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusXl),
                          border: Border.all(color: MoeTokens.surfaceBorder),
                          boxShadow: MoeTokens.shadowCard(),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    desc,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: MoeTokens.titleText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t['created_at'] as String? ?? '',
                                    style: const TextStyle(
                                      color: MoeTokens.hintText,
                                      fontSize: MoeTokens.textXs,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$sign${amt.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: MoeTokens.textMd,
                                color: amtColor,
                              ),
                            ),
                          ],
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
