import 'package:flutter/material.dart';
import 'models/user.dart';
import 'models/post.dart';
import 'services/api_service.dart';
import 'widgets/avatar_image.dart';
import 'widgets/network_image.dart';

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
      if (mounted) {
        setState(() {
          _user = user;
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
      final allPosts = await ApiService.getPosts(page: 1, pageSize: 100);

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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.username ?? widget.userName ?? '用户 ${widget.userId}';
    final avatar = _user?.avatar ?? widget.userAvatar;
    final email = _user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
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
            // 顶部头部区域
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blueAccent, Colors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 120, 16, 0),
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
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
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(label: '动态', value: '${_userPosts.length}'), // 实时显示动态数
                          const _StatItem(label: '关注', value: '0'),
                          const _StatItem(label: '粉丝', value: '0'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing ? Colors.grey[200] : Colors.blueAccent,
                                foregroundColor: _isFollowing ? Colors.black87 : Colors.white,
                                elevation: _isFollowing ? 0 : 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(_isFollowing ? '已关注' : '关注'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('私信功能开发中')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('私信'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 80,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: NetworkAvatarImage(
                      imageUrl: avatar,
                      radius: 40,
                      placeholderIcon: Icons.person,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 动态列表区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      '个人动态',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
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
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.article_outlined, size: 64, color: Colors.grey[200]),
                            const SizedBox(height: 16),
                            Text(
                              '暂无动态',
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
        padding: const EdgeInsets.all(16),
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
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.more_horiz, color: Colors.grey[400], size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.content,
              style: const TextStyle(fontSize: 15),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetworkImageWidget(
                    imageUrl: post.images.first,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.favorite_border, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('${post.likes}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('${post.comments}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ],
        ),
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
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
