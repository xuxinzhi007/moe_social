import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user.dart';
import '../../models/post.dart';
import '../../models/achievement_badge.dart';
import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../services/achievement_service.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/dynamic_avatar.dart';
import '../../widgets/profile_bg.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/achievement_badge_display.dart';
import '../../widgets/post_card.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/gift_selector.dart';
import '../../services/post_service.dart';
import '../../utils/error_handler.dart';
import '../../utils/post_navigation.dart';
import '../feed/create_post_page.dart';
import 'following_page.dart';
import 'followers_page.dart';
import '../chat/voice_call_page.dart';

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
  bool _isFollowing = false;
  List<Post> _userPosts = [];
  int _postTotal = 0;
  bool _isLoadingPosts = true;
  final GlobalKey _postsSectionKey = GlobalKey();
  List<AchievementBadge> _userBadges = [];
  final AchievementService _achievementService = AchievementService();

  // 关注统计数据
  int _followingCount = 0;
  int _followersCount = 0;
  bool _isLoadingStats = true;

  /// none | friend | pending_out | pending_in
  String _friendRelation = 'none';

  @override
  void initState() {
    super.initState();
    // 异步加载最新数据
    _loadData();
    _loadUserPosts();
    _loadFollowStats();
  }

  Future<void> _loadData() async {
    try {
      // 确保AuthService已经初始化，恢复登录状态
      await AuthService.init();
      
      print('🔍 AuthService.isLoggedIn: ${AuthService.isLoggedIn}');
      print('🔍 AuthService.currentUser: ${AuthService.currentUser}');
      
      final user = await ApiService.getUserInfo(widget.userId);
      // 加载用户徽章
      final userBadges = _achievementService.getUserBadges(widget.userId);
      
      // 检查关注状态
      bool isFollowing = false;
      if (AuthService.isLoggedIn) {
        final currentUserId = AuthService.currentUser;
        if (currentUserId != null) {
          // 确保参数顺序正确：followerId（当前用户）在前，followingId（被关注用户）在后
          print('🔍 检查关注状态：当前用户ID = $currentUserId，被关注用户ID = ${widget.userId}');
          try {
            isFollowing = await ApiService.checkFollow(currentUserId, widget.userId);
            print('🔍 关注状态检查结果：$isFollowing');
          } catch (e) {
            print('❌ 检查关注状态失败: $e');
            // 尝试通过followUser API的错误信息来判断关注状态
            try {
              // 尝试关注，如果返回重复错误则说明已经关注
              final result = await ApiService.followUser(currentUserId, widget.userId);
              print('🔍 尝试关注结果: $result');
              if (result['success']) {
                isFollowing = true;
                print('🔍 关注成功，状态更新为true');
              }
            } catch (followError) {
              print('🔍 尝试关注失败: $followError');
              if (followError.toString().contains('Duplicate entry')) {
                isFollowing = true;
                print('🔍 检测到重复关注，状态更新为true');
              }
            }
          }
        }
      }

      String friendRel = 'none';
      if (AuthService.isLoggedIn) {
        final cur = AuthService.currentUser;
        if (cur != null && cur != widget.userId) {
          try {
            friendRel =
                await ApiService.getFriendRelation(cur, widget.userId);
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _user = user;
          _userBadges = userBadges;
          _isFollowing = isFollowing;
          _friendRelation = friendRel;
        });
        print('🔍 最终关注状态: $_isFollowing');
      }
    } catch (e) {
      print('后台加载用户数据失败: $e');
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      final result = await PostService.getPosts(
        page: 1,
        pageSize: 50,
        authorUserId: widget.userId,
      );
      final list = result['posts'] as List<Post>;
      final totalRaw = result['total'];
      final total = totalRaw is int
          ? totalRaw
          : (totalRaw is num ? totalRaw.toInt() : list.length);

      if (mounted) {
        setState(() {
          _userPosts = list;
          _postTotal = total;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  Future<void> _loadFollowStats() async {
    try {
      // 获取关注数量和粉丝数量
      final followingResult = await ApiService.getFollowings(widget.userId, page: 1, pageSize: 1);
      final followersResult = await ApiService.getFollowers(widget.userId, page: 1, pageSize: 1);

      if (mounted) {
        setState(() {
          _followingCount = followingResult['total'] as int;
          _followersCount = followersResult['total'] as int;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('加载关注统计数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    final currentUserId = AuthService.currentUser;
    if (currentUserId == null) {
      if (mounted) {
        ErrorHandler.showError(context, '请先登录');
      }
      return;
    }

    try {
      final updatedPost = await PostService.toggleLike(postId, currentUserId);
      
      final postIndex = _userPosts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        _userPosts[postIndex] = updatedPost;
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    }
  }

  Future<void> _editPost(Post post) async {
    final updated = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => CreatePostPage(initialPost: post)),
    );
    if (updated != null && mounted) {
      setState(() {
        final i = _userPosts.indexWhere((p) => p.id == updated.id);
        if (i != -1) {
          _userPosts[i] = updated.copyWith(
            likes: post.likes,
            comments: post.comments,
            isLiked: post.isLiked,
            userName: updated.userName.isNotEmpty ? updated.userName : post.userName,
            userAvatar: updated.userAvatar.isNotEmpty ? updated.userAvatar : post.userAvatar,
          );
        }
      });
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await ApiService.deletePost(postId);
      if (!mounted) return;
      setState(() => _userPosts.removeWhere((p) => p.id == postId));
      MoeToast.success(context, '动态已删除');
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '删除失败：$e');
    }
  }


  String _friendRelationLabel() {
    switch (_friendRelation) {
      case 'friend':
        return '已是好友';
      case 'pending_out':
        return '好友申请已发送';
      case 'pending_in':
        return '对方向你发了申请（在联系人页处理）';
      default:
        return '发好友申请';
    }
  }

  bool get _isSelf =>
      AuthService.isLoggedIn &&
      AuthService.currentUser != null &&
      AuthService.currentUser == widget.userId;

  void _scrollToPosts() {
    final ctx = _postsSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

  /// 头部最小总高度 = 顶栏留白 + 底边距 + 主体（头像/昵称/统计条等）最小高度。
  /// 之前用整体 scale(272) 未扣掉 [Padding] 的 top，内部 Column 只有 ~169px 易溢出。
  double _userProfileHeaderMinHeight(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top + kToolbarHeight + 2;
    const bottomPad = 14.0;
    final ts = MediaQuery.textScalerOf(context);
    // 统计条为两行（动态/关注/粉丝 + 魅力/收礼），略增高避免挤压。
    final bodyMin = ts.scale(238.0).clamp(200.0, 400.0);
    return (topPad + bottomPad + bodyMin).clamp(300.0, 580.0);
  }

  String _formatReceivedGiftValue(double v) {
    if (v >= 10000) {
      final w = v / 10000;
      return '${w.toStringAsFixed(v >= 100000 ? 0 : 1)}万';
    }
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(1);
  }

  Widget _buildFrostedStatsStrip() {
    Widget stat(String label, String value, {VoidCallback? onTap}) {
      final ts = MediaQuery.textScalerOf(context);
      final valueSize = ts.scale(18.0).clamp(14.0, 24.0);
      final labelSize = ts.scale(11.0).clamp(10.0, 15.0);
      final valueStyle = TextStyle(
        fontSize: valueSize,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1E1E2E),
        height: 1.05,
      );
      final labelStyle = TextStyle(
        fontSize: labelSize,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E1E2E).withValues(alpha: 0.52),
      );
      final col = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: valueStyle,
          ),
          SizedBox(height: ts.scale(4.0).clamp(2.0, 8.0)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
        ],
      );
      if (onTap != null) {
        return Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Center(child: col),
              ),
            ),
          ),
        );
      }
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Center(child: col),
        ),
      );
    }

    final postsLabel = _isLoadingPosts && _userPosts.isEmpty ? '…' : '$_postTotal';
    final charmLabel = _user == null ? '…' : '${_user!.giftCharm}';
    final giftValueLabel =
        _user == null ? '…' : _formatReceivedGiftValue(_user!.receivedGiftValue);
    final sepH = MediaQuery.textScalerOf(context).scale(32.0).clamp(24.0, 44.0);

    Widget vDivider() => Container(
          width: 1,
          height: sepH,
          color: Colors.white.withValues(alpha: 0.35),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: MediaQuery.textScalerOf(context).scale(12.0).clamp(8.0, 18.0),
            horizontal: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  stat('动态', postsLabel, onTap: _scrollToPosts),
                  vDivider(),
                  stat(
                    '关注',
                    _isLoadingStats ? '…' : '$_followingCount',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => FollowingPage(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                  vDivider(),
                  stat(
                    '粉丝',
                    _isLoadingStats ? '…' : '$_followersCount',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => FollowersPage(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.textScalerOf(context).scale(6.0).clamp(4.0, 10.0),
                  8,
                  0,
                ),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              Row(
                children: [
                  stat('魅力', charmLabel),
                  vDivider(),
                  stat('收礼', giftValueLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(String name, String? avatar) {
    final sig = (_user?.signature ?? '').trim();
    final moe = _user?.moeNo ?? '';

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: double.infinity,
        minHeight: _userProfileHeaderMinHeight(context),
      ),
      child: IntrinsicHeight(
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.loose,
          alignment: Alignment.bottomCenter,
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
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + kToolbarHeight + 2,
                20,
                14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                Hero(
                  tag: widget.heroTag ?? 'user_avatar_${widget.userId}',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7F7FD5).withValues(alpha: 0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _user != null
                          ? DynamicAvatar(
                              avatarUrl: avatar ?? '',
                              size: 76,
                              frameId: _user!.equippedFrameId,
                            )
                          : NetworkAvatarImage(
                              imageUrl: avatar ?? '',
                              radius: 38,
                              placeholderIcon: Icons.person,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_user?.isVip == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                const Color(0xFFFFE082).withValues(alpha: 0.9),
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
                  ],
                ),
                if (_isSelf && (_user?.email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _user!.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (sig.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      sig,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ],
                if (moe.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: _isSelf
                          ? () {
                              Clipboard.setData(ClipboardData(text: moe));
                              MoeToast.success(context, '已复制 Moe 号');
                            }
                          : null,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              moe,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isSelf) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _buildFrostedStatsStrip(),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _onSendFriendRequest() async {
    final me = AuthService.currentUser;
    if (me == null) {
      MoeToast.error(context, '请先登录');
      return;
    }
    try {
      await ApiService.sendFriendRequestByUserId(me, widget.userId);
      if (mounted) {
        setState(() => _friendRelation = 'pending_out');
        MoeToast.success(context, '已发送好友申请');
      }
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
    }
  }

  Future<void> _toggleFollow() async {
    if (!AuthService.isLoggedIn) {
      MoeToast.error(context, '请先登录');
      return;
    }
    
    final currentUserId = AuthService.currentUser;
    if (currentUserId == null) {
      MoeToast.error(context, '获取用户信息失败');
      return;
    }
    
    // 禁止关注自己
    if (currentUserId == widget.userId) {
      MoeToast.error(context, '不能关注自己');
      return;
    }
    
    try {
      final result = _isFollowing
          ? await ApiService.unfollowUser(currentUserId, widget.userId)
          : await ApiService.followUser(currentUserId, widget.userId);
      
      if (result['success']) {
        setState(() {
          _isFollowing = !_isFollowing;
        });

        // 刷新关注统计数据
        _loadFollowStats();

        MoeToast.success(context, _isFollowing ? '已关注' : '已取消关注');
      } else {
        MoeToast.error(context, result['message'] ?? '操作失败');
      }
    } catch (e) {
      print('关注操作失败: $e');
      
      // 处理重复关注的情况
      String errorMessage = _isFollowing ? '取消关注失败' : '关注失败';
      if (e.toString().contains('Duplicate entry') || e.toString().contains('already exists')) {
        errorMessage = '您已经关注了该用户';
        // 更新本地状态为已关注
        setState(() {
          _isFollowing = true;
        });
        // 刷新关注统计数据
        _loadFollowStats();
      } else if (e.toString().contains('foreign key constraint fails')) {
        errorMessage = '关注的用户不存在';
      }
      
      MoeToast.error(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.username ?? widget.userName ?? '用户 ${widget.userId}';
    String? avatar = _user?.avatar;
    if (avatar == null || avatar.isEmpty) {
      avatar = widget.userAvatar;
    }
    final showMidCard = !_isSelf ||
        _userBadges.where((badge) => badge.isUnlocked).isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isSelf ? '我的主页' : '个人主页'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopHeader(name, avatar),
            if (showMidCard)
              Transform.translate(
                offset: const Offset(0, -22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_userBadges
                            .where((badge) => badge.isUnlocked)
                            .isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.military_tech,
                                  size: 16, color: Colors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '成就徽章',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_userBadges.where((b) => b.isUnlocked).length} 个',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final h = MediaQuery.of(context)
                                  .textScaler
                                  .scale(64.0)
                                  .clamp(56.0, 96.0);
                              return SizedBox(
                                height: h,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  clipBehavior: Clip.hardEdge,
                                  itemCount: _userBadges
                                      .where((b) => b.isUnlocked)
                                      .take(8)
                                      .length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final badge = _userBadges
                                        .where((b) => b.isUnlocked)
                                        .take(8)
                                        .elementAt(index);
                                    return Align(
                                      alignment: Alignment.topCenter,
                                      child: SizedBox(
                                        height: h,
                                        width: h,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center,
                                          child: BadgeCard(
                                            badge: badge,
                                            size: h,
                                            compact: true,
                                            showProgress: false,
                                            onTap: () =>
                                                _showBadgeDetails(badge),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (AuthService.isLoggedIn &&
                            AuthService.currentUser != widget.userId) ...[
                          if (_userBadges
                              .where((b) => b.isUnlocked)
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _friendRelation == 'none'
                                  ? _onSendFriendRequest
                                  : null,
                              icon: const Icon(Icons.how_to_reg_rounded,
                                  size: 18),
                              label: Text(_friendRelationLabel()),
                            ),
                          ),
                        ],
                        if (!_isSelf) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Flexible(
                                flex: 1,
                                child: ElevatedButton(
                                  onPressed: _toggleFollow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing
                                        ? Colors.grey[200]
                                        : const Color(0xFF7F7FD5),
                                    foregroundColor: _isFollowing
                                        ? Colors.black87
                                        : Colors.white,
                                    elevation: _isFollowing ? 0 : 4,
                                    shadowColor: const Color(0xFF7F7FD5)
                                        .withValues(alpha: 0.35),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  child: Text(
                                    _isFollowing ? '已关注' : '关注',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: () {
                                    if (_user == null) return;
                                    final currentUserId =
                                        AuthService.currentUser;
                                    if (currentUserId == null) {
                                      MoeToast.error(context, '请先登录');
                                      return;
                                    }
                                    final ids = [currentUserId, widget.userId]
                                      ..sort();
                                    final channelName =
                                        'voice_call_${ids.join('_')}';
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => VoiceCallPage(
                                          channelName: channelName,
                                          userName:
                                              widget.userName ?? 'User',
                                          userAvatar:
                                              widget.userAvatar ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF7F7FD5),
                                    side: const BorderSide(
                                        color: Color(0xFF7F7FD5)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  child: const Icon(Icons.phone, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: () {
                                    if (_user == null) return;
                                    final target = _user!;
                                    Navigator.pushNamed(
                                      context,
                                      '/direct-chat',
                                      arguments: {
                                        'userId': target.id,
                                        'username': target.username,
                                        'avatar': target.avatar,
                                      },
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF7F7FD5),
                                    side: const BorderSide(
                                        color: Color(0xFF7F7FD5)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  child: const Text(
                                    '私信',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: _showGiftSelector,
                                  icon: const Icon(Icons.card_giftcard,
                                      size: 16),
                                  label: const Text(
                                    '送礼',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.pink[400],
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor:
                                        Colors.pink.withValues(alpha: 0.35),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 4),
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Container(
                key: _postsSectionKey,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            width: 4, 
                            height: 18, 
                            decoration: BoxDecoration(
                              color: const Color(0xFF7F7FD5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isSelf ? '我的动态' : 'TA 的动态',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (_isLoadingPosts)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_userPosts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.bubble_chart_outlined, size: 64, color: Colors.grey[200]),
                              const SizedBox(height: 16),
                              Text(
                                '这里还空空如也哦 ~',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._userPosts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final post = entry.value;
                        return FadeInUp(
                          delay: Duration(milliseconds: 30 * (index % 8)),
                          child: PostCard(
                            post: post,
                            heroTagPrefix: 'up_',
                            onLike: () => _toggleLike(post.id),
                            onComment: () async {
                              final result = await openPostDetail<int>(
                                  context, post);
                              if (result != null && mounted) {
                                setState(() {
                                  final i = _userPosts
                                      .indexWhere((p) => p.id == post.id);
                                  if (i != -1) {
                                    _userPosts[i] = _userPosts[i]
                                        .copyWith(comments: result);
                                  }
                                });
                              }
                            },
                            onEdit: post.userId == (AuthService.currentUser ?? '')
                                ? () => _editPost(post)
                                : null,
                            onDelete: post.userId == (AuthService.currentUser ?? '')
                                ? () => _deletePost(post.id)
                                : null,
                          ),
                      );
                    }),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }


  void _showGiftSelector() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelector(
        targetId: widget.userId,
        targetType: 'user',
        receiverId: widget.userId,
        onGiftSent: (gift) {
          if (!mounted) return;
          MoeToast.show(
            context,
            '已向 ${_user?.username ?? widget.userName ?? '用户'} 赠送 ${gift.name}',
            icon: Icons.favorite_rounded,
            backgroundColor: const Color(0xFFF0FDF4),
            textColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
          );
        },
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
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

}
