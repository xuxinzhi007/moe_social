import 'dart:async';

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
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_error_state.dart';
import '../../theme/moe_tokens.dart';
import '../../theme/moe_theme_extension.dart';
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
  bool _hasDetailsError = false;
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
    final badges = _loadDetail(
      () async {
        await _achievementService.initializeUserBadges(userId);
        return _achievementService.getUserBadges(userId);
      },
      const <AchievementBadge>[],
    );
    final vip = _loadDetail(
      () => CommerceService.getUserVipStatus(userId)
          .timeout(const Duration(seconds: 5)),
      <String, dynamic>{},
    );
    final following = _loadDetail(
      () => _getCount(
        () => UserService.getFollowings(userId, page: 1, pageSize: 1),
      ),
      0,
    );
    final followers = _loadDetail(
      () => _getCount(
        () => UserService.getFollowers(userId, page: 1, pageSize: 1),
      ),
      0,
    );
    final posts = _loadDetail(() => _getPostCount(userId), 0);

    final results =
        await Future.wait([badges, vip, following, followers, posts]);
    if (!mounted) return;

    final badgesResult = results[0] as _ProfileDetail<List<AchievementBadge>>;
    final vipResult = results[1] as _ProfileDetail<Map<String, dynamic>>;
    final followingResult = results[2] as _ProfileDetail<int>;
    final followersResult = results[3] as _ProfileDetail<int>;
    final postsResult = results[4] as _ProfileDetail<int>;
    final hasDetailsError = results.any((result) => !result.didLoad);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final lp = context.read<UserLevelProvider>();
        if (lp.userLevel == null && !lp.isLoading) lp.loadUserLevel(userId);
      }
    });
    setState(() {
      if (vipResult.didLoad) {
        _isVip = vipResult.value['is_vip'] as bool? ?? false;
      }
      if (followingResult.didLoad) _followingCount = followingResult.value;
      if (followersResult.didLoad) _followerCount = followersResult.value;
      if (postsResult.didLoad) _postCount = postsResult.value;
      if (badgesResult.didLoad) _userBadges = badgesResult.value;
      _hasDetailsError = hasDetailsError;
      _isLoadingDetails = false;
    });
  }

  Future<_ProfileDetail<T>> _loadDetail<T>(
    Future<T> Function() loader,
    T fallback,
  ) async {
    try {
      return _ProfileDetail(value: await loader(), didLoad: true);
    } catch (_) {
      return _ProfileDetail(value: fallback, didLoad: false);
    }
  }

  Future<int> _getCount(Future<Map<String, dynamic>> Function() fn) async {
    final r = await fn().timeout(const Duration(seconds: 5));
    return r['total'] as int? ?? 0;
  }

  Future<int> _getPostCount(String userId) async {
    final viewer = AuthService.currentUser ?? '';
    final r = await PostService.getPosts(
      page: 1,
      pageSize: 1,
      viewerUserId: viewer.isEmpty ? null : viewer,
      authorUserId: userId,
    ).timeout(const Duration(seconds: 8));
    final total = r['total'];
    if (total is int) return total;
    if (total is num) return total.toInt();
    return 0;
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
        backgroundColor: MoeTheme.of(context).pageBackground,
        body: Column(
          children: [
            _buildPinnedHeader(),
            Expanded(
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
        backgroundColor: MoeTheme.of(context).pageBackground,
        body: Column(
          children: [
            _buildPinnedHeader(),
            Expanded(
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
      backgroundColor: MoeTheme.of(context).pageBackground,
      body: Column(
        children: [
          _buildPinnedHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadUserInfo(forceRefresh: true),
              color: MoeTheme.of(context).primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
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
                                  color: MoeTokens.pastelTeal,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.pushNamed(
                                        context, '/user-qr-code');
                                  }),
                            ]),
                          ),
                          const SizedBox(height: 20),
                          // 设置入口仅 AppBar 齿轮（单一入口）；此处只放账号危险操作
                          MoeReveal(
                            delay: const Duration(milliseconds: 140),
                            child: _menuSection('账号', [
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
          ),
        ],
      ),
    );
  }

  /// 资料头固定在顶部，不随列表收起，避免头像和名字被裁成半截。
  Widget _buildPinnedHeader() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(MoeTokens.radiusXl),
        ),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(MoeTokens.radiusXl),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: ProfileBg()),
            SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: kToolbarHeight,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasDetailsError)
                            IconButton(
                              tooltip: '刷新资料明细',
                              onPressed: _isLoadingDetails || _user == null
                                  ? null
                                  : () {
                                      setState(() => _isLoadingDetails = true);
                                      unawaited(
                                        _loadProfileDetails(_user!.id),
                                      );
                                    },
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.settings_outlined,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pushNamed(context, '/settings').then((
                                _,
                              ) {
                                if (mounted) _loadUserInfo();
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                            ),
                            onPressed: _openEditProfile,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildHeader(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header (avatar + name + stats) ──────────────────────────────────────

  Widget _buildHeader() {
    final sig = (_user?.signature ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              MoePressable(
                onTap: _openEditProfile,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: DynamicAvatar(
                    avatarUrl: _user?.avatar ?? '',
                    size: 52,
                    frameId: _user?.equippedFrameId,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _user?.username ?? '未知用户',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (_isVip) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(
                                MoeTokens.radiusFull,
                              ),
                              border: Border.all(
                                color: const Color(0xFFFFE082)
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFF8E1),
                              ),
                            ),
                          ),
                        ],
                        if (_isLoadingDetails) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: _openEditProfile,
                      child: Text(
                        sig.isEmpty ? '添加签名' : sig,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(
                            alpha: sig.isEmpty ? 0.62 : 0.9,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if ((_user?.moeNo ?? '').isNotEmpty)
                          _glassPill(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _user!.moeNo),
                              );
                              MoeToast.success(context, '已复制 Moe 号');
                            },
                            child: Text(
                              _user!.moeNo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Consumer<UserLevelProvider>(
                          builder: (_, lp, __) {
                            final ul = lp.userLevel;
                            if (ul == null) return const SizedBox.shrink();
                            return _glassPill(
                              onTap: _navigateToUserLevel,
                              child: Text(
                                'Lv.${ul.level}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statItem('动态', '$_postCount', onTap: _goToMyPosts),
              _statItem(
                '关注',
                '$_followingCount',
                onTap: _user == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowingPage(userId: _user!.id),
                          ),
                        );
                      },
              ),
              _statItem(
                '粉丝',
                '$_followerCount',
                onTap: _user == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowersPage(userId: _user!.id),
                          ),
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassPill({required Widget child, required VoidCallback onTap}) {
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        ),
        child: child,
      ),
    );
  }

  Widget _statItem(String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Quick Actions ────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final unlockedBadges = _userBadges.where((b) => b.isUnlocked).length;
    final actions = [
      _QuickAction(
        icon: Icons.event_available_rounded,
        iconColor: MoeTokens.primary,
        label: '签到',
        subtitle: '每日奖励',
        onTap: _navigateToCheckIn,
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: MoeTokens.pastelOrange,
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
        iconColor: _isVip ? MoeTokens.pastelOrange : _moe.primary,
        label: '会员',
        subtitle: _isVip ? '权益生效中' : '开通享特权',
        isCta: !_isVip,
        onTap: _openVipCenter,
      ),
      _QuickAction(
        icon: Icons.military_tech_rounded,
        iconColor: MoeTokens.warning,
        label: '成就',
        subtitle: '$unlockedBadges 枚已解锁',
        badge: unlockedBadges,
        onTap: _showAllBadges,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
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
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          child: SizedBox(
            height: 104,
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
                            color: MoeTokens.titleText,
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
                            color: isCta ? _moe.primary : MoeTokens.hintText,
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
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowSm(),
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
                              color: MoeTokens.titleText)),
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
            color: MoeTokens.surface1,
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            border: Border.all(color: MoeTokens.surfaceBorder),
            boxShadow: MoeTokens.shadowSm(),
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
                                              ? MoeTokens.danger
                                              : MoeTokens.titleText)),
                                  if (item.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(item.subtitle!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: MoeTokens.hintText)),
                                  ],
                                ],
                              ),
                            ),
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
                      child: Divider(height: 1, color: MoeTokens.surfaceBorder),
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

class _ProfileDetail<T> {
  const _ProfileDetail({required this.value, required this.didLoad});

  final T value;
  final bool didLoad;
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;
  _MenuItem(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.color,
      required this.onTap,
      this.isDestructive = false});
}
