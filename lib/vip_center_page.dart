import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/vip_record.dart';
import 'vip_purchase_page.dart';
import 'vip_orders_page.dart';
import 'vip_history_page.dart';

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
          ),
        );
      }
    } catch (e) {
      setState(() {
        _autoRenew = !value; // 恢复原值
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VIP中心'),
        backgroundColor: Colors.amber[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVipInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // VIP状态卡片
                    _buildVipStatusCard(),
                    const SizedBox(height: 16),
                    // 活跃VIP记录信息
                    if (_activeRecord != null) _buildActiveRecordCard(),
                    const SizedBox(height: 16),
                    // 功能菜单
                    _buildMenuSection(),
                    const SizedBox(height: 16),
                    // 自动续费设置
                    if (_vipStatus != null && (_vipStatus!['is_vip'] as bool? ?? false))
                      _buildAutoRenewSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVipStatusCard() {
    final isVip = _vipStatus?['is_vip'] as bool? ?? false;
    final expiresAt = _vipStatus?['expires_at'] as String?;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip
              ? [Colors.amber[700]!, Colors.amber[500]!]
              : [Colors.grey[400]!, Colors.grey[300]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            isVip ? Icons.star : Icons.star_border,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            isVip ? 'VIP会员' : '普通用户',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isVip && expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '到期时间: $expiresAt',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
          if (!isVip) ...[
            const SizedBox(height: 16),
            ElevatedButton(
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
                foregroundColor: Colors.amber[700],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('立即开通VIP'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.shopping_cart_outlined,
            title: 'VIP订单',
            subtitle: '查看我的VIP订单',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VipOrdersPage()),
              );
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            icon: Icons.history_outlined,
            title: 'VIP历史',
            subtitle: '查看VIP使用记录',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VipHistoryPage()),
              );
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            icon: Icons.star_outline,
            title: '购买VIP',
            subtitle: '选择VIP套餐',
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
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.amber[700]),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildActiveRecordCard() {
    final record = _activeRecord!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '当前VIP信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('套餐名称', record.planName),
            const Divider(),
            _buildInfoRow(
              '开始时间',
              record.startAtDateTime != null
                  ? '${record.startAtDateTime!.year}-${record.startAtDateTime!.month.toString().padLeft(2, '0')}-${record.startAtDateTime!.day.toString().padLeft(2, '0')}'
                  : record.startAt,
            ),
            const Divider(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoRenewSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SwitchListTile(
        title: const Text('自动续费'),
        subtitle: const Text('VIP到期后自动续费'),
        value: _autoRenew,
        onChanged: _toggleAutoRenew,
        secondary: Icon(
          Icons.autorenew,
          color: _autoRenew ? Colors.amber[700] : Colors.grey,
        ),
      ),
    );
  }
}

