import 'package:provider/provider.dart';
import 'providers/device_info_provider.dart';
import 'package:flutter/material.dart';
import 'pages/autoglm_page.dart';
import 'autoglm/autoglm_service.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/user.dart';
import 'models/post.dart';
import 'models/achievement_badge.dart';
import 'services/achievement_service.dart';
import 'widgets/dynamic_avatar.dart';
import 'widgets/achievement_badge_display.dart';
import 'wallet_page.dart';
import 'widgets/fade_in_up.dart';
import 'gallery/cloud_gallery_page.dart';
import 'pages/checkin_page.dart';
import 'pages/user_level_page.dart';
import 'providers/user_level_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  Map<String, dynamic>? _vipStatus;
  bool _isLoading = true;
  bool _isLoadingDetails = false; // 用于跟踪详细信息加载状态
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
      // 优化：分批加载，核心信息优先
      // 第一阶段：加载核心用户信息（最重要，最快）
      final user = await ApiService.getUserInfo(userId)
          .timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false; // 基本信息已加载，可以显示页面
          _isLoadingDetails = true; // 开始加载详细信息
        });
      }

      // 第二阶段：并行加载其他信息，但设置合理超时
      final results = await Future.wait([
        // VIP状态
        ApiService.getUserVipStatus(userId)
            .timeout(const Duration(seconds: 5))
            .catchError((_) => <String, dynamic>{}),

        // 关注数（限制为只获取总数，不获取具体列表）
        _getFollowingCount(userId),

        // 粉丝数（限制为只获取总数）
        _getFollowerCount(userId),

        // 帖子数量（优化：应该从用户信息API获取，而不是获取所有帖子）
        _getUserPostCount(userId),
      ]);

      final vipStatus = results[0] as Map<String, dynamic>;
      final followingCount = results[1] as int;
      final followerCount = results[2] as int;
      final postCount = results[3] as int;

      bool isVip = vipStatus['is_vip'] as bool? ?? false;

      // 第三阶段：加载用户徽章和等级信息（非关键信息，可以后加载）
      final userBadges = _achievementService.getUserBadges(userId);

      // 预先触发用户等级加载，避免在UI构建时才开始请求
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
          _isLoadingDetails = false; // 详细信息加载完成
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
            content: Text('加载个人信息失败，请检查网络连接'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _loadUserInfo,
            ),
          ),
        );
      }
    }
  }

  /// 优化：获取关注数量
  Future<int> _getFollowingCount(String userId) async {
    try {
      final result = await ApiService.getFollowings(userId, page: 1, pageSize: 1)
          .timeout(const Duration(seconds: 5));
      return result['total'] as int? ?? 0;
    } catch (e) {
      return 0; // 失败时返回0，不影响页面显示
    }
  }

  /// 优化：获取粉丝数量
  Future<int> _getFollowerCount(String userId) async {
    try {
      final result = await ApiService.getFollowers(userId, page: 1, pageSize: 1)
          .timeout(const Duration(seconds: 5));
      return result['total'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 优化：获取用户帖子数量
  Future<int> _getUserPostCount(String userId) async {
    try {
      // TODO: 应该添加专门的API获取用户帖子数量
      // 临时方案：获取较少的帖子进行过滤，减少网络传输
      final result = await ApiService.getPosts(page: 1, pageSize: 20)
          .timeout(const Duration(seconds: 8));
      final posts = result['posts'] as List<Post>;

      // 这里仍然是客户端过滤，但至少减少了数据量
      // 最佳方案是后端提供专门的用户帖子计数API
      return posts
          .where((p) => p.userId.toString() == userId.toString())
          .length;
    } catch (e) {
      return 0; // 失败时返回0，不影响页面显示
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      // 完全加载状态：显示更友好的加载界面
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF7F7FD5),
              ),
              const SizedBox(height: 16),
              Text(
                '正在加载个人信息...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '首次加载可能需要几秒钟',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadUserInfo,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 420.0,
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
                IconButton(
                  icon:
                      const Icon(Icons.settings_outlined, color: Colors.white),
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
                    const SizedBox(height: 20),
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
                          icon: Icons.military_tech_outlined,
                          title: '成就徽章',
                          subtitle:
                              '已解锁 ${_userBadges.where((b) => b.isUnlocked).length} 个',
                          color: Colors.amber,
                          onTap: _showAllBadges,
                        ),
                        _MenuItem(
                          icon: Icons.calendar_today_rounded,
                          title: '每日签到',
                          subtitle: '签到获取经验，提升等级',
                          color: const Color(0xFF7F7FD5),
                          onTap: () => _navigateToCheckIn(),
                        ),
                        _MenuItem(
                          icon: Icons.cloud_outlined,
                          title: '云端图库',
                          subtitle: '上传/管理你的图片云盘',
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
                        _MenuItem(
                          icon: Icons.favorite_border_rounded,
                          title: '我的收藏',
                          color: Colors.pinkAccent,
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.face_rounded,
                          title: '编辑形象',
                          color: Colors.blueAccent,
                          onTap: () {
                            Navigator.pushNamed(context, '/avatar-editor');
                          },
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
                          subtitle:
                              '余额: ¥${_user?.balance.toStringAsFixed(2) ?? '0.00'}',
                          color: Colors.green,
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
                        _MenuItem(
                          icon: Icons.help_outline_rounded,
                          title: '帮助与反馈',
                          color: Colors.purpleAccent,
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.smart_toy_outlined,
                          title: 'AutoGLM 助手',
                          color: Colors.indigoAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const AutoGLMPage()),
                            );
                          },
                          trailing: Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: AutoGLMService.enableOverlay,
                              activeColor: Colors.indigoAccent,
                              onChanged: (value) async {
                                setState(() {
                                  AutoGLMService.enableOverlay = value;
                                });

                                // 调用 Service 控制悬浮窗
                                if (value) {
                                  // 检查权限
                                  bool hasPerm = await AutoGLMService
                                      .checkOverlayPermission();
                                  if (!hasPerm) {
                                    await AutoGLMService
                                        .requestOverlayPermission();
                                    // 简单等待一下
                                    await Future.delayed(
                                        const Duration(seconds: 1));
                                    hasPerm = await AutoGLMService
                                        .checkOverlayPermission();
                                    if (!hasPerm) {
                                      setState(() =>
                                          AutoGLMService.enableOverlay = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('需要悬浮窗权限才能显示')));
                                      return;
                                    }
                                  }
                                  await AutoGLMService.showOverlay();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('悬浮窗已开启')));
                                } else {
                                  await AutoGLMService.removeOverlay();
                                }
                              },
                            ),
                          ),
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
        // 背景图 - 充满整个 FlexibleSpaceBar
        Container(
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
        // 使用 SafeArea 确保内容不被顶部遮挡，并居中显示
        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 15),
                // 用户头像和基本信息的水平布局
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
                            const SizedBox(height: 2),
                            Text(
                              _user?.email ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 统计数据紧凑显示
                            Row(
                              children: [
                                _buildStatItemCompact('动态', '$_postCount'),
                                const SizedBox(width: 16),
                                _buildStatItemCompact('关注', '$_followingCount'),
                                const SizedBox(width: 16),
                                _buildStatItemCompact('粉丝', '$_followerCount'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                // 设备信息完整显示
                Consumer<DeviceInfoProvider>(
                  builder: (context, provider, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getDeviceIcon(provider.deviceType),
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    provider.deviceType.isNotEmpty ? provider.deviceType : '未知设备',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      provider.batteryLevel != null && provider.batteryLevel! < 20
                                          ? Icons.battery_alert
                                          : Icons.battery_std,
                                      color: Colors.white,
                                      size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    provider.batteryLevel != null
                                        ? '${provider.batteryLevel}%'
                                        : '未知',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.wifi, color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        provider.wifiName.isNotEmpty ? provider.wifiName : '未连接',
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        provider.locationText.isNotEmpty
                                            ? provider.locationText
                                            : (provider.latitude != null
                                                ? '${provider.latitude!.toStringAsFixed(2)}, ${provider.longitude!.toStringAsFixed(2)}'
                                                : '未知'),
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
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
                  },
                ),

                // 用户等级信息
                Consumer<UserLevelProvider>(
                  builder: (context, levelProvider, child) {
                    // 在页面加载时获取用户等级信息
                    if (levelProvider.userLevel == null && !levelProvider.isLoading) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final userId = AuthService.currentUser;
                        if (userId != null) {
                          levelProvider.loadUserLevel(userId);
                        }
                      });
                    }

                    if (levelProvider.userLevel != null) {
                      final userLevel = levelProvider.userLevel!;
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _navigateToUserLevel(),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: levelProvider.getLevelGradient(userLevel.level),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.star_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userLevel.levelTitle,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Lv.${userLevel.level} • ${userLevel.experience}/${userLevel.nextLevelExp} EXP',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // 进度条
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: userLevel.progress,
                                      backgroundColor: Colors.white.withOpacity(0.25),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      minHeight: 5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    userLevel.isMaxLevel
                                        ? '已达到最高等级！'
                                        : '距离下一级还需 ${userLevel.expToNext} 经验',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // 徽章展示区域
                if (_userBadges
                    .where((badge) => badge.isUnlocked)
                    .isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 32), // 增加边距防止太宽
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.military_tech,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              '成就徽章',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _userBadges
                                .where((badge) => badge.isUnlocked)
                                .take(6) // 最多显示6个徽章
                                .map((badge) => Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: BadgeCard(
                                        badge: badge,
                                        size: 28,
                                        showProgress: false,
                                        onTap: () => _showBadgeDetails(badge),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
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

  Widget _buildDeviceInfo(DeviceInfoProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getDeviceIcon(provider.deviceType),
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                provider.deviceType.isNotEmpty ? provider.deviceType : '未知设备',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(
                  provider.batteryLevel != null && provider.batteryLevel! < 20
                      ? Icons.battery_alert
                      : Icons.battery_std,
                  color: Colors.white,
                  size: 16),
              const SizedBox(width: 6),
              Text(
                provider.batteryLevel != null
                    ? '${provider.batteryLevel}%'
                    : '未知',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  provider.wifiName.isNotEmpty ? provider.wifiName : '未连接',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.location_on_outlined,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  provider.locationText.isNotEmpty
                      ? provider.locationText
                      : (provider.latitude != null
                          ? '${provider.latitude!.toStringAsFixed(2)}, ${provider.longitude!.toStringAsFixed(2)}'
                          : '未知'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatItemCompact(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.8), fontSize: 11)),
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
          // 在 Web 的某些约束组合下 Row 子节点可能拿到 Infinity 宽度，导致按钮 layout 断言失败
          // 这里显式用 Expanded 给中间文案区域一个“可计算宽度”，并给按钮一个有限宽度，避免白屏
          Expanded(
            child: Column(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  const Text(
                    '开通享特权',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/vip-center');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: const Text('立即查看'),
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
                    ? Text(item.subtitle!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                    : null,
                trailing: item.trailing ??
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.grey, size: 20),
                onTap: item.onTap,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              if (!isLast) const Divider(height: 1, indent: 60, endIndent: 20),
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
            // 顶部拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
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
            // 徽章网格
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

  /// 导航到签到页面
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

  /// 导航到AutoGLM助手页面
  void _navigateToAutoGLM() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AutoGLMPage(),
      ),
    );
  }

  /// 导航到用户等级页面
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
  final Widget? trailing; // 自定义尾部组件

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
