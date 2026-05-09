import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../models/vip_plan.dart';
import 'vip_order_confirm_page.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_toast.dart';

class VipPurchasePage extends StatefulWidget {
  const VipPurchasePage({super.key});

  @override
  State<VipPurchasePage> createState() => _VipPurchasePageState();
}

class _VipPurchasePageState extends State<VipPurchasePage> {
  List<VipPlan> _plans = [];
  bool _isLoading = true;
  bool _isOpeningConfirm = false;
  String? _selectedPlanId;
  String? _loadErrorMessage;
  double _balance = 0.0;
  final List<String> _vipHighlights = const ['尊贵身份标识', '专享高级功能', '会员专属权益'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final userId = AuthService.currentUser;
      final futures = <Future<dynamic>>[
        ApiService.getVipPlans(),
        if (userId != null) ApiService.getUserInfo(userId),
      ];
      final results = await Future.wait(futures);
      final plans = results[0] as List<VipPlan>;

      if (!mounted) {
        return;
      }
      setState(() {
        _plans = plans;
        _loadErrorMessage = null;
        if (userId != null && results.length > 1) {
          _balance = results[1].balance as double;
        }
        if (plans.isNotEmpty) {
          final hasSelectedPlan =
              plans.any((plan) => plan.id == _selectedPlanId);
          if (!hasSelectedPlan) {
            _selectedPlanId = plans.first.id;
          }
        } else {
          _selectedPlanId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorMessage = _resolveLoadErrorMessage(e);
      });
      MoeToast.error(context, _loadErrorMessage ?? '加载VIP套餐失败，请稍后重试');
    }
  }

  String _resolveLoadErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('timeout') || message.contains('超时')) {
      return '网络超时，加载失败，请下拉刷新或重试';
    }
    if (message.contains('socket') ||
        message.contains('无法连接') ||
        message.contains('network')) {
      return '网络连接异常，请检查后重试';
    }
    return '加载VIP套餐失败，请稍后重试';
  }

  Future<void> _refreshBalance() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;
    try {
      final userInfo = await ApiService.getUserInfo(userId);
      if (mounted) {
        setState(() {
          _balance = userInfo.balance;
        });
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, '刷新余额失败，请稍后重试');
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadInitialData(showLoading: false);
  }

  Future<void> _goOrderConfirm() async {
    if (_selectedPlanId == null || _isOpeningConfirm) return;

    final selectedPlan = _getSelectedPlan();
    if (selectedPlan == null) return;

    final userId = AuthService.currentUser;
    if (userId == null) {
      MoeToast.error(context, '请先登录');
      return;
    }

    setState(() {
      _isOpeningConfirm = true;
    });
    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => VipOrderConfirmPage(
            plan: selectedPlan,
            initialBalance: _balance,
          ),
        ),
      );
      if (result == true) {
        await _refreshBalance();
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningConfirm = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 顶部背景
          Container(
            height: 320,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF7F7FD5),
                    onRefresh: _handleRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '开通 VIP 会员',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _vipHighlights
                                    .map(
                                      (label) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFFFFD66B),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.95),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),

                        // 套餐列表 (横向滚动)
                        if (_plans.isEmpty && _loadErrorMessage != null)
                          _buildLoadFailedState()
                        else if (_plans.isEmpty)
                          _buildEmptyPlanState()
                        else
                          SizedBox(
                            height: 230,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: _plans.length,
                              itemBuilder: (context, index) {
                                final plan = _plans[index];
                                return FadeInUp(
                                  delay:
                                      Duration(milliseconds: 30 * (index % 8)),
                                  child: _buildPlanCard(plan),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 24),

                        // 权益说明区
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7F7FD5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '会员权益',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ..._buildBenefitWidgets(),
                              // 底部留白，防止被浮动按钮遮挡
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      // 底部购买栏
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F7FD5).withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '总计 ¥${_getSelectedPlanPrice()}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF8F00),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '钱包余额 ¥${_balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7F7FD5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            (_isLoading || _plans.isEmpty || _isOpeningConfirm)
                                ? null
                                : _goOrderConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7F7FD5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '去确认订单',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '确认页将展示钱包扣款明细，未支付前不会开通会员',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSelectedPlanPrice() {
    if (_plans.isEmpty || _selectedPlanId == null) return '0.00';
    final plan = _plans.firstWhere((p) => p.id == _selectedPlanId,
        orElse: () => _plans.first);
    return plan.price.toStringAsFixed(2);
  }

  VipPlan? _getSelectedPlan() {
    if (_plans.isEmpty || _selectedPlanId == null) return null;
    return _plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => _plans.first,
    );
  }

  Widget _buildPlanCard(VipPlan plan) {
    final isSelected = _selectedPlanId == plan.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = plan.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        margin: const EdgeInsets.only(right: 16, bottom: 16, top: 8), // 留出阴影空间
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD66B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '已选中',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B4B00),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              plan.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF333333) : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: '¥',
                      style: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? const Color(0xFFFF8F00)
                              : Colors.black87,
                          fontWeight: FontWeight.bold)),
                  TextSpan(
                      text: plan.price.toStringAsFixed(0),
                      style: TextStyle(
                          fontSize: 32,
                          color: isSelected
                              ? const Color(0xFFFF8F00)
                              : Colors.black87,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFD700) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${plan.durationDays} 天',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
            const Spacer(),
            Text(
              '点击选择套餐',
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? const Color(0xFF7F7FD5) : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(
      IconData icon, String title, String subtitle, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF333333)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadFailedState() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: Color(0xFF7F7FD5), size: 42),
              const SizedBox(height: 10),
              Text(
                _loadErrorMessage ?? '加载失败，请稍后重试',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlanState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '暂无VIP套餐',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBenefitWidgets() {
    final selectedPlan = _getSelectedPlan();
    final benefitsFromPlan =
        _extractBenefitsFromDescription(selectedPlan?.description ?? '');
    final fallbackBenefits = <Map<String, dynamic>>[
      {
        'icon': Icons.color_lens_rounded,
        'title': '专属主题色',
        'subtitle': '解锁更多个性化主题颜色',
        'color': Colors.purpleAccent,
      },
      {
        'icon': Icons.hd_rounded,
        'title': '高清画质',
        'subtitle': '上传/查看原图特权',
        'color': Colors.blueAccent,
      },
      {
        'icon': Icons.speed_rounded,
        'title': '极速体验',
        'subtitle': '专属线路加速',
        'color': Colors.greenAccent,
      },
      {
        'icon': Icons.star_rounded,
        'title': '身份铭牌',
        'subtitle': '尊贵 VIP 专属标识',
        'color': Colors.orangeAccent,
      },
    ];

    if (benefitsFromPlan.isEmpty) {
      return fallbackBenefits
          .map(
            (benefit) => _buildBenefitItem(
              benefit['icon'] as IconData,
              benefit['title'] as String,
              benefit['subtitle'] as String,
              benefit['color'] as Color,
            ),
          )
          .toList();
    }

    final colors = <Color>[
      Colors.purpleAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
    ];
    return List.generate(benefitsFromPlan.length, (index) {
      return _buildBenefitItem(
        Icons.check_circle_rounded,
        benefitsFromPlan[index],
        '当前套餐专属权益说明',
        colors[index % colors.length],
      );
    });
  }

  List<String> _extractBenefitsFromDescription(String description) {
    if (description.trim().isEmpty) {
      return [];
    }
    final lines = description
        .split(RegExp(r'[\n;；|]'))
        .map((line) => line.replaceAll(RegExp(r'^[\-\d\.\s、]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.take(6).toList();
  }
}
