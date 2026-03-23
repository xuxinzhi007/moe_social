import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/vip_record.dart';
import 'vip_purchase_page.dart';
import 'vip_orders_page.dart';
import 'vip_history_page.dart';
import 'widgets/fade_in_up.dart';
import 'widgets/moe_toast.dart';
import 'widgets/moe_menu_card.dart'; // 引入通用菜单组件

class VipCenterPage extends StatefulWidget {
  const VipCenterPage({super.key});

  @override
  State<VipCenterPage> createState() => _VipCenterPageState();
}

class _VipCenterPageState extends State<VipCenterPage> {
  Map<String, dynamic>? _vipStatus;
  VipRecord? _activeRecord;
  bool _isLoading = true;
  bool _autoRenew = false;

  @override
  void initState() {
    super.initState();
    _loadVipInfo();
  }

  Future<void> _loadVipInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _vipStatus = null;
          _activeRecord = null;
          _autoRenew = false;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vipStatus = await ApiService.getUserVipStatus(userId);
      
      VipRecord? activeRecord;
      try {
        activeRecord = await ApiService.getUserActiveVipRecord(userId);
      } catch (e) {
        print('获取活跃VIP记录失败: $e');
      }

      setState(() {
        _vipStatus = vipStatus;
        _activeRecord = activeRecord;
        _autoRenew = vipStatus['auto_renew'] as bool? ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        MoeToast.error(context, '加载VIP信息失败，请稍后重试');
      }
    }
  }

  Future<void> _toggleAutoRenew(bool value) async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    setState(() {
      _autoRenew = value;
    });

    try {
      await ApiService.updateAutoRenew(userId, value);
      if (mounted) {
        MoeToast.success(context, value ? '已开启自动续费' : '已关闭自动续费');
      }
    } catch (e) {
      setState(() {
        _autoRenew = !value;
      });
      if (mounted) {
        MoeToast.error(context, '操作失败，请稍后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('会员中心', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !isLoggedIn
          ? _buildGuestView()
          : _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7F7FD5)))
          : Stack(
              children: [
                // 顶部背景 - 统一 Moe 风格渐变
                Container(
                  height: 300,
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
                
                RefreshIndicator(
                  onRefresh: _loadVipInfo,
                  color: const Color(0xFF7F7FD5),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
                    child: Column(
                      children: [
                        // VIP状态卡片
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FadeInUp(
                            child: _buildVipStatusCard(),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // 活跃VIP记录信息
                        if (_activeRecord != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: FadeInUp(
                              delay: const Duration(milliseconds: 100),
                              child: _buildActiveRecordCard(),
                            ),
                          ),
                          
                        const SizedBox(height: 16),
                        
                        // 功能菜单 - 使用 MoeMenuCard
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FadeInUp(
                            delay: const Duration(milliseconds: 200),
                            child: MoeMenuCard(
                              items: [
                                MoeMenuItem(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'VIP订单',
                                  subtitle: '查看我的购买记录',
                                  color: Colors.blueAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const VipOrdersPage()),
                                    );
                                  },
                                ),
                                MoeMenuItem(
                                  icon: Icons.history_rounded,
                                  title: '开通记录',
                                  subtitle: '查看历史生效记录',
                                  color: Colors.purpleAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const VipHistoryPage()),
                                    );
                                  },
                                ),
                                MoeMenuItem(
                                  icon: Icons.diamond_outlined,
                                  title: '购买/续费VIP',
                                  subtitle: '查看最新套餐优惠',
                                  color: Colors.orangeAccent,
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const VipPurchasePage()),
                                    );
                                    if (result == true) {
                                      if (mounted) {
                                        Navigator.pop(context, true);
                                      }
                                      _loadVipInfo();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 自动续费设置 - 也可以封装进 MoeMenuCard，或者单独样式
                        if (_vipStatus != null && (_vipStatus!['is_vip'] as bool? ?? false))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: FadeInUp(
                              delay: const Duration(milliseconds: 300),
                              child: _buildAutoRenewCard(),
                            ),
                          ),
                          
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGuestView() {
    return Stack(
      children: [
        Container(
          height: 300,
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
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F7FD5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 36,
                      color: Color(0xFF7F7FD5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '登录后查看 VIP 会员中心',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '登录后可查看会员权益、套餐价格、订单记录和续费状态。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/login');
                        if (mounted) {
                          _loadVipInfo();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7F7FD5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('去登录'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVipStatusCard() {
    final isVip = _vipStatus?['is_vip'] as bool? ?? false;
    final expiresAt = _vipStatus?['expires_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // VIP 保持金色质感，非 VIP 使用白色半透明玻璃拟态，不再用深灰
        gradient: isVip
            ? const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isVip ? Colors.orange : Colors.black).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isVip ? Colors.white.withOpacity(0.25) : const Color(0xFF7F7FD5).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVip ? Icons.workspace_premium_rounded : Icons.star_border_rounded,
                  color: isVip ? Colors.white : const Color(0xFF7F7FD5),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVip ? '尊贵VIP会员' : '普通用户',
                      style: TextStyle(
                        color: isVip ? Colors.white : const Color(0xFF333333),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isVip ? '有效期至: ${expiresAt ?? "未知"}' : '开通VIP，解锁更多特权',
                      style: TextStyle(
                        color: isVip ? Colors.white.withOpacity(0.9) : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (!isVip) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VipPurchasePage()),
                  );
                  if (result == true) {
                    _loadVipInfo();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5), // 统一使用主色
                  foregroundColor: Colors.white,
                  elevation: 5,
                  shadowColor: const Color(0xFF7F7FD5).withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text(
                  '立即开通',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveRecordCard() {
    final record = _activeRecord!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF7F7FD5)),
                const SizedBox(width: 8),
                const Text(
                  '当前套餐详情',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('套餐名称', record.planName),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.grey.withOpacity(0.1)),
            ),
            _buildInfoRow(
              '开始时间',
              record.startAtDateTime != null
                  ? '${record.startAtDateTime!.year}-${record.startAtDateTime!.month.toString().padLeft(2, '0')}-${record.startAtDateTime!.day.toString().padLeft(2, '0')}'
                  : record.startAt,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              '结束时间',
              record.endAtDateTime != null
                  ? '${record.endAtDateTime!.year}-${record.endAtDateTime!.month.toString().padLeft(2, '0')}-${record.endAtDateTime!.day.toString().padLeft(2, '0')}'
                  : record.endAt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF333333)),
        ),
      ],
    );
  }

  Widget _buildAutoRenewCard() {
    // 这里使用 MoeMenuCard 风格的单个项
    return MoeMenuCard(
      items: [
        MoeMenuItem(
          icon: Icons.autorenew_rounded,
          title: '自动续费',
          subtitle: 'VIP到期后自动扣费续期',
          color: Colors.green,
          onTap: () => _toggleAutoRenew(!_autoRenew),
          trailing: Switch.adaptive(
            value: _autoRenew,
            activeColor: const Color(0xFF7F7FD5),
            onChanged: _toggleAutoRenew,
          ),
        ),
      ],
    );
  }
}
