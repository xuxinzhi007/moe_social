import 'dart:ui' show ImageFilter;

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../autoglm/autoglm_page.dart';
import '../../autoglm/autoglm_service.dart'; // 恢复导入
import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../models/achievement_badge.dart';
import '../../services/achievement_service.dart';
import '../../widgets/dynamic_avatar.dart';
import '../../widgets/achievement_badge_display.dart';
import '../../widgets/profile_bg.dart';
import '../commerce/wallet_page.dart';
import '../gallery/cloud_gallery_page.dart';
import '../checkin/checkin_page.dart';
import '../checkin/user_level_page.dart';
import '../../providers/user_level_provider.dart';
import 'following_page.dart';
import 'followers_page.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_loading.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
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

      await _achievementService.initializeUserBadges(userId);

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
        MoeToast.error(context, '加载个人信息失败，请检查网络连接');
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
      final viewer =
          AuthService.isLoggedIn ? (AuthService.currentUser ?? '') : '';
      final result = await ApiService.getPosts(
        page: 1,
        pageSize: 1,
        viewerUserId: viewer.isEmpty ? null : viewer,
        authorUserId: userId,
      ).timeout(const Duration(seconds: 8));
      final total = result['total'];
      if (total is int) return total;
      if (total is num) return total.toInt();
      return 0;
    } catch (e) {
      return 0;
    }
  }

  void _openEditProfile() {
    HapticFeedback.lightImpact();
    final u = _user;
    if (u == null) return;
    Navigator.pushNamed(context, '/edit-profile', arguments: u).then((_) {
      if (mounted) _loadUserInfo();
    });
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
              MoeLoading(color: Color(0xFF7F7FD5)),
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
              expandedHeight: 352,
              pinned: true,
              stretch: true,
              backgroundColor: const Color(0xFF7F7FD5),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '我的',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
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
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/settings').then((_) {
                      _loadUserInfo();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: _openEditProfile,
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
                    const SizedBox(height: 8),

                    if (_user != null) ...[
                      FadeInUp(
                        delay: const Duration(milliseconds: 50),
                        child: _buildAchievementPreviewCard(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 云端图库（发动态 / 好友 / 签到等在首页快捷或底栏，避免此处再堆一层入口）
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileSectionTitle('云端与相册'),
                          _buildMenuCard([
                            _MenuItem(
                              icon: Icons.cloud_queue_rounded,
                              title: '云端图库',
                              subtitle: '管理你的美好回忆',
                              color: const Color(0xFF86A8E7),
                              onTap: () async {
                                HapticFeedback.lightImpact();
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
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileSectionTitle('每日福利'),
                          _buildMenuCard([
                            _MenuItem(
                              icon: Icons.calendar_today_rounded,
                              title: '每日签到',
                              subtitle: '连续签到有惊喜哦',
                              color: const Color(0xFF7F7FD5),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _navigateToCheckIn();
                              },
                            ),
                            _MenuItem(
                              icon: Icons.account_balance_wallet_rounded,
                              title: '我的钱包',
                              subtitle: '余额: ¥${_user?.balance.toStringAsFixed(2) ?? '0.00'}',
                              color: const Color(0xFF4ECDC4),
                              onTap: () {
                                HapticFeedback.lightImpact();
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
                              icon: Icons.workspace_premium_rounded,
                              title: 'VIP 会员中心',
                              subtitle: AuthService.currentUser == null
                                  ? '登录后查看会员权益与套餐'
                                  : (_isVip ? '查看会员状态与续费信息' : '开通 VIP，解锁更多特权'),
                              color: const Color(0xFFFFB347),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _openVipCenter();
                              },
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. 实验室与系统
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileSectionTitle('实验室与系统'),
                          _buildMenuCard([
                              _MenuItem(
                                icon: Icons.smart_toy_rounded,
                                title: 'AutoGLM 助手',
                                color: const Color(0xFF7F7FD5),
                                onTap: () {
                                  HapticFeedback.lightImpact();
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
                                      HapticFeedback.lightImpact();
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
                                              MoeToast.error(context, '需要悬浮窗权限才能显示');
                                            }
                                            return;
                                          }
                                        }
                                        await AutoGLMService.showOverlay();
                                        if (mounted) {
                                          MoeToast.success(context, '悬浮窗已开启');
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
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showLogoutDialog(context);
                                },
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
    const primaryGlow = Color(0xFF7F7FD5);
    final sig = (_user?.signature ?? '').trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: ProfileBg()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.14),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeInUp(
                  delay: const Duration(milliseconds: 80),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openEditProfile,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryGlow.withValues(alpha: 0.38),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: DynamicAvatar(
                            avatarUrl: _user?.avatar ?? '',
                            size: 82,
                            frameId: _user?.equippedFrameId,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeInUp(
                  delay: const Duration(milliseconds: 120),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _user?.username ?? '未知用户',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isVip) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFFFE082).withValues(alpha: 0.95),
                            ),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFFF8E1),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FadeInUp(
                  delay: const Duration(milliseconds: 140),
                  child: GestureDetector(
                    onTap: _openEditProfile,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        sig.isEmpty ? '点击添加个性签名' : sig,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.white.withValues(
                            alpha: sig.isEmpty ? 0.58 : 0.9,
                          ),
                          fontStyle:
                              sig.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeInUp(
                  delay: const Duration(milliseconds: 160),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((_user?.moeNo ?? '').isNotEmpty)
                        Material(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _user!.moeNo),
                              );
                              MoeToast.success(context, '已复制 Moe 号');
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 15,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _user!.moeNo,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Consumer<UserLevelProvider>(
                        builder: (context, levelProvider, child) {
                          final userLevel = levelProvider.userLevel;
                          if (userLevel == null) {
                            return const SizedBox.shrink();
                          }
                          return Material(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _navigateToUserLevel();
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.stars_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Lv.${userLevel.level} ${userLevel.levelTitle}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.26),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildHeaderStatItem(
                                '动态',
                                '$_postCount',
                                onTap: _user != null
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        Navigator.pushNamed(
                                          context,
                                          '/user-profile',
                                          arguments: {
                                            'userId': _user!.id,
                                            'userName': _user!.username,
                                            'userAvatar': _user!.avatar,
                                            'heroTag':
                                                'profile_self_${_user!.id}',
                                          },
                                        );
                                      }
                                    : null,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 34,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            Expanded(
                              child: _buildHeaderStatItem(
                                '关注',
                                '$_followingCount',
                                onTap: _user != null
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (context) => FollowingPage(
                                              userId: _user!.id,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 34,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            Expanded(
                              child: _buildHeaderStatItem(
                                '粉丝',
                                '$_followerCount',
                                onTap: _user != null
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (context) => FollowersPage(
                                              userId: _user!.id,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStatItem(
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    const valueStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: Color(0xFF1E1E2E),
      height: 1.05,
    );
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF1E1E2E).withValues(alpha: 0.52),
    );
    final col = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: valueStyle),
        const SizedBox(height: 4),
        Text(label, style: labelStyle),
      ],
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: col,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: col,
    );
  }

  Widget _buildProfileSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF7F7FD5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D2D3D),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  List<AchievementBadge> _badgesSortedForPreview() {
    final list = List<AchievementBadge>.from(_userBadges);
    list.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
      return b.progress.compareTo(a.progress);
    });
    return list;
  }

  /// 徽章横条高度：随系统字号缩放，避免固定像素导致 dense [BadgeCard] 纵向溢出。
  double _achievementBadgeStripHeight(BuildContext context) {
    final scaled = MediaQuery.of(context).textScaler.scale(130.0);
    return scaled.clamp(108.0, 248.0);
  }

  Widget _buildAchievementPreviewCard() {
    final stats = _achievementService.getBadgeStatistics(_user!.id);
    final sorted = _badgesSortedForPreview();
    final showCount = sorted.length > 12 ? 12 : sorted.length;
    final stripH = _achievementBadgeStripHeight(context);
    const cardW = 72.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '成就徽章',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${stats.unlockedBadges}/${stats.totalBadges}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAllBadges();
                },
                child: const Text('全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.totalBadges > 0
                  ? stats.unlockedBadges / stats.totalBadges
                  : 0,
              minHeight: 6,
              backgroundColor: const Color(0xFFF0F0F5),
              color: const Color(0xFF7F7FD5),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: stripH,
            child: showCount == 0
                ? Center(
                    child: Text(
                      '暂无徽章数据',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 2),
                    clipBehavior: Clip.hardEdge,
                    itemCount: showCount,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final b = sorted[i];
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: cardW,
                          height: stripH,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: cardW,
                              child: BadgeCard(
                                badge: b,
                                size: cardW,
                                dense: true,
                                showProgress: true,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showBadgeDetails(b);
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (stats.unlockedBadges == 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '发帖、评论、签到可积累进度并解锁成就',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openVipCenter() async {
    if (AuthService.currentUser == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('先登录再查看'),
          content: const Text('登录后可查看会员权益、套餐和开通记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去登录'),
            ),
          ],
        ),
      );

      if (shouldLogin == true && mounted) {
        await Navigator.pushNamed(context, '/login');
        if (mounted) {
          _loadUserInfo();
        }
      }
      return;
    }

    if (!mounted) return;
    final result = await Navigator.pushNamed(context, '/vip-center');
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && (result == true || _isVip == false)) {
          _loadUserInfo();
        }
      });
    }
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
            if (!badge.isUnlocked && badge.progress > 0) ...[
              const SizedBox(height: 12),
              Text(
                '进度 ${(badge.progress * 100).toStringAsFixed(0)}% · ${badge.condition}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
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
                  showProgress: true,
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
      MoeToast.error(context, '请先登录');
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
      MoeToast.error(context, '请先登录');
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
