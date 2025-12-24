import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/api_service.dart';
import 'widgets/avatar_image.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String? heroTag;

  const UserProfilePage({
    super.key,
    required this.userId,
    this.userName,
    this.userAvatar,
    this.heroTag,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  User? _user;

  @override
  void initState() {
    super.initState();
    // 异步加载最新数据，但不阻塞页面显示
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await ApiService.getUserInfo(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      print('后台加载用户数据失败: $e');
      // 失败了也不弹窗，保持显示传递过来的基础信息即可
    }
  }

  @override
  Widget build(BuildContext context) {
    // 优先使用加载到的最新数据，否则使用跳转传过来的数据
    final name = _user?.username ?? widget.userName ?? '用户 ${widget.userId}';
    final avatar = _user?.avatar ?? widget.userAvatar;
    final email = _user?.email ?? '';
    final balance = _user?.balance ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[100], // 浅灰背景
      extendBodyBehindAppBar: true, // 让内容延伸到 AppBar 后面
      appBar: AppBar(
        title: const Text('个人主页'),
        elevation: 0,
        backgroundColor: Colors.transparent, // 透明背景
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 顶部头部区域
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. 背景渐变色块 (现在延伸到顶部了)
                Container(
                  height: 200, // 增加高度以覆盖状态栏和AppBar
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blueAccent, Colors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // 2. 个人信息卡片（重叠在背景上）
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 120, 16, 0), // 调整顶部距离
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      const SizedBox(height: 16),
                      // 统计数据
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(label: '动态', value: '0'),
                          _StatItem(label: '关注', value: '0'),
                          _StatItem(label: '粉丝', value: '0'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 按钮组
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('关注'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('私信'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 3. 头像（绝对定位在卡片上方）
                Positioned(
                  top: 80, // 调整头像位置
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    // 暂时不用 Hero，确保稳定
                    child: NetworkAvatarImage(
                      imageUrl: avatar,
                      radius: 40,
                      placeholderIcon: Icons.person,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 内容区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  Text(
                    '暂无动态',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 40), // 撑开一点高度
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// 简单的统计组件
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
