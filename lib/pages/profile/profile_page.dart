import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth_service.dart';
import '../../providers/user_level_provider.dart';
import '../../widgets/achievement_badge_display.dart';
import '../../widgets/dynamic_avatar.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_menu_card.dart';
import '../../theme/moe_tokens.dart';
import '../../theme/moe_theme_extension.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/dialogs/confirm_dialog.dart';
import '../../widgets/profile_bg.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../checkin/user_level_page.dart';
import 'followers_page.dart';
import 'following_page.dart';
import 'profile_viewmodel.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  MoeTheme get _moe => MoeTheme.of(context);
  late final ProfileViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ProfileViewModel()..addListener(_onVmChanged);
    unawaited(_loadUserInfo());
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadUserInfo({bool forceRefresh = false}) {
    return _vm.loadUserInfo(
      forceRefresh: forceRefresh,
      onDetailsLoaded: (userId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final lp = context.read<UserLevelProvider>();
            if (lp.userLevel == null && !lp.isLoading) lp.loadUserLevel(userId);
          }
        });
      },
      onRefreshErrorWithCachedUser: (e) {
        if (mounted) {
          MoeToast.error(
            context,
            MoeErrorCopy.toast(e, scene: MoeErrorScene.profile),
          );
        }
      },
    );
  }

  // ─── Navigation helpers ───────────────────────────────────────────────────

  void _openEditProfile() {
    HapticFeedback.lightImpact();
    final u = _vm.user;
    if (u == null) return;
    Navigator.pushNamed(context, '/edit-profile', arguments: u).then((_) {
      if (mounted) _loadUserInfo();
    });
  }

  void _goToMyPosts() {
    final u = _vm.user;
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
    Navigator.pushNamed(context, '/checkin');
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
      final login = await showConfirmDialog(
        context,
        title: '先登录再查看',
        message: '登录后可查看会员权益、套餐和开通记录。',
        confirmText: '去登录',
        cancelText: '稍后再说',
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
        if (mounted && (result == true || !_vm.isVip)) _loadUserInfo();
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
    final uid = _vm.user?.id;
    if (uid == null || uid.isEmpty) return;
    Navigator.pushNamed(context, '/achievements');
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_vm.isLoading && _vm.user == null) {
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

    if (_vm.loadError != null && _vm.user == null) {
      return AdaptivePageScaffold(
        template: PageTemplate.fullscreen,
        backgroundColor: MoeTheme.of(context).pageBackground,
        body: Column(
          children: [
            _buildPinnedHeader(),
            Expanded(
              child: Center(
                child: MoeErrorState.fromError(
                  _vm.loadError,
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
                          if (_vm.user != null) ...[
                            MoeReveal(
                                delay: const Duration(milliseconds: 80),
                                child: _buildAchievementsPreview()),
                            const SizedBox(height: 18),
                          ],
                          // Cloud & QR
                          MoeReveal(
                            delay: const Duration(milliseconds: 110),
                            child: _menuSection('云端与相册', [
                              MoeMenuItem(
                                  icon: Icons.cloud_queue_rounded,
                                  title: '云端图库',
                                  subtitle: '管理你的美好回忆',
                                  color: MoeTokens.secondary,
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    await Navigator.pushNamed(
                                        context, '/cloud-gallery');
                                  }),
                              MoeMenuItem(
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
                              MoeMenuItem(
                                  icon: Icons.logout_rounded,
                                  title: '退出登录',
                                  color: MoeTokens.danger,
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
                          if (_vm.hasDetailsError)
                            IconButton(
                              tooltip: '刷新资料明细',
                              onPressed:
                                  _vm.isLoadingDetails || _vm.user == null
                                      ? null
                                      : () => unawaited(
                                            _vm.loadProfileDetails(
                                              _vm.user!.id,
                                            ),
                                          ),
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
    final user = _vm.user;
    final sig = (user?.signature ?? '').trim();

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
                    avatarUrl: user?.avatar ?? '',
                    size: 52,
                    frameId: user?.equippedFrameId,
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
                            user?.username ?? '未知用户',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (_vm.isVip) ...[
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
                                color: MoeTokens.pastelOrange
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        if (_vm.isLoadingDetails) ...[
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
                        if ((user?.moeNo ?? '').isNotEmpty)
                          _glassPill(
                            onTap: () {
                              final moeNo = user?.moeNo ?? '';
                              if (moeNo.isEmpty) return;
                              Clipboard.setData(
                                ClipboardData(text: moeNo),
                              );
                              MoeToast.success(context, '已复制 Moe 号');
                            },
                            child: Text(
                              user?.moeNo ?? '',
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
              _statItem('动态', '${_vm.postCount}', onTap: _goToMyPosts),
              _statItem(
                '关注',
                '${_vm.followingCount}',
                onTap: user == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowingPage(userId: user.id),
                          ),
                        );
                      },
              ),
              _statItem(
                '粉丝',
                '${_vm.followerCount}',
                onTap: user == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowersPage(userId: user.id),
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
    final unlockedBadges = _vm.unlockedBadgeCount;
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
        subtitle: '¥${_vm.user?.balance.toStringAsFixed(2) ?? '0.00'}',
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(context, '/wallet').then((_) {
            if (mounted) _loadUserInfo();
          });
        },
      ),
      _QuickAction(
        icon:
            _vm.isVip ? Icons.workspace_premium_rounded : Icons.diamond_rounded,
        iconColor: _vm.isVip ? MoeTokens.pastelOrange : _moe.primary,
        label: '会员',
        subtitle: _vm.isVip ? '权益生效中' : '开通享特权',
        isCta: !_vm.isVip,
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
                            color: MoeTokens.danger, shape: BoxShape.circle),
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
    final stats = _vm.badgeStatistics!;
    final unlocked = _vm.userBadges.where((b) => b.isUnlocked).toList();
    final inProgress = _vm.userBadges
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
                          color: MoeTokens.pastelOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            '${stats.unlockedBadges}/${stats.totalBadges}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MoeTokens.warning)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stats.totalBadges == 0
                        ? '开始任务，点亮你的第一枚徽章'
                        : '已完成 ${(stats.totalBadges > 0 ? stats.unlockedBadges * 100 ~/ stats.totalBadges : 0)}%',
                    style: const TextStyle(
                      color: MoeTokens.inkMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  preview.isEmpty
                      ? const Text('完成任务解锁成就 →',
                          style: TextStyle(
                              color: MoeTokens.hintText, fontSize: 11.5))
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
                                    color: MoeTokens.softChipBg,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Center(
                                  child: Text(
                                    '+${preview.length - 4}',
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: MoeTokens.inkMuted),
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
                        backgroundColor: MoeTokens.lineSoft,
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
                const Text('查看',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: MoeTokens.inkMuted)),
                const Icon(Icons.chevron_right_rounded,
                    size: 17, color: MoeTokens.hintText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Menu section ─────────────────────────────────────────────────────────

  Widget _menuSection(String title, List<MoeMenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        const SizedBox(height: 10),
        MoeMenuCard(items: items),
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
                color: MoeTokens.titleText,
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
