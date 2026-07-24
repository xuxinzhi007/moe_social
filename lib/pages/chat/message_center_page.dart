import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/motion/moe_sheet.dart';
import '../profile/friends_page.dart';
import '../profile/widgets/add_friend_bottom_sheet.dart';
import '../../services/user_service.dart';
import 'conversations_page.dart';

/// 底部 Tab「好友」承载普通 IM：私信会话优先，好友列表作为找人入口。
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    (label: '私信', icon: Icons.chat_bubble_outline_rounded),
    (label: '好友', icon: Icons.group_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      template: PageTemplate.fullscreen,
      backgroundColor: MoeTokens.pageBackground,
      body: Scaffold(
        backgroundColor: MoeTokens.pageBackground,
        appBar: AppBar(
          title: Text(
            '消息',
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
                    for (final t in _tabs)
                      Tab(
                        height: 36,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.icon, size: 16),
                            const SizedBox(width: 4),
                            Text(t.label),
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
                  const FriendsPage(contactsOnly: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
