import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/user.dart';
import 'widgets/avatar_image.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  Map<String, dynamic>? _vipStatus;
  bool _isLoading = true;
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取用户信息
      final user = await ApiService.getUserInfo(userId);
      
      // 获取VIP状态
      Map<String, dynamic>? vipStatus;
      bool isVip = false;
      try {
        vipStatus = await ApiService.getUserVipStatus(userId);
        isVip = vipStatus['is_vip'] as bool? ?? false;
      } catch (e) {
        // VIP状态获取失败不影响页面显示
        print('获取VIP状态失败: $e');
      }

      setState(() {
        _user = user;
        _vipStatus = vipStatus;
        _isVip = isVip;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户信息失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings').then((_) {
                // 返回时刷新用户信息
                _loadUserInfo();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // User Header
                    Center(
                      child: Column(
                        children: [
                          NetworkAvatarImage(
                            imageUrl: _user?.avatar,
                            radius: 50,
                            placeholderIcon: Icons.person,
                            placeholderColor: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _user?.username ?? '未知用户',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _user?.email ?? '',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          if (_isVip)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'VIP会员',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          if (_vipStatus != null && _vipStatus!['expires_at'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'VIP到期: ${_vipStatus!['expires_at']}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Statistics
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem('动态', '0'),
                        _buildStatItem('关注', '0'),
                        _buildStatItem('粉丝', '0'),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Menu Items
                    ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        if (_isVip)
                          _buildMenuItem(Icons.star, 'VIP中心', () {
                            Navigator.pushNamed(context, '/vip-center');
                          }),
                        _buildMenuItem(Icons.edit_outlined, '编辑资料', () async {
                          if (_user != null) {
                            final result = await Navigator.pushNamed(
                              context,
                              '/edit-profile',
                              arguments: _user,
                            );
                            if (result == true) {
                              _loadUserInfo(); // 刷新用户信息
                            }
                          }
                        }),
                        _buildMenuItem(Icons.favorite_outline, '我的收藏', () {}),
                        _buildMenuItem(Icons.history, '浏览历史', () {}),
                        _buildMenuItem(Icons.wallet_outlined, '我的钱包', () {}),
                        _buildMenuItem(Icons.help_outline, '帮助与反馈', () {}),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('退出登录', style: TextStyle(color: Colors.red)),
                          onTap: () {
                            _showLogoutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              AuthService.logout();
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

