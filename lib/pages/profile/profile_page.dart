import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth_service.dart';
import '../../models/achievement_badge.dart';
import '../../models/user.dart';
import '../../providers/user_level_provider.dart';
import '../../services/achievement_service.dart';
import '../../services/commerce_service.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../widgets/achievement_badge_display.dart';
import '../achievements/achievements_page.dart';
import '../../widgets/dynamic_avatar.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_error_state.dart';
import '../../theme/moe_tokens.dart';
import '../../theme/moe_theme_extension.dart';
import '../../utils/main_tab_navigation.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/dialogs/confirm_dialog.dart';
import '../../widgets/profile_bg.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../checkin/checkin_page.dart';
import '../checkin/user_level_page.dart';
import '../commerce/wallet_page.dart';
import '../gallery/cloud_gallery_page.dart';
import 'followers_page.dart';
import 'following_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  MoeTheme get _moe => MoeTheme.of(context);

  User? _user;
  bool _isLoading = true;
  bool _isLoadingDetails = false;
  Object? _loadError;
  bool _isVip = false;
  int _postCount = 0;
  int _followingCount = 0;
  int _followerCount = 0;
  List<AchievementBadge> _userBadges = [];
  final AchievementService _achievementService = AchievementService();

  Future<void>? _ongoingProfileLoad;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadUserInfo({bool forceRefresh = false}) {
    if (_ongoingProfileLoad != null && !forceRefresh) {
      return _ongoingProfileLoad!;
    }
    final f = _loadUserInfoImpl(forceRefresh: forceRefresh);
    _ongoingProfileLoad = f;
    f.whenComplete(() {
      if (identical(_ongoingProfileLoad, f)) _ongoingProfileLoad = null;
    });
    return f;
  }

  Future<void> _loadUserInfoImpl({bool forceRefresh = false}) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = null;
        });
      }
      return;
    }
    final blockingLoad = _user == null;
    if (mounted) {
      setState(() {
        if (blockingLoad) {
          _isLoading = true;
        } else {
          _isLoadingDetails = true;
        }
        _loadError = null;
      });
    }
    try {
      // 与同好页等一致：优先读 AuthService 本地缓存，再按需拉远端
      final user = await AuthService.getUserInfo(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoading = false;
        _isLoadingDetails = true;
        _loadError = null;
      });
      unawaited(_loadProfileDetails(userId));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingDetails = false;
          _loadError = e;
        });
        if (_user != null) {
          MoeToast.error(
            context,
            MoeErrorCopy.toast(e, scene: MoeErrorScene.profile),
          );
        }
      }
    }
  }

  Future<void> _loadProfileDetails(String userId) async {
    try {
      await _achievementService.initializeUserBadges(userId);
      final results = await Future.wait([
        CommerceService.getUserVipStatus(userId)
            .timeout(const Duration(seconds: 5))
            .catchError((_) => <String, dynamic>{}),
        _getCount(
            () => UserService.getFollowings(userId, page: 1, pageSize: 1)),
        _getCount(() => UserService.getFollowers(userId, page: 1, pageSize: 1)),
        _getPostCount(userId),
      ]);
      final vipStatus = results[0] as Map<String, dynamic>;
      final userBadges = _achievementService.getUserBadges(userId);

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final lp = context.read<UserLevelProvider>();
          if (lp.userLevel == null && !lp.isLoading) lp.loadUserLevel(userId);
        }
      });
      if (mounted) {
        setState(() {
          _isVip = vipStatus['is_vip'] as bool? ?? false;
          _followingCount = results[1] as int;
          _followerCount = results[2] as int;
          _postCount = results[3] as int;
          _userBadges = userBadges;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  Future<int> _getCount(Future<Map<String, dynamic>> Function() fn) async {
    try {
      final r = await fn().timeout(const Duration(seconds: 5));
      return r['total'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getPostCount(String userId) async {
    try {
      final viewer = AuthService.currentUser ?? '';
      final r = await PostService.getPosts(
        page: 1,
        pageSize: 1,
        viewerUserId: viewer.isEmpty ? null : viewer,
        authorUserId: userId,
      ).timeout(const Duration(seconds: 8));
      final t = r['total'];
      if (t is int) return t;
      if (t is num) return t.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ─── Navigation helpers ───────────────────────────────────────────────────

  void _openEditProfile() {
    HapticFeedback.lightImpact();
    final u = _user;
    if (u == null) return;
    Navigator.pushNamed(context, '/edit-profile', arguments: u).then((_) {
      if (mounted) _loadUserInfo();
    });
  }

  void _goToMyPosts() {
    final u = _user;
    if (u == null) return;
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/user-profile', arguments: {
      'userId': u.id,
      'userName': u.username,
      'userAvatar': u.avatar,
      'heroTag': 'profile_self_${u.id}',
    });
  }

  void _navigateToCheckIn() {
    final userId = AuthService.currentUser;
    if (userId == null) {
      MoeToast.error(context, '请先登录');
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CheckInPage(userId: userId)));
  }

  void _navigateToUserLevel() {
    final userId = AuthService.currentUser;
    if (userId == null) {
      MoeToast.error(context, '请先登录');
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => UserLevelPage(userId: userId)));
  }

  Future<void> _openVipCenter() async {
    HapticFeedback.lightImpact();
    if (AuthService.currentUser == null) {
      final login = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('先登录再查看'),
          content: const Text('登录后可查看会员权益、套餐和开通记录。'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('稍后再说')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('去登录')),
          ],
        ),
      );
      if (login == true && mounted) {
        await Navigator.pushNamed(context, '/login');
        if (mounted) _loadUserInfo();
      }
      return;
    }
    if (!mounted) return;
    final result = await Navigator.pushNamed(context, '/vip-center');
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && (result == true || !_isVip)) _loadUserInfo();
      });
    }
  }

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showConfirmDialog(
      context,
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      isDestructive: true,
    );
    if (shouldLogout == true) {
      AuthService.logout();
    }
  }

  void _showAllBadges() {
    final uid = _user?.id;
    if (uid == null || uid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AchievementsPage(userId: uid)),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return AdaptivePageScaffold(
        template: PageTemplate.fullscreen,
        backgroundColor: MoeTokens.pageBackground,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildSliverAppBar(),
            SliverFillRemaining(
              child: Center(
                child: MoeLoading(color: MoeTheme.of(context).primary),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadError != null && _user == null) {
      return AdaptivePageScaffold(
        template: PageTemplate.fullscreen,
        backgroundColor: MoeTokens.pageBackground,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildSliverAppBar(),
            SliverFillRemaining(
              child: Center(
                child: MoeErrorState.fromError(
                  _loadError,
                  scene: MoeErrorScene.profile,
                  onRetry: () => _loadUserInfo(forceRefresh: true),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AdaptivePageScaffold(
      template: PageTemplate.fullscreen,
      backgroundColor: MoeTokens.pageBackground,
      body: RefreshIndicator(
        onRefresh: () => _loadUserInfo(forceRefresh: true),
        color: MoeTheme.of(context).primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 84),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick actions
                    MoeReveal(
                        delay: const Duration(milliseconds: 50),
                        child: _buildQuickActions()),
                    const SizedBox(height: 18),
                    MoeReveal(
                      delay: const Duration(milliseconds: 65),
                      child: _menuSection('常用功能', [
                        _MenuItem(
                          icon: Icons.contacts_rounded,
                          title: '同好与联系人',
                          subtitle: '好友、会话与添加申请',
                          color: const Color(0xFFFF6B6B),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushNamed(context, '/friends');
                          },
                        ),
                        _MenuItem(
                          icon: Icons.forum_rounded,
                          title: '兴趣社区',
                          subtitle: '话题、帖子与同好交流',
                          color: const Color(0xFF5B8DEF),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushNamed(context, '/community');
                          },
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    // Achievements preview
                    if (_user != null) ...[
                      MoeReveal(
                          delay: const Duration(milliseconds: 80),
                          child: _buildAchievementsPreview()),
                      const SizedBox(height: 18),
                    ],
                    // Cloud & QR
                    MoeReveal(
                      delay: const Duration(milliseconds: 110),
                      child: _menuSection('云端与相册', [
                        _MenuItem(
                            icon: Icons.cloud_queue_rounded,
                            title: '云端图库',
                            subtitle: '管理你的美好回忆',
                            color: MoeTokens.secondary,
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const CloudGalleryPage()));
                            }),
                        _MenuItem(
                            icon: Icons.qr_code_rounded,
                            title: '我的二维码',
                            subtitle: '让其他用户扫描添加你',
                            color: const Color(0xFF4ECDC4),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pushNamed(context, '/user-qr-code');
                            }),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    // Lab & System
                    MoeReveal(
                      delay: const Duration(milliseconds: 140),
                      child: _menuSection('AI 与设置', [
                        _MenuItem(
                            icon: Icons.smart_toy_rounded,
                            title: 'AI 互动',
                            subtitle: '智能体对话，增强社交互动',
                            color: const Color(0xFFFFB347),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              openMainTab(context, 2);
                            }),
                        _MenuItem(
                            icon: Icons.settings_outlined,
                            title: '通用设置',
                            color: const Color(0xFF90A4AE),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pushNamed(context, '/settings')
                                  .then((_) {
                                if (mounted) _loadUserInfo();
                              });
                            }),
                        _MenuItem(
                            icon: Icons.logout_rounded,
                            title: '退出登录',
                            color: const Color(0xFFFF6B6B),
                            isDestructive: true,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showLogoutDialog();
                            }),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SliverAppBar ─────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    final moe = MoeTheme.of(context);
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      stretch: true,
      backgroundColor: moe.primary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('我的',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          if (_isLoadingDetails) ...[
            const SizedBox(width: 8),
            const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70))),
          ],
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, '/settings').then((_) {
              if (mounted) _loadUserInfo();
            });
          },
        ),
        IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: _openEditProfile),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeader(),
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
        ],
      ),
    );
  }

  // ─── Header (avatar + name + stats) ──────────────────────────────────────

  Widget _buildHeader() {
    final primaryGlow = _moe.primary;
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
                  Colors.black.withValues(alpha: 0.12)
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                MoeReveal(
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
                                offset: const Offset(0, 10))
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: DynamicAvatar(
                              avatarUrl: _user?.avatar ?? '',
                              size: 78,
                              frameId: _user?.equippedFrameId),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Name + VIP
                MoeReveal(
                  delay: const Duration(milliseconds: 120),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(_user?.username ?? '未知用户',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (_isVip) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: const Color(0xFFFFE082)
                                    .withValues(alpha: 0.95)),
                          ),
                          child: const Text('VIP',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFF8E1))),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Signature
                MoeReveal(
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
                          color: Colors.white
                              .withValues(alpha: sig.isEmpty ? 0.55 : 0.9),
                          fontStyle:
                              sig.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Moe-No + Level pills
                MoeReveal(
                  delay: const Duration(milliseconds: 160),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((_user?.moeNo ?? '').isNotEmpty)
                        _glassPill(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: _user!.moeNo));
                            MoeToast.success(context, '已复制 Moe 号');
                          },
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.badge_outlined,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.9)),
                            const SizedBox(width: 5),
                            Text(_user!.moeNo,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.75)),
                          ]),
                        ),
                      Consumer<UserLevelProvider>(
                        builder: (_, lp, __) {
                          final ul = lp.userLevel;
                          if (ul == null) return const SizedBox.shrink();
                          return _glassPill(
                            onTap: _navigateToUserLevel,
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.stars_rounded,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text('Lv.${ul.level} ${ul.levelTitle}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.7)),
                            ]),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Stats bar — each item is a tap target
                MoeReveal(
                  delay: const Duration(milliseconds: 200),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.26),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.42)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: _statItem('动态', '$_postCount',
                                    onTap: _goToMyPosts)),
                            _vDivider(),
                            Expanded(
                              child: _statItem('关注', '$_followingCount',
                                  onTap: _user != null
                                      ? () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => FollowingPage(
                                                      userId: _user!.id)));
                                        }
                                      : null),
                            ),
                            _vDivider(),
                            Expanded(
                              child: _statItem('粉丝', '$_followerCount',
                                  onTap: _user != null
                                      ? () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => FollowersPage(
                                                      userId: _user!.id)));
                                        }
                                      : null),
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

  Widget _glassPill({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: child)),
    );
  }

  Widget _statItem(String label, String value, {VoidCallback? onTap}) {
    final col = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1E2E),
              height: 1.05)),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E1E2E).withValues(alpha: 0.52))),
    ]);
    if (onTap != null) {
      return Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: col)));
    }
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: col);
  }

  Widget _vDivider() => Container(
      width: 1, height: 32, color: Colors.white.withValues(alpha: 0.35));

  // ─── Quick Actions ────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final unlockedBadges = _userBadges.where((b) => b.isUnlocked).length;
    final actions = [
      _QuickAction(
        icon: Icons.event_available_rounded,
        iconColor: const Color(0xFF5A67D8),
        label: '签到',
        subtitle: '每日奖励',
        onTap: _navigateToCheckIn,
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: const Color(0xFFFF8F00),
        label: '钱包',
        subtitle: '¥${_user?.balance.toStringAsFixed(2) ?? '0.00'}',
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WalletPage())).then((_) {
            if (mounted) _loadUserInfo();
          });
        },
      ),
      _QuickAction(
        icon: _isVip ? Icons.workspace_premium_rounded : Icons.diamond_rounded,
        iconColor: _isVip ? const Color(0xFFFFB347) : _moe.primary,
        label: '会员',
        subtitle: _isVip ? '权益生效中' : '开通享特权',
        isCta: !_isVip,
        onTap: _openVipCenter,
      ),
      _QuickAction(
        icon: Icons.military_tech_rounded,
        iconColor: const Color(0xFFE65100),
        label: '成就',
        subtitle: '$unlockedBadges 枚已解锁',
        badge: unlockedBadges,
        onTap: _showAllBadges,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: actions.map((a) {
          return Expanded(child: _buildQuickActionCard(a));
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    final isCta = action.isCta;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 120,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: action.iconColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          action.icon,
                          size: 20,
                          color: action.iconColor,
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          action.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F3142),
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          action.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color:
                                isCta ? _moe.primary : const Color(0xFF76798D),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (action.badge != null && action.badge! > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: const BoxDecoration(
                            color: Color(0xFFFF6B35), shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            '${action.badge}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Achievement preview strip ────────────────────────────────────────────

  Widget _buildAchievementsPreview() {
    final stats = _achievementService.getBadgeStatistics(_user!.id);
    final unlocked = _userBadges.where((b) => b.isUnlocked).toList();
    final inProgress = _userBadges
        .where((b) => !b.isUnlocked && b.progress > 0)
        .take(3)
        .toList();
    final preview = [...unlocked.take(5), ...inProgress];

    return GestureDetector(
      onTap: _showAllBadges,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: _moe.primary.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge preview strip
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('成就徽章',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF333333))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFB347).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            '${stats.unlockedBadges}/${stats.totalBadges}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stats.totalBadges == 0
                        ? '开始任务，点亮你的第一枚徽章'
                        : '已完成 ${(stats.totalBadges > 0 ? stats.unlockedBadges * 100 ~/ stats.totalBadges : 0)}%',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  preview.isEmpty
                      ? Text('完成任务解锁成就 →',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 11.5))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...preview.take(4).map(
                                  (b) => SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: MiniBadge(
                                      badge: b,
                                      size: 32,
                                    ),
                                  ),
                                ),
                            if (preview.length > 4)
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Center(
                                  child: Text(
                                    '+${preview.length - 4}',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[500]),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: stats.totalBadges > 0
                            ? stats.unlockedBadges / stats.totalBadges
                            : 0,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey.shade200,
                        color: _moe.primary,
                      ),
                      Text(
                        '${stats.totalBadges > 0 ? (stats.unlockedBadges * 100 ~/ stats.totalBadges) : 0}%',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _moe.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text('查看',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500])),
                Icon(Icons.chevron_right_rounded,
                    size: 17, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Menu section ─────────────────────────────────────────────────────────

  Widget _menuSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: _moe.primary.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
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
                        topLeft: items.first == item
                            ? const Radius.circular(24)
                            : Radius.zero,
                        topRight: items.first == item
                            ? const Radius.circular(24)
                            : Radius.zero,
                        bottomLeft:
                            isLast ? const Radius.circular(24) : Radius.zero,
                        bottomRight:
                            isLast ? const Radius.circular(24) : Radius.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(13)),
                              child:
                                  Icon(item.icon, color: item.color, size: 21),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: item.isDestructive
                                              ? Colors.redAccent
                                              : const Color(0xFF333333))),
                                  if (item.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(item.subtitle!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400])),
                                  ],
                                ],
                              ),
                            ),
                            item.trailing ??
                                Icon(Icons.arrow_forward_ios_rounded,
                                    color: Colors.grey[300], size: 15),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 60, right: 20),
                      child: Divider(
                          height: 1,
                          color: Colors.grey.withValues(alpha: 0.08)),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Row(children: [
        Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: _moe.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(t,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D2D3D),
                letterSpacing: 0.2)),
      ]);
}

// ─── Helper data models ──────────────────────────────────────────────────────

class _QuickAction {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool isCta;
  final int? badge;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isCta = false,
    this.badge,
  });
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;
  _MenuItem(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.color,
      required this.onTap,
      this.isDestructive = false,
      this.trailing});
}
