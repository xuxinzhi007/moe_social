import 'package:flutter/material.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/models/user.dart';
import 'package:moe_social/models/gift.dart';
import 'package:moe_social/widgets/avatar_image.dart';
import 'package:moe_social/widgets/moe_toast.dart';
import 'package:moe_social/widgets/gift_selector.dart';
import 'package:moe_social/widgets/like_button.dart';

class InteractionPage extends StatefulWidget {
  final String currentUserId;

  const InteractionPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<InteractionPage> createState() => _InteractionPageState();
}

class _InteractionPageState extends State<InteractionPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriends();
    _loadFriendRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    try {
      final friends = await ApiService.getFriends(widget.currentUserId);
      setState(() => _friends = friends);
    } catch (e) {
      MoeToast.show(context, '获取好友列表失败');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFriendRequests() async {
    try {
      final requests = await ApiService.getIncomingFriendRequests(widget.currentUserId);
      setState(() => _friendRequests = requests);
    } catch (e) {
      MoeToast.show(context, '获取好友请求失败');
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      await ApiService.acceptFriendRequest(widget.currentUserId, requestId);
      MoeToast.show(context, '已接受好友请求');
      _loadFriendRequests();
      _loadFriends();
    } catch (e) {
      MoeToast.show(context, '接受好友请求失败');
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await ApiService.rejectFriendRequest(widget.currentUserId, requestId);
      MoeToast.show(context, '已拒绝好友请求');
      _loadFriendRequests();
    } catch (e) {
      MoeToast.show(context, '拒绝好友请求失败');
    }
  }

  Future<void> _sendFriendRequest(String moeNo) async {
    if (moeNo.isEmpty) {
      MoeToast.show(context, '请输入Moe号');
      return;
    }
    try {
      await ApiService.sendFriendRequestByMoeNo(widget.currentUserId, moeNo);
      MoeToast.show(context, '好友请求已发送');
    } catch (e) {
      MoeToast.show(context, '发送好友请求失败');
    }
  }

  void _showGiftSelector(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelector(
        targetId: user.id,
        targetType: 'user',
        receiverId: user.id,
        onGiftSent: (gift) {
          MoeToast.show(context, '已向 ${user.username} 赠送了 ${gift.name}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('互动中心'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '好友'),
            Tab(text: '好友请求'),
            Tab(text: '礼物中心'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildFriendRequestsTab(),
          _buildGiftsTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildAddFriendForm(),
        ),
        Expanded(
          child: _friends.isEmpty
              ? const Center(child: Text('暂无好友'))
              : ListView.builder(
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    return ListTile(
                      leading: NetworkAvatarImage(imageUrl: friend.avatar, radius: 25),
                      title: Text(friend.username),
                      subtitle: Text('Moe号: ${friend.moeNo}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () => _showGiftSelector(friend),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat),
                            onPressed: () {
                              // 跳转到聊天页面
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAddFriendForm() {
    final TextEditingController _moeNoController = TextEditingController();

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _moeNoController,
            decoration: const InputDecoration(
              hintText: '输入好友Moe号',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => _sendFriendRequest(_moeNoController.text),
          child: const Text('添加'),
        ),
      ],
    );
  }

  Widget _buildFriendRequestsTab() {
    if (_friendRequests.isEmpty) {
      return const Center(child: Text('暂无好友请求'));
    }

    return ListView.builder(
      itemCount: _friendRequests.length,
      itemBuilder: (context, index) {
        final request = _friendRequests[index];
        final userMap = request['user'] as Map<String, dynamic>;
        final user = User.fromJson(userMap);
        final requestId = request['id'] as String;

        return ListTile(
          leading: NetworkAvatarImage(imageUrl: user.avatar, radius: 25),
          title: Text(user.username),
          subtitle: Text('Moe号: ${user.moeNo}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _acceptFriendRequest(requestId),
                child: const Text('接受'),
              ),
              TextButton(
                onPressed: () => _rejectFriendRequest(requestId),
                child: const Text('拒绝'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGiftsTab() {
    final popularGifts = Gift.getPopularGifts();
    final categories = GiftCategory.values;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('热门礼物', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: popularGifts.length,
            itemBuilder: (context, index) {
              final gift = popularGifts[index];
              return GestureDetector(
                onTap: () {
                  MoeToast.show(context, '礼物: ${gift.name} - ¥${gift.price}');
                },
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: gift.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(gift.emoji, style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(gift.name, style: const TextStyle(fontSize: 12)),
                    Text('¥${gift.price}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text('礼物分类', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categories.map<Widget>((category) {
              return GestureDetector(
                onTap: () {
                  final categoryGifts = Gift.getGiftsByCategory(category);
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('${category.displayName}礼物'),
                        content: Container(
                          width: double.maxFinite,
                          height: 300,
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: categoryGifts.length,
                            itemBuilder: (context, index) {
                              final gift = categoryGifts[index];
                              return GestureDetector(
                                onTap: () {
                                  MoeToast.show(context, '礼物: ${gift.name} - ¥${gift.price}');
                                  Navigator.pop(context);
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: gift.color.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Center(
                                        child: Text(gift.emoji, style: const TextStyle(fontSize: 24)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(gift.name, style: const TextStyle(fontSize: 10)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Chip(
                  label: Row(
                    children: [
                      Text(category.icon),
                      const SizedBox(width: 5),
                      Text(category.displayName),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
