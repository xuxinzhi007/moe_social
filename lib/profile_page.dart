import 'package:provider/provider.dart';
import 'providers/device_info_provider.dart';
import 'package:flutter/material.dart';
import 'autoglm/autoglm_page.dart';
import 'autoglm/autoglm_service.dart'; // 恢复导入
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/user.dart';
import 'models/post.dart';
import 'models/achievement_badge.dart';
import 'services/achievement_service.dart';
import 'widgets/dynamic_avatar.dart';
import 'widgets/achievement_badge_display.dart';
import 'widgets/profile_bg.dart';
import 'wallet_page.dart';
import 'widgets/fade_in_up.dart';
import 'gallery/cloud_gallery_page.dart';
import 'pages/checkin_page.dart';
import 'pages/user_level_page.dart';
import 'providers/user_level_provider.dart';
import 'following_page.dart';
import 'followers_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  Map<String, dynamic>? _vipStatus;
  bool _isLoading = true;
  bool _isLoadingDetails = false;
  bool _isVip = false;
  int _postCount = 0;
  int _followingCount = 0;
  int _followerCount = 0;
  List<AchievementBadge> _userBadges = [];
  final AchievementService _achievementService = AchievementService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await ApiService.getUserInfo(userId)
          .timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
          _isLoadingDetails = true;
        });
      }

      final results = await Future.wait([
        ApiService.getUserVipStatus(userId)
            .timeout(const Duration(seconds: 5))
            .catchError((_) => <String, dynamic>{}),
        _getFollowingCount(userId),
        _getFollowerCount(userId),
        _getUserPostCount(userId),
      ]);

      final vipStatus = results[0] as Map<String, dynamic>;
      final followingCount = results[1] as int;
      final followerCount = results[2] as int;
      final postCount = results[3] as int;

      bool isVip = vipStatus['is_vip'] as bool? ?? false;

      final userBadges = _achievementService.getUserBadges(userId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final levelProvider = context.read<UserLevelProvider>();
          if (levelProvider.userLevel == null && !levelProvider.isLoading) {
            levelProvider.loadUserLevel(userId);
          }
        }
      });

      if (mounted) {
        setState(() {
          _vipStatus = vipStatus;
          _isVip = isVip;
          _postCount = postCount;
          _followingCount = followingCount;
          _followerCount = followerCount;
          _userBadges = userBadges;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      print('Profile loading error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingDetails = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('加载个人信息失败，请检查网络连接'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _loadUserInfo,
            ),
          ),
        );
      }
    }
  }

  Future<int> _getFollowingCount(String userId) async {
    try {
      final result = await ApiService.getFollowings(userId, page: 1, pageSize: 1)
          .timeout(const Duration(seconds: 5));
      return result['total'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getFollowerCount(String userId) async {
    try {
      final result = await ApiService.getFollowers(userId, page: 1, pageSize: 1)
          .timeout(const Duration(seconds: 5));
      return result['total'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getUserPostCount(String userId) async {
    try {
      final result = await ApiService.getPosts(page: 1, pageSize: 20)
          .timeout(const Duration(seconds: 8));
      final posts = result['posts'] as List<Post>;
      return posts
          .where((p) => p.userId.toString() == userId.toString())
          .length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(
                color: Color(0xFF7F7FD5),
              ),
              SizedBox(height: 16),
              Text(
                '正在加载个人信息...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _loadUserInfo,
        color: const Color(0xFF7F7FD5),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 380.0,
              pinned: true,
              stretch: true,
              backgroundColor: const Color(0xFF7F7FD5),
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('个人中心',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  if (_isLoadingDetails) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
              centerTitle: true,
              actions: [
                // 恢复设置按钮
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings').then((_) {
                      _loadUserInfo();
                    });
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(),
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (_isVip)
                      FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        child: _buildVipCard(),
                      ),
                    const SizedBox(height: 16),
                    
                    // 1. 我的足迹
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 12, bottom: 10),
                            child: Text('我的足迹', 
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
                          ),
                          _buildMenuCard([
                            _MenuItem(
                              icon: Icons.military_tech_rounded,
                              title: '成就徽章',
                              subtitle: '已解锁 ${_userBadges.where((b) => b.isUnlocked).length} 个',
                              color: const Color(0xFFFFB347),
                              onTap: _showAllBadges,
                            ),
                            _MenuItem(
                              icon: Icons.cloud_queue_rounded,
                              title: '云端图库',
                              subtitle: '管理你的美好回忆',
                              color: const Color(0xFF86A8E7),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CloudGalleryPage(),
                                  ),
                                );
                              },
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. 每日福利
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 12, bottom: 10),
                            child: Text('每日福利', 
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
                          ),
                          _buildMenuCard([
                            _MenuItem(
                              icon: Icons.calendar_today_rounded,
                              title: '每日签到',
                              subtitle: '连续签到有惊喜哦',
                              color: const Color(0xFF7F7FD5),
                              onTap: () => _navigateToCheckIn(),
                            ),
                            _MenuItem(
                              icon: Icons.account_balance_wallet_rounded,
                              title: '我的钱包',
                              subtitle: '余额: ¥${_user?.balance.toStringAsFixed(2) ?? '0.00'}',
                              color: const Color(0xFF4ECDC4),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const WalletPage()),
                                ).then((value) {
                                  _loadUserInfo();
                                });
                              },
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. 实验室与系统
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 12, bottom: 10),
                            child: Text('实验室与系统', 
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
                          ),
                          _buildMenuCard([
                            _MenuItem(
                              icon: Icons.smart_toy_rounded,
                              title: 'AutoGLM 助手',
                              color: const Color(0xFF7F7FD5),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const AutoGLMPage()),
                                );
                              },
                              // 恢复 AutoGLM 开关
                              trailing: Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: AutoGLMService.enableOverlay,
                                  activeColor: const Color(0xFF7F7FD5),
                                  onChanged: (value) async {
                                    setState(() {
                                      AutoGLMService.enableOverlay = value;
                                    });

                                    if (value) {
                                      bool hasPerm = await AutoGLMService.checkOverlayPermission();
                                      if (!hasPerm) {
                                        await AutoGLMService.requestOverlayPermission();
                                        await Future.delayed(const Duration(seconds: 1));
                                        hasPerm = await AutoGLMService.checkOverlayPermission();
                                        if (!hasPerm) {
                                          setState(() => AutoGLMService.enableOverlay = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('需要悬浮窗权限才能显示')));
                                          }
                                          return;
                                        }
                                      }
                                      await AutoGLMService.showOverlay();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('悬浮窗已开启')));
                                      }
                                    } else {
                                      await AutoGLMService.removeOverlay();
                                    }
                                  },
                                ),
                              ),
                            ),
                            // 移除列表中的“通用设置”
                            _MenuItem(
                              icon: Icons.logout_rounded,
                              title: '退出登录',
                              color: const Color(0xFFFF6B6B),
                              isDestructive: true,
                              onTap: () => _showLogoutDialog(context),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 背景图
        const Positioned.fill(
          child: ProfileBg(),
        ),

        // 用户信息内容
        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 15),
                // 用户头像和基本信息
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
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
                        child: DynamicAvatar(
                          avatarUrl: _user?.avatar ?? '',
                          size: 70,
                          frameId: _user?.equippedFrameId,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user?.username ?? '未知用户',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // 等级胶囊条 (Compact Level Indicator)
                            Consumer<UserLevelProvider>(
                              builder: (context, levelProvider, child) {
                                final userLevel = levelProvider.userLevel;
                                if (userLevel == null) return const SizedBox.shrink();
                                return GestureDetector(
                                  onTap: () => _navigateToUserLevel(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.stars_rounded, size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Lv.${userLevel.level} ${userLevel.levelTitle}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white70),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            // 统计数据
                            Row(
                              children: [
                                _buildStatItemCompact('动态', '$_postCount'),
                                const SizedBox(width: 16),
                                _buildStatItemCompact(
                                  '关注',
                                  '$_followingCount',
                                  onTap: _user != null
                                      ? () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  FollowingPage(userId: _user!.id),
                                            ),
                                          )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                _buildStatItemCompact(
                                  '粉丝',
                                  '$_followerCount',
                                  onTap: _user != null
                                      ? () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  FollowersPage(userId: _user!.id),
                                            ),
                                          )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // 设备信息
                Consumer<DeviceInfoProvider>(
                  builder: (context, provider, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getDeviceIcon(provider.deviceType),
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            provider.deviceType.isNotEmpty ? provider.deviceType : '未知设备',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Container(width: 1, height: 12, color: Colors.white30),
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              provider.locationText.isNotEmpty
                                  ? provider.locationText
                                  : '未知位置',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 移除原先的大块 UserLevelProvider Consumer Card

                // 徽章展示区域
                if (_userBadges.where((badge) => badge.isUnlocked).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _userBadges
                            .where((badge) => badge.isUnlocked)
                            .take(6)
                            .map((badge) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: BadgeCard(
                                    badge: badge,
                                    size: 32, // 稍微加大一点
                                    showProgress: false,
                                    onTap: () => _showBadgeDetails(badge),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'macos':
        return Icons.desktop_mac;
      case 'windows':
        return Icons.window;
      case 'linux':
        return Icons.computer;
      case 'web':
        return Icons.web;
      default:
        return Icons.smartphone;
    }
  }

  Widget _buildStatItemCompact(String label, String value, {VoidCallback? onTap}) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }
    return child;
  }

  Widget _buildVipCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFB347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB347).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VIP 会员中心',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                if (_vipStatus != null && _vipStatus!['expires_at'] != null)
                  Text(
                    '到期: ${_vipStatus!['expires_at']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  const Text(
                    '解锁尊贵特权',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/vip-center');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFFA500),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('立即查看', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: items.map((item) {
          final isLast = items.last == item;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.only(
                    topLeft: items.first == item ? const Radius.circular(24) : Radius.zero,
                    topRight: items.first == item ? const Radius.circular(24) : Radius.zero,
                    bottomLeft: isLast ? const Radius.circular(24) : Radius.zero,
                    bottomRight: isLast ? const Radius.circular(24) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: item.color, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: item.isDestructive ? Colors.redAccent : const Color(0xFF333333),
                                ),
                              ),
                              if (item.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        item.trailing ?? Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.grey[300],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 68, right: 20),
                  child: Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showBadgeDetails(AchievementBadge badge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: badge.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                badge.emoji,
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            if (badge.isUnlocked) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      '已解锁',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAllBadges() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    '我的成就徽章',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: BadgeGrid(
                  badges: _userBadges,
                  badgeSize: 80,
                  crossAxisCount: 3,
                ),
              ),
            ),
          ],
        ),
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
              Navigator.pop(context);
              AuthService.logout();
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _navigateToCheckIn() {
    final userId = AuthService.currentUser;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckInPage(userId: userId),
      ),
    );
  }

  void _navigateToUserLevel() {
    final userId = AuthService.currentUser;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserLevelPage(userId: userId),
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
  final Widget? trailing;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });
}
