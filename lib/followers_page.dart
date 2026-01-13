import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/user.dart';
import 'widgets/avatar_image.dart';
import 'user_profile_page.dart';

class FollowersPage extends StatefulWidget {
  final String userId;

  const FollowersPage({super.key, required this.userId});

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  List<User> _followers = [];
  bool _isLoading = true;
  int _total = 0;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getFollowers(widget.userId, page: _page, pageSize: 10);
      final followers = result['followers'] as List<User>;
      final total = result['total'] as int;

      if (mounted) {
        setState(() {
          if (_page == 1) {
            _followers = followers;
          } else {
            _followers.addAll(followers);
          }
          _total = total;
          _hasMore = _followers.length < _total;
          _page++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载粉丝列表失败: $e')),
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
        title: const Text('粉丝'),
        elevation: 0,
      ),
      body: _isLoading && _followers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _page = 1;
                _hasMore = true;
                await _loadFollowers();
              },
              child: ListView.builder(
                itemCount: _followers.length + 1,
                itemBuilder: (context, index) {
                  if (index == _followers.length) {
                    if (_hasMore) {
                      // 使用 Future.microtask 延迟加载，避免在构建过程中调用 setState()
                      Future.microtask(() {
                        _loadFollowers();
                      });
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else {
                      return const SizedBox(height: 20);
                    }
                  }

                  final user = _followers[index];
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
                            heroTag: 'avatar_${user.id}_follower',
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