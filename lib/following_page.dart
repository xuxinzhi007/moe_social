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
    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getFollowings(widget.userId, page: _page, pageSize: 10);
      final followings = result['followings'] as List<User>;
      final total = result['total'] as int;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载关注列表失败: $e')),
        );
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
                    if (_hasMore) {
                      // 使用 Future.microtask 延迟加载，避免在构建过程中调用 setState()
                      Future.microtask(() {
                        _loadFollowings();
                      });
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