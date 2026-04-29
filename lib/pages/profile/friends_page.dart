import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth_service.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/gift_selector.dart';
import '../../services/presence_service.dart';
import '../../widgets/avatar_image.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/fade_in_up.dart';

// 筛选类型
enum _FilterType { all, online, recent }

// 好友分组
enum _FriendGroup {
  all,
  online,
  recent,
  favorite,
}

class FriendsPage extends StatefulWidget {
  /// 底部「联系人」内子分区：0 好友 · 1 申请。
  final int initialHubTabIndex;

  const FriendsPage({super.key, this.initialHubTabIndex = 0});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  List<User> _friends = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  /// 当前用户资料（空状态 / 添加好友里展示「我的 Moe 号」）
  User? _selfProfile;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchKeyword = '';
  Map<String, bool> _onlineStatus = {};
  Timer? _onlineTimer;
  bool _presenceListening = false;
  _FilterType _filterType = _FilterType.all;
  _FriendGroup _currentGroup = _FriendGroup.all;
  Set<String> _favoriteFriends = {};
  Map<String, DateTime> _recentInteractions = {};
  bool _showFab = true;

  /// 每个 [FriendsPage] 实例唯一，避免 IndexedStack 里常驻一页 + `pushNamed('/friends')`
  /// 再打开一页时，两个 FAB 共用同一 `heroTag` 触发 Overlay/GlobalKey 冲突。
  final Object _fabHeroTag = Object();

