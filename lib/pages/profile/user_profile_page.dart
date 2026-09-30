import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user.dart';
import '../../models/post.dart';
import '../../models/achievement_badge.dart';
import '../../auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../utils/moe_error_copy.dart';
import '../../services/achievement_service.dart';
import '../../services/like_state_manager.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/dynamic_avatar.dart';
import '../../widgets/profile_bg.dart';
import '../../widgets/achievement_badge_display.dart';
import '../../widgets/post_card.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/gift_selector.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../utils/error_handler.dart';
import '../../utils/post_navigation.dart';
import '../../theme/moe_tokens.dart';
import '../feed/create_post_page.dart';
import 'following_page.dart';
import 'followers_page.dart';
import '../chat/voice_call_launcher.dart';

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
  final LikeStateManager _likeManager = LikeStateManager();

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

      final user = await UserService.getUserInfo(widget.userId);
      // 加载用户徽章
      final userBadges = _achievementService.getUserBadges(widget.userId);

      // 检查关注状态
      bool isFollowing = false;
      if (AuthService.isLoggedIn) {
        final currentUserId = AuthService.currentUser;
        if (currentUserId != null) {
          // 确保参数顺序正确：followerId（当前用户）在前，followingId（被关注用户）在后
          try {
            isFollowing =
                await UserService.checkFollow(currentUserId, widget.userId);
          } catch (_) {
            isFollowing = false;
          }
        }
      }

      String friendRel = 'none';
      if (AuthService.isLoggedIn) {
        final cur = AuthService.currentUser;
        if (cur != null && cur != widget.userId) {
          try {
            friendRel = await UserService.getFriendRelation(cur, widget.userId);
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
      }
    } catch (e) {
      debugPrint('后台加载用户数据失败: $e');
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
      final followingResult =
          await UserService.getFollowings(widget.userId, page: 1, pageSize: 1);
      final followersResult =
          await UserService.getFollowers(widget.userId, page: 1, pageSize: 1);

      if (mounted) {
        setState(() {
          _followingCount = followingResult['total'] as int;
          _followersCount = followersResult['total'] as int;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('加载关注统计数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  void _toggleLike(String postId) {
    final isLiked = _likeManager.getStatusNotifier(postId).value;
    final likeCount = _likeManager.getCountNotifier(postId).value;
    _updateLikeSnapshot(postId: postId, isLiked: isLiked, likeCount: likeCount);
  }

  // 仅更新数据快照，点赞 UI 由 PostCard 内部 ValueListenable 局部刷新。
  void _updateLikeSnapshot({
    required String postId,
    required bool isLiked,
    required int likeCount,
  }) {
    final postIndex = _userPosts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      _userPosts[postIndex] = _userPosts[postIndex].copyWith(
        isLiked: isLiked,
        likes: likeCount,
      );
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
            userName:
                updated.userName.isNotEmpty ? updated.userName : post.userName,
            userAvatar: updated.userAvatar.isNotEmpty
                ? updated.userAvatar
                : post.userAvatar,
          );
        }
      });
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await PostService.deletePost(postId);
      if (!mounted) return;
      setState(() => _userPosts.removeWhere((p) => p.id == postId));
      _likeManager.evictPost(postId);
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
        return '已申请';
      case 'pending_in':
        return '待处理';
      default:
        return '加好友';
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

  Widget _headerStat(String label, String value, {VoidCallback? onTap}) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.78),
            height: 1,
          ),
        ),
      ],
    );
    return Expanded(
      child: MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: row),
          ),
        ),
      ),
    );
  }

  Widget _glassPill({required Widget child, VoidCallback? onTap}) {
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

  Widget _buildTopHeader(String name, String? avatar) {
    final sig = (_user?.signature ?? '').trim();
    final moe = _user?.moeNo ?? '';
    final frameId = _user?.equippedFrameId;
    final hasFrame = frameId != null && frameId.isNotEmpty;
    const avatarSize = 48.0;
    final postsLabel =
        _isLoadingPosts && _userPosts.isEmpty ? '…' : '$_postTotal';
    final charmLabel = _user == null ? '…' : '${_user!.giftCharm}';
    final giftValueLabel = _user == null
        ? '…'
        : _formatReceivedGiftValue(_user!.receivedGiftValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceLg,
        MoeTokens.spaceSm,
        MoeTokens.spaceLg,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        child: Stack(
          children: [
            const Positioned.fill(child: ProfileBg()),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: widget.heroTag ?? 'user_avatar_${widget.userId}',
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: hasFrame
                              ? DynamicAvatar(
                                  avatarUrl: avatar ?? '',
                                  size: avatarSize,
                                  frameId: frameId,
                                )
                              : NetworkAvatarImage(
                                  imageUrl: avatar ?? '',
                                  radius: avatarSize / 2,
                                  placeholderIcon: Icons.person,
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
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                if (_user?.isVip == true) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
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
                              ],
                            ),
                            if (sig.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                sig,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (moe.isNotEmpty)
                                  _glassPill(
                                    onTap: _isSelf
                                        ? () {
                                            Clipboard.setData(
                                              ClipboardData(text: moe),
                                            );
                                            MoeToast.success(
                                              context,
                                              '已复制 Moe 号',
                                            );
                                          }
                                        : null,
                                    child: Text(
                                      moe,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                _glassPill(
                                  child: Text(
                                    '魅力 $charmLabel',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _glassPill(
                                  child: Text(
                                    '收礼 $giftValueLabel',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _headerStat('动态', postsLabel, onTap: _scrollToPosts),
                      _headerStat(
                        '关注',
                        _isLoadingStats ? '…' : '$_followingCount',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  FollowingPage(userId: widget.userId),
                            ),
                          );
                        },
                      ),
                      _headerStat(
                        '粉丝',
                        _isLoadingStats ? '…' : '$_followersCount',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  FollowersPage(userId: widget.userId),
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
      await UserService.sendFriendRequestByUserId(me, widget.userId);
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

    try {
      final wantFollowing = !_isFollowing;
      final result = wantFollowing
          ? await UserService.followUser(currentUserId, widget.userId)
          : await UserService.unfollowUser(currentUserId, widget.userId);
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _isFollowing = wantFollowing;
        });
        _loadFollowStats();
        MoeToast.success(context, wantFollowing ? '已关注' : '已取消关注');
      } else {
        final message = result['message']?.toString().trim();
        MoeToast.error(
          context,
          message != null && message.isNotEmpty ? message : '操作失败',
        );
      }
    } catch (e) {
      if (!mounted) return;
      MoeToast.error(
        context,
        MoeErrorCopy.toast(e, scene: MoeErrorScene.following),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.username ?? widget.userName ?? '用户 ${widget.userId}';
    String? avatar = _user?.avatar;
    if (avatar == null || avatar.isEmpty) {
      avatar = widget.userAvatar;
    }
    final unlocked =
        _userBadges.where((badge) => badge.isUnlocked).toList(growable: false);

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: Text(_isSelf ? '我的主页' : '个人主页'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: MoeTokens.pageBackground,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTopHeader(name, avatar)),
          if (unlocked.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildBadgeShelf(unlocked),
            ),
          if (!_isSelf) SliverToBoxAdapter(child: _buildVisitorActions()),
          ..._buildPostsSlivers(),
        ],
      ),
    );
  }

  Widget _buildBadgeShelf(List<AchievementBadge> unlocked) {
    const medal = 46.0;
    final preview = unlocked.take(12).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceLg,
        12,
        MoeTokens.spaceLg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowSm(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '成就徽章',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  ),
                  child: Text(
                    '${unlocked.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: medal,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: preview.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final badge = preview[index];
                  return BadgeCard(
                    badge: badge,
                    size: medal,
                    compact: true,
                    showProgress: false,
                    onTap: () => _showBadgeDetails(badge),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorActions() {
    final showFriend =
        AuthService.isLoggedIn && AuthService.currentUser != widget.userId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceLg,
        12,
        MoeTokens.spaceLg,
        0,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (showFriend)
            _visitorChip(
              icon: Icons.how_to_reg_rounded,
              label: _friendRelationLabel(),
              onTap: _friendRelation == 'none' ? _onSendFriendRequest : null,
            ),
          _visitorChip(
            icon: _isFollowing ? Icons.check_rounded : Icons.add_rounded,
            label: _isFollowing ? '已关注' : '关注',
            filled: !_isFollowing,
            onTap: _toggleFollow,
          ),
          _visitorChip(
            icon: Icons.chat_bubble_outline_rounded,
            label: '私信',
            onTap: _openDirectChat,
          ),
          _visitorChip(
            icon: Icons.card_giftcard_rounded,
            label: '送礼',
            onTap: _showGiftSelector,
          ),
          _visitorChip(
            icon: Icons.phone_rounded,
            label: '通话',
            onTap: _startVoiceCall,
          ),
        ],
      ),
    );
  }

  Widget _visitorChip({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final enabled = onTap != null;
    final fg = !enabled
        ? MoeTokens.titleText.withValues(alpha: 0.38)
        : (filled ? Colors.white : MoeTokens.primary);
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: filled && enabled ? MoeTokens.primary : MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(
            color:
                filled && enabled ? MoeTokens.primary : MoeTokens.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startVoiceCall() async {
    if (_user == null) return;
    if (AuthService.currentUser == null) {
      MoeToast.error(context, '请先登录');
      return;
    }
    try {
      final callData = await ChatService.voiceCall(widget.userId);
      final channelName = callData['channel_name']?.toString();
      if (channelName == null || channelName.isEmpty) {
        throw Exception('invalid channel');
      }
      if (!mounted) return;
      await openVoiceCallPage(
        context,
        channelName: channelName,
        userName: widget.userName ?? 'User',
        userAvatar: widget.userAvatar ?? '',
      );
    } catch (_) {
      if (mounted) {
        MoeToast.error(context, '发起通话失败，请重试');
      }
    }
  }

  void _openDirectChat() {
    final target = _user;
    if (target == null) return;
    Navigator.pushNamed(
      context,
      '/direct-chat',
      arguments: {
        'userId': target.id,
        'username': target.username,
        'avatar': target.avatar,
      },
    );
  }

  List<Widget> _buildPostsSlivers() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          key: _postsSectionKey,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Text(
                _isSelf ? '我的动态' : 'TA 的动态',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: MoeTokens.titleText,
                ),
              ),
              const Spacer(),
              if (!_isLoadingPosts)
                Text(
                  '$_postTotal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MoeTokens.titleText.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (_isLoadingPosts)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: MoeLoading(size: 28)),
          ),
        )
      else if (_userPosts.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: MoeTokens.surface1,
                borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                border: Border.all(color: MoeTokens.surfaceBorder),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 28,
                    color: MoeTokens.primary.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '还没有动态',
                    style: TextStyle(
                      fontSize: 13,
                      color: MoeTokens.titleText.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: _userPosts.length,
          itemBuilder: (context, index) {
            final post = _userPosts[index];
            return PostCard(
              post: post,
              heroTagPrefix: 'up_',
              onLike: () => _toggleLike(post.id),
              onComment: () async {
                final result = await openPostDetail(context, post);
                if (result != null && mounted) {
                  setState(() {
                    final i = _userPosts.indexWhere((p) => p.id == post.id);
                    if (i != -1) {
                      _userPosts[i] = _userPosts[i].copyWith(comments: result);
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
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
    ];
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
      builder: (_) => BadgeDetailDialog(badge: badge),
    );
  }
}
