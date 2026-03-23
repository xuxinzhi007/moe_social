import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'models/user.dart';
import 'services/api_service.dart';
import 'services/presence_service.dart';
import 'widgets/avatar_image.dart';
import 'providers/notification_provider.dart';
import 'widgets/fade_in_up.dart';
import 'widgets/moe_toast.dart';

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
  Map<String, bool> _onlineStatus = {};
  Timer? _onlineTimer;
  bool _presenceListening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_presenceListening) return;
    _presenceListening = true;
    PresenceService.start();
    PresenceService.online.addListener(_onPresenceUpdate);
  }

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    if (_presenceListening) {
      PresenceService.online.removeListener(_onPresenceUpdate);
    }
    super.dispose();
  }

  void _onPresenceUpdate() {
    if (!mounted) return;
    if (_friends.isEmpty) return;
    final current = PresenceService.online.value;
    if (PresenceService.isConnected && current.isNotEmpty) {
      _onlineTimer?.cancel();
      _onlineTimer = null;
    }
    final next = <String, bool>{};
    for (final f in _friends) {
      next[f.id] = current[f.id] ?? false;
    }
    setState(() {
      _onlineStatus = next;
    });
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
      final followingResult = await ApiService.getFollowings(currentUserId,
          page: 1, pageSize: 1000);
      final followerResult =
          await ApiService.getFollowers(currentUserId, page: 1, pageSize: 1000);
      final followings = followingResult['followings'] as List<User>;
      final followers = followerResult['followers'] as List<User>;
      final followerIds = followers.map((u) => u.id).toSet();
      final friends =
          followings.where((u) => followerIds.contains(u.id)).toList();
      friends.sort((a, b) => a.username.compareTo(b.username));
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _isLoading = false;
        _hasError = false;
      });

      await _ensureOnlineStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _ensureOnlineStatus() async {
    if (!mounted || _friends.isEmpty) return;

    final presenceMap = PresenceService.online.value;
    if (PresenceService.isConnected && presenceMap.isNotEmpty) {
      final next = <String, bool>{};
      for (final f in _friends) {
        next[f.id] = presenceMap[f.id] ?? false;
      }
      setState(() {
        _onlineStatus = next;
      });
      return;
    }

    _startOnlinePolling();
  }

  void _startOnlinePolling() {
    _updateOnlineStatus();
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _updateOnlineStatus();
    });
  }

  Future<void> _updateOnlineStatus() async {
    if (!mounted || _friends.isEmpty) {
      return;
    }

    final presenceMap = PresenceService.online.value;
    if (PresenceService.isConnected && presenceMap.isNotEmpty) {
      final next = <String, bool>{};
      for (final f in _friends) {
        next[f.id] = presenceMap[f.id] ?? false;
      }
      setState(() {
        _onlineStatus = next;
      });
      return;
    }

    final ids = List<String>.from(_friends.map((u) => u.id));
    try {
      final status = await ApiService.getChatOnlineBatch(ids);
      if (!mounted) return;
      setState(() {
        _onlineStatus = status;
      });
    } catch (_) {
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
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
                      filled: true,
                      fillColor: Colors.grey[50],
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
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
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
                            MoeToast.error(rootContext, '请先登录');
                            return;
                          }
                          setState(() {
                            isLoading = true;
                            error = null;
                          });
                          try {
                            final targetUser =
                                await ApiService.checkUserByEmail(email);
                            if (targetUser.id == currentUserId) {
                              setState(() {
                                isLoading = false;
                                error = '不能添加自己为好友';
                              });
                              return;
                            }
                            await ApiService.followUser(
                                currentUserId, targetUser.id);
                            if (rootContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              MoeToast.success(rootContext, '已关注 ${targetUser.username}');
                              _loadFriends();
                            }
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                              error = e.toString();
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7F7FD5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('好友', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF7F7FD5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.person_add_rounded, color: Color(0xFF7F7FD5)),
              onPressed: _showAddFriendDialog,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7F7FD5)));
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadFriends,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F7FD5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
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
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有好友，试着通过邮箱添加一个吧',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('添加好友'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F7FD5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 4,
                shadowColor: const Color(0xFF7F7FD5).withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }
    
    final friends = _filteredFriends;
    
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索好友昵称或邮箱',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                });
              },
            ),
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFriends,
            color: const Color(0xFF7F7FD5),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final user = friends[index];
                return FadeInUp(
                  delay: Duration(milliseconds: 30 * (index % 8)),
                  child: _buildFriendCard(user),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(User user) {
    final isOnline = _onlineStatus[user.id] ?? false;
    final dmUnread =
        context.watch<NotificationProvider>().unreadDmBySender[user.id] ?? 0;
        
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
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
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 头像与在线状态
                Stack(
                  children: [
                    Hero(
                      tag: 'friend_${user.id}',
                      child: NetworkAvatarImage(
                        imageUrl: user.avatar,
                        radius: 28,
                        placeholderIcon: Icons.person,
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // 操作区
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dmUnread > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          dmUnread > 99 ? '99+' : dmUnread.toString(),
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 11,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F7FD5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF7F7FD5), size: 20),
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
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    IconButton(
                      icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
                      onPressed: () => _showFriendActions(user),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFriendActions(User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F7FD5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF7F7FD5)),
                  ),
                  title: const Text('私聊', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                  ),
                  title: const Text('删除好友', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(context);
                    final currentUserId = AuthService.currentUser;
                    if (currentUserId == null) return;
                    
                    try {
                      await ApiService.unfollowUser(currentUserId, user.id);
                      if (mounted) {
                        MoeToast.success(this.context, '已取消关注 ${user.username}');
                        _loadFriends();
                      }
                    } catch (e) {
                      if (mounted) {
                        MoeToast.error(this.context, '操作失败，请重试');
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