  late final TabController _hubTabController;

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
    final initialTab = widget.initialHubTabIndex.clamp(0, 1);
    _hubTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialTab,
    );
    _hubTabController.addListener(_onHubTabChanged);
    _loadFriends();
  }

  void _onHubTabChanged() {
    if (!mounted) return;
    if (_hubTabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _hubTabController.removeListener(_onHubTabChanged);
    _hubTabController.dispose();
    _onlineTimer?.cancel();
    if (_presenceListening) {
      PresenceService.online.removeListener(_onPresenceUpdate);
    }
    super.dispose();
  }

  void _goToRequestsTab() {
    if (_hubTabController.index != 1) {
      _hubTabController.animateTo(1);
    }
  }

  String _apiErr(Object e) {
    if (e is ApiException) return e.message;
    return '网络异常，请稍后重试';
  }

  Future<void> _acceptIncomingRequest(String requestId) async {
    final me = AuthService.currentUser;
    if (me == null || requestId.isEmpty) return;
    try {
      await ApiService.acceptFriendRequest(me, requestId);
      if (mounted) MoeToast.success(context, '已同意');
      await _loadFriends();
    } catch (e) {
      if (mounted) MoeToast.error(context, _apiErr(e));
    }
  }

  Future<void> _rejectIncomingRequest(String requestId) async {
    final me = AuthService.currentUser;
    if (me == null || requestId.isEmpty) return;
    try {
      await ApiService.rejectFriendRequest(me, requestId);
      if (mounted) MoeToast.info(context, '已拒绝');
      await _loadFriends();
    } catch (e) {
      if (mounted) MoeToast.error(context, _apiErr(e));
    }
  }

  void _openGiftSelector(User user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GiftSelector(
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
      final friends = await ApiService.getFriends(currentUserId);
      final incoming =
          await ApiService.getIncomingFriendRequests(currentUserId);
      User? self;
      try {
        self = await ApiService.getUserInfo(currentUserId);
      } catch (_) {}
      friends.sort((a, b) => a.username.compareTo(b.username));
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _incomingRequests = incoming;
        _selfProfile = self;
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

  void _copyToClipboard(BuildContext ctx, String text, String toast) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    if (ctx.mounted) MoeToast.success(ctx, toast);
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
    showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _AddFriendBottomSheet(
            rootContext: rootContext,
            myMoe: _selfProfile?.moeNo ?? '',
            onReloadFriends: _loadFriends,
          ),
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
      final moe = u.moeNo.toLowerCase();
      return name.contains(keyword) ||
          email.contains(keyword) ||
          moe.contains(keyword);
    }).toList();
  }

  PreferredSizeWidget _contactsAppBar() {
    return AppBar(
      title: const Text(
        '联系人',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      foregroundColor: const Color(0xFF333333),
      actions: [
        if (_incomingRequests.isNotEmpty)
          IconButton(
            tooltip: '查看申请',
            onPressed: _goToRequestsTab,
            icon: Badge(
              label: Text('${_incomingRequests.length}'),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                color: Color(0xFF7F7FD5),
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF7F7FD5).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: '添加好友',
            icon: const Icon(Icons.person_add_rounded, color: Color(0xFF7F7FD5)),
            onPressed: _showAddFriendDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedOutScaffold() {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _contactsAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 56, color: scheme.outline),
              const SizedBox(height: 18),
              Text(
                '登录后管理好友、处理申请与送礼物',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHubTabStrip() {
    final scheme = Theme.of(context).colorScheme;
    final track = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHighest.withOpacity(0.5)
        : const Color(0xFFE8ECF3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Material(
        color: track,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: TabBar(
            controller: _hubTabController,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            labelColor: const Color(0xFF5C6BC0),
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            splashBorderRadius: BorderRadius.circular(14),
            tabs: [
              const Tab(text: '好友'),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('申请'),
                    if (_incomingRequests.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_incomingRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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

  /// 过滤无法解析的申请行，避免 [SliverList] 中出现零尺寸子项触发渲染断言。
  List<Map<String, dynamic>> get _renderableIncomingRequests {
    return _incomingRequests.where((row) {
      final map = _applicantFromRequest(row);
      if (map == null || map.isEmpty) return false;
      try {
        User.fromJson(map);
      } catch (_) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildIncomingRequestsTab() {
    return RefreshIndicator(
      onRefresh: _loadFriends,
      color: const Color(0xFF7F7FD5),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                '待你处理的好友申请',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_incomingRequests.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '暂无申请',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '下拉可刷新',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final row = _renderableIncomingRequests[i];
                    final u = User.fromJson(_applicantFromRequest(row)!);
                    final rid = row['id']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 360;
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    NetworkAvatarImage(
                                      imageUrl: u.avatar,
                                      radius: 26,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u.username,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (u.moeNo.isNotEmpty)
                                            Text(
                                              'Moe ${u.moeNo}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    compact
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: rid.isEmpty
                                                    ? null
                                                    : () => _rejectIncomingRequest(rid),
                                                child: const Text('拒绝'),
                                              ),
                                              FilledButton(
                                                onPressed: rid.isEmpty
                                                    ? null
                                                    : () => _acceptIncomingRequest(rid),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF7F7FD5),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                child: const Text('同意'),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: rid.isEmpty
                                                    ? null
                                                    : () => _rejectIncomingRequest(rid),
                                                child: const Text('拒绝'),
                                              ),
                                              const SizedBox(width: 4),
                                              FilledButton(
                                                onPressed: rid.isEmpty
                                                    ? null
                                                    : () => _acceptIncomingRequest(rid),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF7F7FD5),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                child: const Text('同意'),
                                              ),
                                            ],
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: _renderableIncomingRequests.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.currentUser == null) {
      return _buildLoggedOutScaffold();
    }
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: _contactsAppBar(),
        body: const Center(child: MoeLoading()),
      );
    }
    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: _contactsAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 80,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadFriends,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF7F7FD5).withOpacity(0.4),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _contactsAppBar(),
      body: Column(
        children: [
          _buildHubTabStrip(),
          Expanded(
            child: TabBarView(
              controller: _hubTabController,
              children: [
                _buildFriendsListTab(),
                _buildIncomingRequestsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _hubTabController.index == 0 &&
              _friends.isNotEmpty &&
              _showFab
          ? _buildFloatingActionButton()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      heroTag: _fabHeroTag,
      onPressed: _showAddFriendDialog,
      backgroundColor: const Color(0xFF7F7FD5),
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Icon(Icons.person_add_rounded, size: 24),
    );
  }

  Widget _buildFriendsListTab() {
    if (_friends.isEmpty) {
      final myMoe = _selfProfile?.moeNo ?? '';
      final myEmail = _selfProfile?.email ?? '';
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_incomingRequests.isNotEmpty)
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      child: InkWell(
                        onTap: _goToRequestsTab,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF7F7FD5).withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mail_outline_rounded,
                                color: const Color(0xFF7F7FD5),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_incomingRequests.length} 条好友申请，点击查看',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey[500],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_incomingRequests.isNotEmpty) const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F7FD5).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_outline_rounded,
                            size: 36,
                            color: Color(0xFF7F7FD5),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '还没有好友',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '用对方的邮箱或 10 位 Moe 号发送申请；对方也可用你的信息搜索你。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (myMoe.isNotEmpty || myEmail.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '我的账号',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (myMoe.isNotEmpty)
                            Material(
                              color: const Color(0xFFF5F7FF),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => _copyToClipboard(
                                  context,
                                  myMoe,
                                  '已复制我的 Moe 号',
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Moe 号',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              myMoe,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1,
                                                color: Color(0xFF5C6BC0),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 20,
                                        color: Colors.grey[700],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (myMoe.isNotEmpty && myEmail.isNotEmpty)
                            const SizedBox(height: 8),
                          if (myEmail.isNotEmpty)
                            Material(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => _copyToClipboard(
                                  context,
                                  myEmail,
                                  '已复制邮箱',
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '邮箱',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              myEmail,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 20,
                                        color: Colors.grey[700],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _showAddFriendDialog,
                          icon: const Icon(Icons.person_add_rounded, size: 20),
                          label: const Text('添加好友'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7F7FD5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    
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
                hintText: '搜索昵称、邮箱或 Moe 号',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                  _showFab = value.isEmpty;
                });
              },
            ),
          ),
        ),
        
        // 分组标签栏
        _buildGroupTabs(),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFriends,
            color: const Color(0xFF7F7FD5),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _getFilteredFriends().length,
              itemBuilder: (context, index) {
                final user = _getFilteredFriends()[index];
                return _buildFriendCard(user, index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildGroupTab(_FriendGroup.all, '全部', Icons.people_rounded),
          const SizedBox(width: 10),
          _buildGroupTab(_FriendGroup.online, '在线', Icons.circle_rounded),
          const SizedBox(width: 10),
          _buildGroupTab(_FriendGroup.recent, '最近', Icons.access_time_rounded),
          const SizedBox(width: 10),
          _buildGroupTab(_FriendGroup.favorite, '收藏', Icons.star_rounded),
        ],
      ),
    );
  }

  Widget _buildGroupTab(_FriendGroup group, String label, IconData icon) {
    final isSelected = _currentGroup == group;
    final onlineCount = _friends.where((f) => _onlineStatus[f.id] ?? false).length;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _currentGroup = group;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7F7FD5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isSelected ? const Color(0xFF7F7FD5) : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
              if (group == _FriendGroup.online && onlineCount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '$onlineCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<User> _getFilteredFriends() {
    var friends = _filteredFriends;
    
    switch (_currentGroup) {
      case _FriendGroup.online:
        friends = friends.where((f) => _onlineStatus[f.id] ?? false).toList();
        break;
      case _FriendGroup.recent:
        friends.sort((a, b) {
          final aTime = _recentInteractions[a.id] ?? DateTime(0);
          final bTime = _recentInteractions[b.id] ?? DateTime(0);
          return bTime.compareTo(aTime);
        });
        break;
      case _FriendGroup.favorite:
        friends = friends.where((f) => _favoriteFriends.contains(f.id)).toList();
        break;
      case _FriendGroup.all:
      default:
        friends.sort((a, b) {
          final aOnline = (_onlineStatus[a.id] ?? false) ? 1 : 0;
          final bOnline = (_onlineStatus[b.id] ?? false) ? 1 : 0;
          if (aOnline != bOnline) return bOnline.compareTo(aOnline);
          return a.username.compareTo(b.username);
        });
        break;
    }
    
    return friends;
  }

  Widget _buildFriendCard(User user, int index) {
    final isOnline = _onlineStatus[user.id] ?? false;
    final dmUnread =
        context.watch<NotificationProvider>().unreadDmBySender[user.id] ?? 0;
    final isFavorite = _favoriteFriends.contains(user.id);
    return FadeInUp(
      key: ValueKey('friend_${user.id}'),
      duration: const Duration(milliseconds: 200),
      delay: Duration(milliseconds: 50 * (index % 5)),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isOnline ? const Color(0xFF4CAF50).withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            _updateRecentInteraction(user.id);
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
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: isOnline ? const Color(0xFF4CAF50).withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: NetworkAvatarImage(
                          imageUrl: user.avatar,
                          radius: 28,
                          placeholderIcon: Icons.person,
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF333333),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isOnline)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '在线',
                                style: TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
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
                      if (user.moeNo.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _copyToClipboard(
                            context,
                            user.moeNo,
                            '已复制 Moe 号',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    user.moeNo,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                      color: Colors.grey[800],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 15,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
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
                    
                    // 收藏按钮
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          if (isFavorite) {
                            _favoriteFriends.remove(user.id);
                          } else {
                            _favoriteFriends.add(user.id);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isFavorite ? const Color(0xFFFFD700).withOpacity(0.1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFavorite ? const Color(0xFFFFD700) : Colors.grey[400],
                          size: 20,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Tooltip(
                      message: '送礼物',
                      child: Material(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openGiftSelector(user),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.card_giftcard_rounded,
                              color: Color(0xFFE8A598),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // 聊天按钮
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7F7FD5).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () {
                          _updateRecentInteraction(user.id);
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _updateRecentInteraction(String userId) {
    setState(() {
      _recentInteractions[userId] = DateTime.now();
    });
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

class _AddFriendBottomSheet extends StatefulWidget {
  const _AddFriendBottomSheet({
    required this.rootContext,
    required this.myMoe,
    required this.onReloadFriends,
  });

  final BuildContext rootContext;
  final String myMoe;
  final VoidCallback onReloadFriends;

  @override
  State<_AddFriendBottomSheet> createState() => _AddFriendBottomSheetState();
}

class _AddFriendBottomSheetState extends State<_AddFriendBottomSheet> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyLine(BuildContext ctx, String text, String toast) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    if (ctx.mounted) MoeToast.success(ctx, toast);
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = '请输入邮箱或 Moe 号');
      return;
    }
    final currentUserId = AuthService.currentUser;
    if (currentUserId == null) {
      if (mounted) Navigator.of(context).pop();
      if (widget.rootContext.mounted) {
        MoeToast.error(widget.rootContext, '请先登录');
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (raw.contains('@')) {
        final targetUser = await ApiService.checkUserByEmail(raw);
        if (targetUser.id == currentUserId) {
          setState(() {
            _isLoading = false;
            _error = '不能添加自己为好友';
          });
          return;
        }
        await ApiService.sendFriendRequestByUserId(currentUserId, targetUser.id);
      } else if (RegExp(r'^\d{10}$').hasMatch(raw)) {
        await ApiService.sendFriendRequestByMoeNo(currentUserId, raw);
      } else {
        setState(() {
          _isLoading = false;
          _error = '请输入有效邮箱或 10 位 Moe 号';
        });
        return;
      }
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        Navigator.of(context).pop();
        MoeToast.success(widget.rootContext, '好友申请已发送');
        widget.onReloadFriends();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetContext = context;
    final myMoe = widget.myMoe;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '添加好友',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入对方的注册邮箱，或 10 位数字 Moe 号，我们会向对方发送好友申请。',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '邮箱或 Moe 号',
                hintText: '例如 name@example.com 或 1234567890',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (myMoe.isNotEmpty) ...[
              Text(
                '我的 Moe 号（可复制发给对方）',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: const Color(0xFFF0F2FF),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _copyLine(
                    sheetContext,
                    myMoe,
                    '已复制我的 Moe 号',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            myMoe,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Color(0xFF5C6BC0),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.copy_rounded,
                          size: 20,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(sheetContext).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7F7FD5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('发送申请'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
