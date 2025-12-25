import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/user.dart';
import 'widgets/avatar_image.dart';
import 'wallet_page.dart';
import 'widgets/fade_in_up.dart';

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
  int _postCount = 0;

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
      final futures = await Future.wait([
        ApiService.getUserInfo(userId),
        ApiService.getUserVipStatus(userId).catchError((_) => <String, dynamic>{}),
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
      extendBodyBehindAppBar: true, // AppBar背景透明，内容延伸到顶部
      appBar: AppBar(
        title: const Text('个人中心', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/settings').then((_) {
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
                    // 头部区域
                    _buildHeader(),
                    
                    const SizedBox(height: 20),
                    
                    // 菜单区域
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (_isVip)
                            FadeInUp(
                              delay: const Duration(milliseconds: 100),
                              child: _buildVipCard(),
                            ),
                          const SizedBox(height: 16),
                          
                          FadeInUp(
                            delay: const Duration(milliseconds: 200),
                            child: _buildMenuCard([
                              _MenuItem(
                                icon: Icons.edit_outlined, 
                                title: '编辑资料',
                                color: Colors.blueAccent,
                                onTap: () async {
                                  if (_user != null) {
                                    final result = await Navigator.pushNamed(
                                      context,
                                      '/edit-profile',
                                      arguments: _user,
                                    );
                                    if (result == true) {
                                      _loadUserInfo();
                                    }
                                  }
                                },
                              ),
                              _MenuItem(
                                icon: Icons.favorite_border_rounded, 
                                title: '我的收藏',
                                color: Colors.pinkAccent,
                                onTap: () {},
                              ),
                              _MenuItem(
                                icon: Icons.history_rounded, 
                                title: '浏览历史',
                                color: Colors.orangeAccent,
                                onTap: () {},
                              ),
                            ]),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          FadeInUp(
                            delay: const Duration(milliseconds: 300),
                            child: _buildMenuCard([
                              _MenuItem(
                                icon: Icons.account_balance_wallet_outlined, 
                                title: '我的钱包',
                                subtitle: '余额: ¥${_user?.balance.toStringAsFixed(2) ?? '0.00'}',
                                color: Colors.green,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const WalletPage()),
                                  );
                                },
                              ),
                              _MenuItem(
                                icon: Icons.help_outline_rounded, 
                                title: '帮助与反馈',
                                color: Colors.purpleAccent,
                                onTap: () {},
                              ),
                            ]),
                          ),

                          const SizedBox(height: 16),

                          FadeInUp(
                            delay: const Duration(milliseconds: 400),
                            child: _buildMenuCard([
                              _MenuItem(
                                icon: Icons.logout_rounded, 
                                title: '退出登录',
                                color: Colors.redAccent,
                                isDestructive: true,
                                onTap: () => _showLogoutDialog(context),
                              ),
                            ]),
                          ),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 背景图
        Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF7F7FD5),
                Color(0xFF86A8E7),
                Color(0xFF91EAE4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
        ),
        // 装饰圆
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        
        // 用户信息内容
        Positioned(
          bottom: 20,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: NetworkAvatarImage(
                  imageUrl: _user?.avatar,
                  radius: 46,
                  placeholderIcon: Icons.person,
                  placeholderColor: Colors.grey[200]!,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _user?.username ?? '未知用户',
                style: const TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _user?.email ?? '',
                style: TextStyle(color: Colors.white.withOpacity(0.9)),
              ),
              const SizedBox(height: 16),
              // 统计数据
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatItem('动态', '$_postCount'),
                    Container(height: 20, width: 1, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _buildStatItem('关注', '0'),
                    Container(height: 20, width: 1, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _buildStatItem('粉丝', '0'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ],
    );
  }

  Widget _buildVipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VIP会员中心',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (_vipStatus != null && _vipStatus!['expires_at'] != null)
                Text(
                  '到期: ${_vipStatus!['expires_at']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                )
              else
                const Text(
                  '开通享特权',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/vip-center');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 0,
            ),
            child: const Text('立即查看'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: items.map((item) {
          final isLast = items.last == item;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: item.isDestructive ? Colors.red : Colors.black87,
                  ),
                ),
                subtitle: item.subtitle != null 
                    ? Text(item.subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[500])) 
                    : null,
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                onTap: item.onTap,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              if (!isLast)
                const Divider(height: 1, indent: 60, endIndent: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
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

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });
}
