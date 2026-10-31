import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../models/vip_record.dart';
import '../../services/commerce_service.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/moe_button.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

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
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _records = [];
        _hasMore = true;
        _error = null;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CommerceService.getVipHistory(
        userId,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _records = result['records'] as List<VipRecord>;
        } else {
          _records.addAll(result['records'] as List<VipRecord>);
        }
        _total = result['total'] as int;
        _hasMore = _records.length < _total;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
      if (_records.isNotEmpty) {
        MoeToast.error(context, '加载历史记录失败: $e');
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
        return MoeTokens.success;
      case 'expired':
        return MoeTokens.hintText;
      case 'cancelled':
        return MoeTokens.danger;
      default:
        return MoeTokens.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      title: 'VIP 开通记录',
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: () => _loadHistory(refresh: true),
        child: _isLoading && _records.isEmpty
            ? const Center(child: MoeLoading())
            : _error != null && _records.isEmpty
                ? Center(
                    child: MoeErrorState.fromError(
                      _error,
                      scene: MoeErrorScene.generic,
                      onRetry: () => _loadHistory(refresh: true),
                    ),
                  )
                : _records.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          MoeEmptyState(
                            icon: Icons.history_rounded,
                            title: '暂无开通记录',
                            subtitle: '开通或续期会员后的生效周期记录会展示在这里',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _records.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _records.length) {
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

                          final record = _records[index];
                          return _buildRecordCard(record);
                        },
                      ),
      ),
    );
  }

  Widget _buildRecordCard(VipRecord record) {
    final isActive = record.isActive;
    final statusColor = _getStatusColor(record.status);

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
                      record.planName,
                      style: const TextStyle(
                        fontSize: MoeTokens.textMd,
                        fontWeight: FontWeight.w700,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '记录编号: ${record.id}',
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          color: MoeTokens.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      _getStatusText(record.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: MoeTokens.textXs,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: MoeTokens.lineSoft),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '开始时间',
                      style: TextStyle(
                        color: MoeTokens.hintText,
                        fontSize: MoeTokens.textXs,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.startAtDateTime != null
                          ? '${record.startAtDateTime!.year}-${record.startAtDateTime!.month.toString().padLeft(2, '0')}-${record.startAtDateTime!.day.toString().padLeft(2, '0')}'
                          : record.startAt,
                      style: const TextStyle(
                        fontSize: MoeTokens.textBase,
                        fontWeight: FontWeight.w600,
                        color: MoeTokens.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '结束时间',
                      style: TextStyle(
                        color: MoeTokens.hintText,
                        fontSize: MoeTokens.textXs,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.endAtDateTime != null
                          ? '${record.endAtDateTime!.year}-${record.endAtDateTime!.month.toString().padLeft(2, '0')}-${record.endAtDateTime!.day.toString().padLeft(2, '0')}'
                          : record.endAt,
                      style: const TextStyle(
                        fontSize: MoeTokens.textBase,
                        fontWeight: FontWeight.w600,
                        color: MoeTokens.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
