import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/user.dart';
import 'widgets/avatar_image.dart';
import 'wallet_page.dart';

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
  int _postCount = 0; // 动态数量

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
      // 并行请求：用户信息、VIP状态、帖子数量
      final futures = await Future.wait([
        ApiService.getUserInfo(userId),
        ApiService.getUserVipStatus(userId).catchError((_) => <String, dynamic>{}),
        // 获取所有帖子并过滤出自己的，计算数量
        ApiService.getPosts(page: 1, pageSize: 100).then((posts) {
          return posts.where((p) => p.userId.toString() == userId.toString()).length;
        }).catchError((_) => 0),
      ]);

      final user = futures[0] as User;
      final vipStatus = futures[1] as Map<String, dynamic>;
      final postCount = futures[2] as int;

      bool isVip = vipStatus['is_vip'] as bool? ?? false;

      if (mounted) {
        setState(() {
          _user = user;
          _vipStatus = vipStatus;
          _isVip = isVip;
          _postCount = postCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                          // 钱包余额显示
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wallet, size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  '余额: ¥${_user?.balance.toStringAsFixed(2) ?? '0.00'}',
                                  style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
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
                        _buildStatItem('动态', '$_postCount'),
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
                        _buildMenuItem(Icons.wallet_outlined, '我的钱包', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WalletPage()),
                          );
                        }),
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
