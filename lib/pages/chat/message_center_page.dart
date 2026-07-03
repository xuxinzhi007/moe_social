import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../profile/friends_page.dart';
import '../profile/widgets/add_friend_bottom_sheet.dart';
import 'conversations_page.dart';

/// 底部 Tab「好友」：私信会话 + 同好列表，定位清晰、风格与首页 Tab 对齐。
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    (label: '聊天', icon: Icons.chat_bubble_outline_rounded),
    (label: '同好', icon: Icons.group_outlined),
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
      final me = await ApiService.getUserInfo(uid);
      myMoe = me.moeNo;
    } catch (_) {}

    if (!rootContext.mounted) return;
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
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: AddFriendBottomSheet(
            rootContext: rootContext,
            myMoe: myMoe,
            onReloadFriends: () {
              if (mounted) setState(() {});
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);

    return AdaptivePageScaffold(
      template: PageTemplate.fullscreen,
      backgroundColor: MoeTokens.pageBackground,
      body: Scaffold(
        backgroundColor: MoeTokens.pageBackground,
        appBar: AppBar(
          title: const Text(
            '好友',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: MoeTokens.pageBackground,
          foregroundColor: MoeTokens.titleText,
          actions: [
            IconButton(
              tooltip: '添加同好',
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: MoeTokens.cardShadow(tint: moe.primary, blur: 10),
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
        body: TabBarView(
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
    );
  }
}
