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
import '../../widgets/moe_error_state.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/fade_in_up.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import '../discover/discover_match_tab.dart';
import 'widgets/add_friend_bottom_sheet.dart';
import 'widgets/friends_logged_out_body.dart';

// 好友分组
enum _FriendGroup {
  all,
  online,
  recent,
  favorite,
}

class FriendsPage extends StatefulWidget {
  final bool contactsOnly;

  const FriendsPage({
    super.key,
    this.contactsOnly = false,
  });

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with WidgetsBindingObserver {
  MoeTheme get _moe => MoeTheme.of(context);

  List<User> _friends = [];
  List<Map<String, dynamic>> _incomingRequests = [];

  /// 当前用户资料（空状态 / 添加好友里展示「我的 Moe 号」）
  User? _selfProfile;
  bool _isLoading = true;
  bool _hasError = false;
  Object? _loadError;
  String _searchKeyword = '';
  Map<String, bool> _onlineStatus = {};
  Timer? _onlineTimer;
  Timer? _friendsHubPollTimer;
  bool _presenceListening = false;
  _FriendGroup _currentGroup = _FriendGroup.all;
  final Set<String> _favoriteFriends = {};
  final Map<String, DateTime> _recentInteractions = {};

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
    WidgetsBinding.instance.addObserver(this);
    _friendsHubPollTimer = Timer.periodic(const Duration(seconds: 22), (_) {
      if (!mounted || AuthService.currentUser == null) return;
      unawaited(_loadFriends(silent: true));
    });
    _loadFriends();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AuthService.currentUser != null) {
      unawaited(_loadFriends(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _friendsHubPollTimer?.cancel();
    _onlineTimer?.cancel();
    if (_presenceListening) {
      PresenceService.online.removeListener(_onPresenceUpdate);
    }
    super.dispose();
  }

  void _goToRequestsTab() {
    _showRequestsSheet();
  }

  void _showMatchSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.84;
        return SafeArea(
          top: false,
          child: Container(
            height: height,
            decoration: const BoxDecoration(
              color: MoeTokens.pageBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _buildSheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '在线匹配',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MoeTokens.titleText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: DiscoverMatchTab(compact: true)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRequestsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.76;
        return SafeArea(
          top: false,
          child: Container(
            height: height,
            decoration: const BoxDecoration(
              color: MoeTokens.pageBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _buildSheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '好友申请${_incomingRequests.isEmpty ? '' : ' (${_incomingRequests.length})'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MoeTokens.titleText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildIncomingRequestsTab()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
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
    if (!_onlineStatusChanged(next)) return;
    setState(() {
      _onlineStatus = next;
    });
  }

  bool _onlineStatusChanged(Map<String, bool> next) {
    if (next.length != _onlineStatus.length) return true;
    for (final e in next.entries) {
      if (_onlineStatus[e.key] != e.value) return true;
    }
    return false;
  }

  Future<void> _loadFriends({bool silent = false}) async {
    final currentUserId = AuthService.currentUser;
    if (currentUserId == null) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _loadError = '请先登录';
        });
      }
      return;
    }

    if (mounted && !silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _loadError = null;
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
        _loadError = null;
      });

      await _ensureOnlineStatus();
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        debugPrint('FriendsPage silent refresh failed: $e');
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
        _loadError = e;
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

    if (PresenceService.isConnected) {
      final presenceMap = PresenceService.online.value;
      final next = <String, bool>{};
      for (final f in _friends) {
        next[f.id] = presenceMap[f.id] ?? false;
      }
      if (_onlineStatusChanged(next)) {
        setState(() {
          _onlineStatus = next;
        });
      }
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

    if (PresenceService.isConnected) {
      final presenceMap = PresenceService.online.value;
      final next = <String, bool>{};
      for (final f in _friends) {
        next[f.id] = presenceMap[f.id] ?? false;
      }
      if (_onlineStatusChanged(next)) {
        setState(() {
          _onlineStatus = next;
        });
      }
      return;
    }

    final ids = List<String>.from(_friends.map((u) => u.id));
    try {
      final status = await ApiService.getChatOnlineBatch(ids);
      if (!mounted) return;
      setState(() {
        _onlineStatus = status;
      });
    } catch (_) {}
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
          child: AddFriendBottomSheet(
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
    final moe = MoeTheme.of(context);
    return AppBar(
      title: const Text(
        '同好',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      backgroundColor: moe.cardBackground,
      elevation: 0,
      centerTitle: true,
      foregroundColor: MoeTokens.titleText,
      actions: [
        if (_incomingRequests.isNotEmpty)
          IconButton(
            tooltip: '查看申请',
            onPressed: _goToRequestsTab,
            icon: Badge(
              label: Text('${_incomingRequests.length}'),
              child: Icon(
                Icons.mark_email_unread_outlined,
                color: moe.primary,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: moe.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: '添加好友',
            icon: Icon(Icons.person_add_rounded, color: moe.primary),
            onPressed: _showAddFriendDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedOutScaffold() {
    return Scaffold(
      backgroundColor: MoeTheme.of(context).pageBackground,
      appBar: _contactsAppBar(),
      body: const FriendsLoggedOutBody(),
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
    final renderableRequests = _renderableIncomingRequests;
    return RefreshIndicator(
      onRefresh: _loadFriends,
      color: _moe.primary,
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
          if (renderableRequests.isEmpty)
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
                    final row = renderableRequests[i];
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
                                    color: Colors.black.withValues(alpha: 0.05),
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
                                                    : () =>
                                                        _rejectIncomingRequest(
                                                            rid),
                                                child: const Text('拒绝'),
                                              ),
                                              FilledButton(
                                                onPressed: rid.isEmpty
                                                    ? null
                                                    : () =>
                                                        _acceptIncomingRequest(
                                                            rid),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: _moe.primary,
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
                                                    : () =>
                                                        _rejectIncomingRequest(
                                                            rid),
                                                child: const Text('拒绝'),
                                              ),
                                              const SizedBox(width: 4),
                                              FilledButton(
                                                onPressed: rid.isEmpty
                                                    ? null
                                                    : () =>
                                                        _acceptIncomingRequest(
                                                            rid),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: _moe.primary,
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
                  childCount: renderableRequests.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = MoeTheme.of(context).pageBackground;
    if (AuthService.currentUser == null) {
      if (widget.contactsOnly) return const FriendsLoggedOutBody();
      return _buildLoggedOutScaffold();
    }
    if (_isLoading) {
      if (widget.contactsOnly) return const Center(child: MoeLoading());
      return Scaffold(
        backgroundColor: pageBg,
        appBar: _contactsAppBar(),
        body: const Center(child: MoeLoading()),
      );
    }
    if (_hasError) {
      if (widget.contactsOnly) {
        return Center(
          child: MoeErrorState.fromError(
            _loadError,
            scene: MoeErrorScene.contacts,
            onRetry: _loadFriends,
          ),
        );
      }
      return Scaffold(
        backgroundColor: pageBg,
        appBar: _contactsAppBar(),
        body: Center(
          child: MoeErrorState.fromError(
            _loadError,
            scene: MoeErrorScene.contacts,
            onRetry: _loadFriends,
          ),
        ),
      );
    }
    if (widget.contactsOnly) {
      return _buildContactsPanel();
    }
    return Scaffold(
      backgroundColor: pageBg,
      appBar: _contactsAppBar(),
      body: _buildContactsPanel(),
    );
  }

  Widget _buildContactsPanel() {
    if (_friends.isEmpty) {
      return _buildContactsPanelEmpty();
    }

    final filteredFriends = _getFilteredFriends();
    final onlineCount =
        _friends.where((f) => _onlineStatus[f.id] ?? false).length;
    final favoriteCount =
        _friends.where((f) => _favoriteFriends.contains(f.id)).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
          child: _buildContactsPanelSummary(
            onlineCount: onlineCount,
            favoriteCount: favoriteCount,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: _buildContactsPanelActions(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: _buildContactsPanelSearch(),
        ),
        _buildCompactGroupTabs(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFriends,
            color: _moe.primary,
            child: filteredFriends.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                    children: [
                      _buildContactsPanelBlankState(
                        icon: Icons.search_off_rounded,
                        title: '没有匹配联系人',
                        subtitle: '换个关键词或切换分组看看',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 28),
                    itemCount: filteredFriends.length,
                    itemBuilder: (context, index) {
                      return _buildCompactFriendRow(
                        filteredFriends[index],
                        index,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsPanelEmpty() {
    final myMoe = _selfProfile?.moeNo ?? '';
    final myEmail = _selfProfile?.email ?? '';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      children: [
        _buildContactsPanelActions(),
        const SizedBox(height: 14),
        _buildContactsPanelBlankState(
          icon: Icons.people_outline_rounded,
          title: '还没有同好',
          subtitle: '添加好友，或用在线匹配认识新朋友',
        ),
        if (myMoe.isNotEmpty || myEmail.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildMyAccountCard(myMoe: myMoe, myEmail: myEmail),
        ],
      ],
    );
  }

  Widget _buildContactsPanelSummary({
    required int onlineCount,
    required int favoriteCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _summaryPill(
            icon: Icons.groups_rounded,
            label: '同好',
            value: '${_friends.length}',
            color: _moe.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryPill(
            icon: Icons.circle_rounded,
            label: '在线',
            value: '$onlineCount',
            color: const Color(0xFF2EBD85),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryPill(
            icon: Icons.star_rounded,
            label: '收藏',
            value: '$favoriteCount',
            color: const Color(0xFFE8A598),
          ),
        ),
      ],
    );
  }

  Widget _summaryPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: MoeTokens.titleText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsPanelActions() {
    final hasRequests = _incomingRequests.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: _compactActionChip(
            icon: Icons.favorite_rounded,
            label: '匹配',
            color: const Color(0xFFFC6076),
            onTap: _showMatchSheet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _compactActionChip(
            icon: Icons.person_add_rounded,
            label: '添加',
            color: _moe.primary,
            onTap: _showAddFriendDialog,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _compactActionChip(
            icon: hasRequests
                ? Icons.mark_email_unread_rounded
                : Icons.mark_email_read_rounded,
            label: hasRequests ? '${_incomingRequests.length} 申请' : '申请',
            color:
                hasRequests ? const Color(0xFFFF8F00) : const Color(0xFF90A4AE),
            onTap: _showRequestsSheet,
          ),
        ),
      ],
    );
  }

  Widget _compactActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsPanelSearch() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索昵称、邮箱或 Moe 号',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchKeyword = value;
          });
        },
      ),
    );
  }

  Widget _buildCompactGroupTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        children: [
          _compactGroupTab(_FriendGroup.all, '全部'),
          const SizedBox(width: 8),
          _compactGroupTab(_FriendGroup.online, '在线'),
          const SizedBox(width: 8),
          _compactGroupTab(_FriendGroup.recent, '最近'),
          const SizedBox(width: 8),
          _compactGroupTab(_FriendGroup.favorite, '收藏'),
        ],
      ),
    );
  }

  Widget _compactGroupTab(_FriendGroup group, String label) {
    final selected = _currentGroup == group;
    return Expanded(
      child: Material(
        color: selected ? _moe.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentGroup = group);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _moe.primary : Colors.grey.shade200,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFriendRow(User user, int index) {
    final isOnline = _onlineStatus[user.id] ?? false;
    final dmUnread =
        context.watch<NotificationProvider>().unreadDmBySender[user.id] ?? 0;
    final isFavorite = _favoriteFriends.contains(user.id);
    return FadeInUp(
      key: ValueKey('contacts_panel_${user.id}'),
      duration: const Duration(milliseconds: 180),
      delay: Duration(milliseconds: 35 * (index % 5)),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              },
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOnline
                    ? const Color(0xFF2EBD85).withValues(alpha: 0.24)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    NetworkAvatarImage(
                      imageUrl: user.avatar,
                      radius: 23,
                      placeholderIcon: Icons.person,
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF2EBD85)
                              : Colors.grey.shade300,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MoeTokens.titleText,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (dmUnread > 0) ...[
                            const SizedBox(width: 6),
                            _unreadBadge(dmUnread),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.moeNo.isNotEmpty
                            ? 'Moe ${user.moeNo}'
                            : (user.email.isNotEmpty ? user.email : '同好'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '送礼物',
                  onPressed: () => _openGiftSelector(user),
                  icon: const Icon(Icons.card_giftcard_rounded),
                  color: const Color(0xFFE8A598),
                  iconSize: 20,
                  constraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  tooltip: isFavorite ? '取消收藏' : '收藏',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (isFavorite) {
                        _favoriteFriends.remove(user.id);
                      } else {
                        _favoriteFriends.add(user.id);
                      }
                    });
                  },
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color:
                        isFavorite ? const Color(0xFFE8A598) : Colors.grey[400],
                  ),
                  iconSize: 21,
                  constraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  tooltip: '私聊',
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
                  icon: const Icon(Icons.chat_bubble_rounded),
                  color: _moe.primary,
                  iconSize: 20,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unreadBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildContactsPanelBlankState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _moe.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _moe.primary, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MoeTokens.titleText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyAccountCard({
    required String myMoe,
    required String myEmail,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的账号',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (myMoe.isNotEmpty) ...[
            const SizedBox(height: 10),
            _accountCopyRow(
              label: 'Moe 号',
              value: myMoe,
              toast: '已复制我的 Moe 号',
            ),
          ],
          if (myEmail.isNotEmpty) ...[
            const SizedBox(height: 8),
            _accountCopyRow(
              label: '邮箱',
              value: myEmail,
              toast: '已复制邮箱',
            ),
          ],
        ],
      ),
    );
  }

  Widget _accountCopyRow({
    required String label,
    required String value,
    required String toast,
  }) {
    return Material(
      color: const Color(0xFFF7F8FC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _copyToClipboard(context, value, toast),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MoeTokens.titleText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy_rounded, size: 18, color: Colors.grey[600]),
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
        friends =
            friends.where((f) => _favoriteFriends.contains(f.id)).toList();
        break;
      case _FriendGroup.all:
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

  void _updateRecentInteraction(String userId) {
    setState(() {
      _recentInteractions[userId] = DateTime.now();
    });
  }
}
