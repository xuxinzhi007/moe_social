import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/user.dart';
import 'widgets/avatar_image.dart';
import 'user_profile_page.dart';

class FollowingPage extends StatefulWidget {
  final String userId;

  const FollowingPage({super.key, required this.userId});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  List<User> _followings = [];
  bool _isLoading = true;
  int _total = 0;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadFollowings();
  }

  Future<void> _loadFollowings() async {
    // 添加更多调试日志
    print('🔍 开始加载关注列表: userId=$widget.userId, page=$_page, _hasMore=$_hasMore, _isLoading=$_isLoading');
    
    if (!_hasMore || _isLoading) {
      print('❌ 跳过加载: _hasMore=$_hasMore, _isLoading=$_isLoading');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('📡 发送API请求: userId=$widget.userId, page=$_page, pageSize=10');
      final result = await ApiService.getFollowings(widget.userId, page: _page, pageSize: 10);
      
      print('📥 API响应: $result');
      
      // 简化数据处理，直接使用API返回的数据
      final followings = result['followings'] as List<User>;
      final total = result['total'] as int;

      print('📊 解析结果: followings=${followings.length}, total=$total');
      
      if (mounted) {
        setState(() {
          if (_page == 1) {
            _followings = followings;
          } else {
            _followings.addAll(followings);
          }
          _total = total;
          _hasMore = _followings.length < _total;
          _page++;
        });
      }
    } catch (e) {
      print('❌ 加载关注列表失败: $e');
      print('❌ 错误类型: ${e.runtimeType}');
      print('❌ 错误详情: ${e.toString()}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载关注列表失败: $e')),
        );
        // 确保状态正确更新，避免无限加载
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关注'),
        elevation: 0,
      ),
      body: _isLoading && _followings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _page = 1;
                _hasMore = true;
                await _loadFollowings();
              },
              child: ListView.builder(
                itemCount: _followings.length + 1,
                itemBuilder: (context, index) {
                  if (index == _followings.length) {
                    if (_hasMore && !_isLoading) {
                      // 只在还有更多数据且不在加载状态时才加载，避免重复请求
                      Future.microtask(() {
                        _loadFollowings();
                      });
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (_isLoading) {
                      // 如果正在加载，只显示加载指示器
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else {
                      return const SizedBox(height: 20);
                    }
                  }

                  final user = _followings[index];
                  return ListTile(
                    leading: NetworkAvatarImage(
                      imageUrl: user.avatar,
                      radius: 24,
                      placeholderIcon: Icons.person,
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.email),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfilePage(
                            userId: user.id,
                            userName: user.username,
                            userAvatar: user.avatar,
                            heroTag: 'avatar_${user.id}_following',
                          ),
                        ),
                      );
                    },
                    trailing: AuthService.currentUser != user.id
                        ? ElevatedButton(
                            onPressed: () async {
                              // 这里可以添加关注/取消关注功能
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('关注'),
                          )
                        : null,
                  );
                },
              ),
            ),
    );
  }
}