import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/vip_record.dart';
import 'vip_purchase_page.dart';
import 'vip_orders_page.dart';
import 'vip_history_page.dart';
import 'widgets/fade_in_up.dart'; // 引入动画组件

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
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取VIP状态
      final vipStatus = await ApiService.getUserVipStatus(userId);
      
      // 获取活跃VIP记录
      VipRecord? activeRecord;
      try {
        activeRecord = await ApiService.getUserActiveVipRecord(userId);
      } catch (e) {
        // 可能没有活跃记录
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载VIP信息失败: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '已开启自动续费' : '已关闭自动续费'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _autoRenew = !value; // 恢复原值
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true, // 内容延伸到顶部
      appBar: AppBar(
        title: const Text('会员中心', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 顶部背景
                Container(
                  height: 300,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
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
                        
                        // 功能菜单
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FadeInUp(
                            delay: const Duration(milliseconds: 200),
                            child: _buildMenuSection(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 自动续费设置
                        if (_vipStatus != null && (_vipStatus!['is_vip'] as bool? ?? false))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: FadeInUp(
                              delay: const Duration(milliseconds: 300),
                              child: _buildAutoRenewSection(),
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

  Widget _buildVipStatusCard() {
    final isVip = _vipStatus?['is_vip'] as bool? ?? false;
    final expiresAt = _vipStatus?['expires_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip
              ? [const Color(0xFFFFD700), const Color(0xFFFFA500)] // 金色渐变
              : [const Color(0xFFE0E0E0), const Color(0xFFBDBDBD)], // 灰色渐变
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isVip ? Colors.orange : Colors.grey).withOpacity(0.4),
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
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVip ? Icons.workspace_premium_rounded : Icons.star_border_rounded,
                  color: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isVip ? '有效期至: ${expiresAt ?? "未知"}' : '开通VIP，解锁更多特权',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
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
                    _loadVipInfo(); // 刷新VIP信息
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey[800],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
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
          const Divider(height: 1, indent: 60, endIndent: 20),
          _buildMenuItem(
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
          const Divider(height: 1, indent: 60, endIndent: 20),
          _buildMenuItem(
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
                _loadVipInfo(); // 刷新VIP信息
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
      onTap: onTap,
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
            color: Colors.grey.withOpacity(0.05),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('套餐名称', record.planName),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
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
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildAutoRenewSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SwitchListTile.adaptive(
        title: const Text('自动续费', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('VIP到期后自动扣费续期', style: TextStyle(fontSize: 12)),
        value: _autoRenew,
        activeColor: const Color(0xFF7F7FD5),
        onChanged: _toggleAutoRenew,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.autorenew_rounded,
            color: Colors.green,
            size: 22,
          ),
        ),
      ),
    );
  }
}
