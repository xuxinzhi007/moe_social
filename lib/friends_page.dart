import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'models/user.dart';
import 'services/api_service.dart';
import 'widgets/avatar_image.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<User> _friends = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final currentUserId = AuthService.currentUser;
    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '请先登录';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    try {
      final followingResult = await ApiService.getFollowings(currentUserId, page: 1, pageSize: 1000);
      final followerResult = await ApiService.getFollowers(currentUserId, page: 1, pageSize: 1000);
      final followings = followingResult['followings'] as List<User>;
      final followers = followerResult['followers'] as List<User>;
      final followerIds = followers.map((u) => u.id).toSet();
      final friends = followings.where((u) => followerIds.contains(u.id)).toList();
      friends.sort((a, b) => a.username.compareTo(b.username));
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _showAddFriendDialog() {
    final rootContext = context;
    final controller = TextEditingController();
    showDialog(
      context: rootContext,
      builder: (dialogContext) {
        bool isLoading = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('通过邮箱添加好友'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: '输入对方邮箱',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (error != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error ?? '',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = controller.text.trim();
                          if (email.isEmpty) {
                            setState(() {
                              error = '请输入邮箱';
                            });
                            return;
                          }
                          final currentUserId = AuthService.currentUser;
                          if (currentUserId == null) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(content: Text('请先登录')),
                            );
                            return;
                          }
                          setState(() {
                            isLoading = true;
                            error = null;
                          });
                          try {
                            final targetUser = await ApiService.checkUserByEmail(email);
                            if (targetUser.id == currentUserId) {
                              setState(() {
                                isLoading = false;
                                error = '不能添加自己为好友';
                              });
                              return;
                            }
                            await ApiService.followUser(currentUserId, targetUser.id);
                            if (rootContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(content: Text('已关注 ${targetUser.username}')),
                              );
                              _loadFriends();
                            }
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                              error = e.toString();
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<User> get _filteredFriends {
    if (_searchKeyword.trim().isEmpty) {
      return _friends;
    }
    final keyword = _searchKeyword.trim().toLowerCase();
    return _friends.where((u) {
      final name = u.username.toLowerCase();
      final email = u.email.toLowerCase();
      return name.contains(keyword) || email.contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _showAddFriendDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('加载好友列表失败'),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFriends,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('还没有好友，试着通过邮箱添加一个吧'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('添加好友'),
            ),
          ],
        ),
      );
    }
    final friends = _filteredFriends;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索好友昵称或邮箱',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchKeyword = value;
              });
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFriends,
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final user = friends[index];
                return _buildFriendItem(user);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendItem(User user) {
    return ListTile(
      leading: NetworkAvatarImage(
        imageUrl: user.avatar,
        radius: 24,
        placeholderIcon: Icons.person,
      ),
      title: Text(
        user.username,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(user.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF7F7FD5)),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/direct-chat',
                arguments: {
                  'userId': user.id,
                  'username': user.username,
                  'avatar': user.avatar,
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showFriendActions(user);
            },
          ),
        ],
      ),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/user-profile',
          arguments: {
            'userId': user.id,
            'userName': user.username,
            'userAvatar': user.avatar,
            'heroTag': 'friend_${user.id}',
          },
        );
      },
    );
  }

  void _showFriendActions(User user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('私聊'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    this.context,
                    '/direct-chat',
                    arguments: {
                      'userId': user.id,
                      'username': user.username,
                      'avatar': user.avatar,
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.red),
                title: const Text('删除好友', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final currentUserId = AuthService.currentUser;
                  if (currentUserId == null) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('请先登录')),
                    );
                    return;
                  }
                  try {
                    await ApiService.unfollowUser(currentUserId, user.id);
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('已取消关注 ${user.username}')),
                      );
                      _loadFriends();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
