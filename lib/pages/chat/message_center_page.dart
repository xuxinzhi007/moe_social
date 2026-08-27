import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth_service.dart';
import '../../services/friend_request_sync.dart';
import '../../services/presence_service.dart';
import '../../services/user_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/moe_badge_dot.dart';
import '../../widgets/motion/moe_sheet.dart';
import '../profile/friends_page.dart';
import '../profile/widgets/add_friend_bottom_sheet.dart';
import 'conversations_page.dart';

/// 底部 Tab「好友」：聊天优先，通讯录找人；申请角标走 WS 实时同步。
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// 递增以通知 [FriendsPage] 打开申请面板。
  final ValueNotifier<int> _openRequestsTick = ValueNotifier<int>(0);

  static const _tabs = [
    (label: '聊天', icon: Icons.chat_bubble_outline_rounded),
    (label: '通讯录', icon: Icons.group_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    PresenceService.start();
    unawaited(FriendRequestSync.refreshIncomingCount());
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _openRequestsTick.dispose();
    super.dispose();
  }

  void _showAddFriendSheet() {
    final rootContext = context;
    unawaited(_openAddFriendSheet(rootContext));
  }

  Future<void> _openAddFriendSheet(BuildContext rootContext) async {
    final uid = AuthService.currentUser;
    if (uid == null) return;
    var myMoe = '';
    try {
      final me = await UserService.getUserInfo(uid);
      myMoe = me.moeNo;
    } catch (_) {}

    if (!rootContext.mounted) return;
    MoeSheet.show<void>(
      rootContext,
      builder: (_) => AddFriendBottomSheet(
        rootContext: rootContext,
        myMoe: myMoe,
        onReloadFriends: () {
          unawaited(FriendRequestSync.refreshIncomingCount());
          FriendRequestSync.bumpTick();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _openRequests() {
    HapticFeedback.lightImpact();
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
    _openRequestsTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FriendRequestSync.incomingCount,
      builder: (context, incomingRequestCount, _) {
        final hasRequests = incomingRequestCount > 0;

        return AdaptivePageScaffold(
          template: PageTemplate.fullscreen,
          backgroundColor: MoeTokens.pageBackground,
          body: Scaffold(
            backgroundColor: MoeTokens.pageBackground,
            appBar: AppBar(
              title: Text(
                '好友',
                style: TextStyle(
                  fontWeight: MoeTokens.fontWeightTitle,
                  fontSize: MoeTokens.textXl,
                  color: MoeTokens.titleText,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: MoeTokens.surface1,
              foregroundColor: MoeTokens.titleText,
              surfaceTintColor: Colors.transparent,
              shape: const Border(
                bottom: BorderSide(color: MoeTokens.surfaceBorder),
              ),
              actions: [
                IconButton(
                  tooltip: '添加好友',
                  onPressed: _showAddFriendSheet,
                  icon: const Icon(Icons.person_add_rounded),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: MoeTokens.surface1,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                      border: Border.all(color: MoeTokens.surfaceBorder),
                      boxShadow: MoeTokens.shadowCard(),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerHeight: 0,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: MoeTokens.primaryGradient,
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: MoeTokens.hintText,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      tabs: [
                        for (var i = 0; i < _tabs.length; i++)
                          Tab(
                            height: 36,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_tabs[i].icon, size: 16),
                                const SizedBox(width: 4),
                                Text(_tabs[i].label),
                                if (i == 1 && hasRequests) ...[
                                  const SizedBox(width: 6),
                                  MoeBadgeDot.count(
                                    count: incomingRequestCount,
                                    // 保持原橙色申请角标语义
                                    color: MoeTokens.warning,
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: Column(
              children: [
                if (hasRequests && _tabController.index == 0)
                  _FriendRequestBanner(
                    count: incomingRequestCount,
                    onTap: _openRequests,
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ConversationsPage(
                        embedded: true,
                        showEmbeddedToolbar: false,
                        onEmptyFindFriends: () => _tabController.animateTo(1),
                      ),
                      FriendsPage(
                        contactsOnly: true,
                        hideAddAction: true,
                        openRequestsTick: _openRequestsTick,
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
}

class _FriendRequestBanner extends StatelessWidget {
  const _FriendRequestBanner({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MoeTokens.softLavenderBg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: MoeTokens.surfaceBorder),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 18,
                color: MoeTokens.primary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count == 1 ? '有 1 位同好想认识你' : '有 $count 条好友申请待处理',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MoeTokens.titleText,
                  ),
                ),
              ),
              Text(
                '去看看',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MoeTokens.primary,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: MoeTokens.hintText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
