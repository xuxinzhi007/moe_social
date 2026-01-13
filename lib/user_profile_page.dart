import 'package:flutter/material.dart';
import 'models/user.dart';
import 'models/post.dart';
import 'models/achievement_badge.dart';
import 'models/gift.dart';
import 'services/api_service.dart';
import 'services/achievement_service.dart';
import 'widgets/avatar_image.dart';
import 'widgets/network_image.dart';
import 'widgets/fade_in_up.dart';
import 'widgets/achievement_badge_display.dart';
import 'widgets/gift_selector.dart';
import 'widgets/gift_animation.dart';

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

  @override
  void initState() {
    super.initState();
    // 异步加载最新数据
    _loadData();
    _loadUserPosts();
  }

  Future<void> _loadData() async {
    try {
      final user = await ApiService.getUserInfo(widget.userId);
      // 加载用户徽章
      final userBadges = _achievementService.getUserBadges(widget.userId);

      if (mounted) {
        setState(() {
          _user = user;
          _userBadges = userBadges;
        });
      }
    } catch (e) {
      print('后台加载用户数据失败: $e');
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      // 临时方案：获取最新帖子并在前端过滤
      // 扩大获取范围到100条，以增加匹配几率
      final result = await ApiService.getPosts(page: 1, pageSize: 100);
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

  void _toggleFollow() {
    setState(() {
      _isFollowing = !_isFollowing;
    });
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFollowing ? '已关注' : '已取消关注'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.username ?? widget.userName ?? '用户 ${widget.userId}';
    final avatar = _user?.avatar ?? widget.userAvatar;
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
                          const _StatItem(label: '关注', value: '0'),
                          const _StatItem(label: '粉丝', value: '0'),
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
                          Expanded(
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
                              ),
                              child: Text(_isFollowing ? '已关注' : '关注'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('私信功能开发中')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7F7FD5),
                                side: const BorderSide(color: Color(0xFF7F7FD5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('私信'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showGiftSelector,
                              icon: const Icon(Icons.card_giftcard, size: 16),
                              label: const Text('送礼'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink[400],
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: Colors.pink.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
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
                      child: NetworkAvatarImage(
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
                      ..._userPosts.map((post) => _buildSimplePostItem(post)),
                    
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

  // 简化的帖子列表项
  Widget _buildSimplePostItem(Post post) {
    return InkWell(
      onTap: () {
        // 可以跳转到帖子详情
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[100]!),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _formatTime(post.createdAt),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.more_horiz, color: Colors.grey[300], size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.content,
              style: const TextStyle(fontSize: 15, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NetworkImageWidget(
                    imageUrl: post.images.first,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 16, color: Colors.pink[100]),
                const SizedBox(width: 4),
                Text('${post.likes}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.blue[100]),
                const SizedBox(width: 4),
                Text('${post.comments}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) {
      return '${time.year}-${time.month}-${time.day}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inMinutes}分钟前';
    }
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
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
