import 'package:flutter/material.dart';

import '../../models/gift.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/gift_selector.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

/// 底部导航「互动」：加好友 / 处理申请 / 送礼入口 / 商城礼物预览。
/// 数据走 REST：`/api/user/:id/friends`、`friend-requests/*`、`/api/gifts`；送礼走 [GiftSelector] → `/gifts/send`。
class InteractionPage extends StatefulWidget {
  final String currentUserId;

  const InteractionPage({super.key, required this.currentUserId});

  @override
  State<InteractionPage> createState() => _InteractionPageState();
}

class _InteractionPageState extends State<InteractionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _moeNoController = TextEditingController();

  List<User> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];

  bool _friendsLoading = false;
  bool _requestsLoading = false;
  String? _friendsError;
  String? _requestsError;

  List<Gift> _catalogGifts = [];
  bool _catalogLoading = false;
  String? _catalogError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (_loggedIn) {
      _refreshAll();
    }
  }

  bool get _loggedIn => widget.currentUserId.trim().isNotEmpty;

  @override
  void dispose() {
    _moeNoController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadFriends(),
      _loadFriendRequests(),
      _loadGiftCatalog(),
    ]);
  }

  String _err(Object e) {
    if (e is ApiException) return e.message;
    return '网络异常，请稍后重试';
  }

  Future<void> _loadFriends() async {
    if (!_loggedIn) return;
    setState(() {
      _friendsLoading = true;
      _friendsError = null;
    });
    try {
      final friends = await ApiService.getFriends(widget.currentUserId);
      if (!mounted) return;
      setState(() {
        _friends = friends;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _friendsError = _err(e));
      MoeToast.error(context, _friendsError!);
    } finally {
      if (mounted) setState(() => _friendsLoading = false);
    }
  }

  Future<void> _loadFriendRequests() async {
    if (!_loggedIn) return;
    setState(() {
      _requestsLoading = true;
      _requestsError = null;
    });
    try {
      final requests =
          await ApiService.getIncomingFriendRequests(widget.currentUserId);
      if (!mounted) return;
      setState(() => _friendRequests = requests);
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestsError = _err(e));
      MoeToast.error(context, _requestsError!);
    } finally {
      if (mounted) setState(() => _requestsLoading = false);
    }
  }

  Future<void> _loadGiftCatalog() async {
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    try {
      final rows = await ApiService.getGifts(page: 1, pageSize: 60);
      if (!mounted) return;
      setState(() {
        _catalogGifts = rows.map(Gift.fromCatalogApi).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _catalogError = _err(e));
    } finally {
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    if (!_loggedIn || requestId.isEmpty) return;
    try {
      await ApiService.acceptFriendRequest(widget.currentUserId, requestId);
      if (mounted) MoeToast.success(context, '已接受好友请求');
      await _loadFriendRequests();
      await _loadFriends();
    } catch (e) {
      if (mounted) MoeToast.error(context, _err(e));
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    if (!_loggedIn || requestId.isEmpty) return;
    try {
      await ApiService.rejectFriendRequest(widget.currentUserId, requestId);
      if (mounted) MoeToast.success(context, '已拒绝');
      await _loadFriendRequests();
    } catch (e) {
      if (mounted) MoeToast.error(context, _err(e));
    }
  }

  Future<void> _sendFriendRequest(String moeNo) async {
    if (!_loggedIn) {
      MoeToast.error(context, '请先登录');
      return;
    }
    final v = moeNo.trim();
    if (v.isEmpty) {
      MoeToast.show(context, '请输入对方 Moe 号');
      return;
    }
    try {
      await ApiService.sendFriendRequestByMoeNo(widget.currentUserId, v);
      if (mounted) {
        MoeToast.success(context, '好友请求已发送');
        _moeNoController.clear();
      }
    } catch (e) {
      if (mounted) MoeToast.error(context, _err(e));
    }
  }

  void _showGiftSelector(User user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelector(
        targetId: user.id,
        targetType: 'user',
        receiverId: user.id,
        onGiftSent: (gift) {
          if (mounted) {
            MoeToast.success(context, '已向 ${user.username} 赠送 ${gift.name}');
          }
        },
      ),
    );
  }

  Map<String, dynamic>? _applicantFromRequest(Map<String, dynamic> request) {
    final from = request['from_user'];
    if (from is Map) return Map<String, dynamic>.from(from);
    final u = request['user'];
    if (u is Map) return Map<String, dynamic>.from(u);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_loggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('互动中心'),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 56, color: scheme.outline),
                const SizedBox(height: 16),
                Text(
                  '登录后即可使用加好友、收申请、送礼等功能',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('互动中心'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _friendsLoading || _requestsLoading ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF7F7FD5),
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: const Color(0xFF7F7FD5),
          tabs: const [
            Tab(text: '好友'),
            Tab(text: '好友请求'),
            Tab(text: '礼物'),
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
    return RefreshIndicator(
      color: const Color(0xFF7F7FD5),
      onRefresh: _loadFriends,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildAddFriendForm(),
            ),
          ),
          if (_friendsLoading && _friends.isEmpty)
            const SliverFillRemaining(child: Center(child: MoeLoading()))
          else if (_friendsError != null && _friends.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_friendsError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadFriends,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_friends.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('暂无好友', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Text(
                      '输入对方 Moe 号发送申请',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final friend = _friends[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: NetworkAvatarImage(
                        imageUrl: friend.avatar,
                        radius: 25,
                      ),
                      title: Text(friend.username),
                      subtitle: Text(
                        friend.moeNo.isEmpty ? 'Moe 号未设置' : 'Moe号: ${friend.moeNo}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: SizedBox(
                        width: 112,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: '送礼物',
                              icon: const Icon(Icons.card_giftcard_outlined),
                              color: const Color(0xFF7F7FD5),
                              onPressed: () => _showGiftSelector(friend),
                            ),
                            IconButton(
                              tooltip: '发消息',
                              icon: const Icon(Icons.chat_bubble_outline_rounded),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/direct-chat',
                                  arguments: {
                                    'userId': friend.id,
                                    'username': friend.username,
                                    'avatar': friend.avatar,
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _friends.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddFriendForm() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _moeNoController,
                decoration: const InputDecoration(
                  hintText: '输入对方 10 位 Moe 号',
                  border: InputBorder.none,
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _sendFriendRequest(_moeNoController.text),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7F7FD5),
                foregroundColor: Colors.white,
              ),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendRequestsTab() {
    return RefreshIndicator(
      color: const Color(0xFF7F7FD5),
      onRefresh: _loadFriendRequests,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_requestsLoading && _friendRequests.isEmpty)
            const SliverFillRemaining(child: Center(child: MoeLoading()))
          else if (_requestsError != null && _friendRequests.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_requestsError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadFriendRequests,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_friendRequests.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mail_outline_rounded,
                        size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('暂无待处理请求', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final request = _friendRequests[index];
                  final userMap = _applicantFromRequest(request);
                  if (userMap == null || userMap.isEmpty) {
                    return const ListTile(
                      title: Text('数据异常'),
                      subtitle: Text('缺少 from_user'),
                    );
                  }
                  User user;
                  try {
                    user = User.fromJson(userMap);
                  } catch (e) {
                    return ListTile(
                      title: const Text('数据异常'),
                      subtitle: Text('$e'),
                    );
                  }
                  final requestId = request['id']?.toString() ?? '';
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: NetworkAvatarImage(
                        imageUrl: user.avatar,
                        radius: 25,
                      ),
                      title: Text(user.username),
                      subtitle: Text(
                        user.moeNo.isEmpty ? 'Moe 号未设置' : 'Moe号: ${user.moeNo}',
                      ),
                      trailing: SizedBox(
                        width: 168,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: requestId.isEmpty
                                  ? null
                                  : () => _acceptFriendRequest(requestId),
                              child: const Text('接受'),
                            ),
                            TextButton(
                              onPressed: requestId.isEmpty
                                  ? null
                                  : () => _rejectFriendRequest(requestId),
                              child: const Text('拒绝'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _friendRequests.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGiftsTab() {
    return RefreshIndicator(
      color: const Color(0xFF7F7FD5),
      onRefresh: _loadGiftCatalog,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '说明',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在「好友」列表中点击礼物图标，可向好友发送礼物（扣减钱包余额）。本页展示商城礼物目录；若加载失败将使用内置示例数据。',
                    style: TextStyle(
                      color: Colors.grey[700],
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.account_balance_wallet_outlined,
                            size: 18),
                        label: const Text('去钱包充值'),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/wallet'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.people_outline, size: 18),
                        label: const Text('好友列表'),
                        onPressed: () {
                          // 主栏已有「好友」；此处跳到好友页路由（若存在）
                          Navigator.pushNamed(context, '/friends');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_catalogLoading && _catalogGifts.isEmpty)
            const SliverFillRemaining(child: Center(child: MoeLoading()))
          else if (_catalogError != null && _catalogGifts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_catalogError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadGiftCatalog,
                        child: const Text('重试'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '以下为内置示例（与后端礼物 ID 可能不一致，送礼请在好友里选）',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                _catalogGifts.isEmpty ? '内置热门礼物' : '商城礼物',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) {
                  final displayGifts = _catalogGifts.isNotEmpty
                      ? _catalogGifts
                      : Gift.getPopularGifts(limit: 8);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: displayGifts.length,
                    itemBuilder: (context, index) {
                      final gift = displayGifts[index];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            MoeToast.show(
                              context,
                              '${gift.name} · ¥${gift.price.toStringAsFixed(2)}',
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(gift.emoji,
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 4),
                                Text(
                                  gift.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  '¥${gift.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
