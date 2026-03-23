import 'package:flutter/material.dart';
import 'models/user.dart';
import 'models/post.dart';
import 'models/achievement_badge.dart';
import 'models/gift.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'services/achievement_service.dart';
import 'widgets/avatar_image.dart';
import 'widgets/dynamic_avatar.dart';
import 'widgets/fade_in_up.dart';
import 'widgets/achievement_badge_display.dart';
import 'widgets/post_card.dart';
import 'widgets/gift_animation.dart';
import 'services/post_service.dart';
import 'utils/error_handler.dart';
import 'following_page.dart';
import 'followers_page.dart';
import 'voice_call_page.dart';

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
  bool _isLoadingPosts = true;
  List<AchievementBadge> _userBadges = [];
  final AchievementService _achievementService = AchievementService();

  // 关注统计数据
  int _followingCount = 0;
  int _followersCount = 0;
  bool _isLoadingStats = true;

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

      if (mounted) {
        setState(() {
          _user = user;
          _userBadges = userBadges;
          _isFollowing = isFollowing;
        });
        print('🔍 最终关注状态: $_isFollowing');
      }
    } catch (e) {
      print('后台加载用户数据失败: $e');
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      // 临时方案：获取最新帖子并在前端过滤
      // 扩大获取范围到100条，以增加匹配几率
      final result = await PostService.getPosts(page: 1, pageSize: 100);
      final allPosts = result['posts'] as List<Post>;

      final myPosts = allPosts.where((p) => p.userId.toString() == widget.userId.toString()).toList();

      if (mounted) {
        setState(() {
          _userPosts = myPosts;
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

  Future<void> _toggleFollow() async {
    if (!AuthService.isLoggedIn) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先登录'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    final currentUserId = AuthService.currentUser;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('获取用户信息失败'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    // 禁止关注自己
    if (currentUserId == widget.userId) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('不能关注自己'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? '已关注' : '已取消关注'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '操作失败'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
    final email = _user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // 浅灰背景
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('个人主页'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 顶部头部区域 (Moe 风格)
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 260,
                  width: double.infinity,
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
                  top: -60,
                  left: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.fromLTRB(16, 140, 16, 0),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
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
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(label: '动态', value: '${_userPosts.length}'),
                          _StatItem(
                            label: '关注',
                            value: _isLoadingStats ? '...' : '$_followingCount',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FollowingPage(userId: widget.userId),
                                ),
                              );
                            },
                          ),
                          _StatItem(
                            label: '粉丝',
                            value: _isLoadingStats ? '...' : '$_followersCount',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FollowersPage(userId: widget.userId),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      // 用户徽章展示
                      if (_userBadges.where((badge) => badge.isUnlocked).isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.military_tech, size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            const Text(
                              '成就徽章',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _userBadges
                                .where((badge) => badge.isUnlocked)
                                .take(8) // 最多显示8个徽章
                                .map((badge) => Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: BadgeCard(
                                        badge: badge,
                                        size: 36,
                                        showProgress: false,
                                        onTap: () => _showBadgeDetails(badge),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Flexible(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing ? Colors.grey[200] : const Color(0xFF7F7FD5),
                                foregroundColor: _isFollowing ? Colors.black87 : Colors.white,
                                elevation: _isFollowing ? 0 : 4,
                                shadowColor: const Color(0xFF7F7FD5).withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(_isFollowing ? '已关注' : '关注', style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: () {
                                if (_user == null) return;
                                
                                // 生成一个唯一的频道名称，例如按照 userIds 排序拼接
                                // 这里简化处理，直接使用对方的 userId 作为频道名，或者双方 id 组合
                                final currentUserId = AuthService.currentUser;
                                if (currentUserId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('请先登录')),
                                  );
                                  return;
                                }
                                
                                // 简单的频道名生成策略：
                                 // 使用双方ID排序拼接，确保两人进入同一频道
                                 final ids = [currentUserId, widget.userId];
                                 ids.sort();
                                 final channelName = 'voice_call_${ids.join('_')}';
                                 
                                 Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VoiceCallPage(
                                      channelName: channelName,
                                      userName: widget.userName ?? 'User',
                                      userAvatar: widget.userAvatar ?? '',
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7F7FD5),
                                side: const BorderSide(color: Color(0xFF7F7FD5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                                side: const BorderSide(color: Color(0xFF7F7FD5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('私信', style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 1,
                            child: ElevatedButton.icon(
                              onPressed: _showGiftSelector,
                              icon: const Icon(Icons.card_giftcard, size: 16),
                              label: const Text('送礼', style: const TextStyle(fontWeight: FontWeight.w500)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink[400],
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: Colors.pink.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 90,
                  child: Hero(
                    tag: widget.heroTag ?? 'user_avatar_${widget.userId}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: _user != null
                          ? DynamicAvatar(
                              avatarUrl: avatar ?? '',
                              size: 88,
                              frameId: _user!.equippedFrameId,
                            )
                          : NetworkAvatarImage(
                              imageUrl: avatar,
                              radius: 44,
                              placeholderIcon: Icons.person,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 动态列表区域
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Container(
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
                          const Text(
                            '个人动态',
                            style: TextStyle(
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
                      ..._userPosts.map((post) => FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        child: PostCard(
                          post: post,
                          heroTagPrefix: 'up_',
                          onLike: () => _toggleLike(post.id),
                          onComment: () async {
                            await Navigator.pushNamed(context, '/comments', arguments: post.id);
                          },
                          onShare: () {},
                          onAvatarTap: () {},
                        ),
                      )),
                    
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                  const Icon(Icons.card_giftcard, color: Colors.pink),
                  const SizedBox(width: 8),
                  Text(
                    '送礼给 ${_user?.username ?? widget.userName ?? '用户'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 礼物选择器
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildGiftGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftGrid() {
    final gifts = Gift.getPopularGifts(limit: 12);
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            _sendGift(gift);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gift.color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(gift.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  gift.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${gift.price.toStringAsFixed(gift.price == gift.price.roundToDouble() ? 0 : 1)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: gift.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendGift(Gift gift) {
    // 显示礼物发送动画
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => GiftSendAnimation(
        gift: gift,
        onAnimationComplete: () {
          Navigator.of(context).pop();
          // 显示发送成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(gift.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已送出${gift.name}给 ${_user?.username ?? widget.userName ?? '用户'}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
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

// 简单的统计组件
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatItem({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
