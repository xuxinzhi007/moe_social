import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth_service.dart';
import '../../services/friend_request_sync.dart';
import '../../services/presence_service.dart';
import '../../services/user_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/moe_toast.dart';
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
    HapticFeedback.selectionClick();
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
                if (_tabController.index == 1)
                  IconButton(
                    tooltip: '搜索好友',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      if (AuthService.currentUser == null) {
                        MoeToast.error(context, '请先登录');
                        return;
                      }
                      Navigator.pushNamed(context, '/friend-search');
                    },
                    icon: const Icon(Icons.search_rounded),
                  ),
                IconButton(
                  tooltip: hasRequests ? '好友申请（$incomingRequestCount）' : '好友申请',
                  onPressed: _openRequests,
                  icon: Badge(
                    isLabelVisible: hasRequests,
                    backgroundColor: MoeTokens.warning,
                    label: Text(
                      incomingRequestCount > 99
                          ? '99+'
                          : '$incomingRequestCount',
                    ),
                    child: Icon(
                      hasRequests
                          ? Icons.mark_email_unread_outlined
                          : Icons.mail_outline_rounded,
                    ),
                  ),
                ),
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
                      color: MoeTokens.softChipBg,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                      border: Border.all(color: MoeTokens.surfaceBorder),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerHeight: 0,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: MoeTokens.surface1,
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusFull),
                        boxShadow: MoeTokens.shadowSm(),
                      ),
                      labelColor: MoeTokens.primary,
                      unselectedLabelColor: MoeTokens.hintText,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: MoeTokens.textSm,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: MoeTokens.textSm,
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
