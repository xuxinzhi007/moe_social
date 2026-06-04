import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../discover/discover_match_tab.dart';
import '../profile/friends_page.dart';
import 'conversations_page.dart';

class MessageCenterPage extends StatelessWidget {
  const MessageCenterPage({super.key});

  void _openContactsSheet(BuildContext context) {
    _openPanel(
      context,
      title: '同好',
      icon: Icons.group_rounded,
      heightRatio: 0.78,
      child: const FriendsPage(contactsOnly: true),
    );
  }

  void _openMatchSheet(BuildContext context) {
    _openPanel(
      context,
      title: '在线匹配',
      icon: Icons.favorite_rounded,
      heightRatio: 0.76,
      child: const DiscoverMatchTab(compact: true),
    );
  }

  void _openPanel(
    BuildContext context, {
    required String title,
    required IconData icon,
    required double heightRatio,
    required Widget child,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        final screen = MediaQuery.sizeOf(context);
        final height = screen.height * heightRatio;
        final maxWidth = screen.width >= 720 ? 640.0 : double.infinity;
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                height: height,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    _sheetHandle(),
                    _sheetHeader(context, title: title, icon: icon),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetHandle() {
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

  Widget _sheetHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 10, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MoeTokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: MoeTokens.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: MoeTokens.titleText,
              ),
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text(
          '消息',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: MoeTokens.titleText,
        actions: [
          IconButton(
            tooltip: '在线匹配',
            onPressed: () => _openMatchSheet(context),
            icon: const Icon(Icons.favorite_rounded),
          ),
          IconButton(
            tooltip: '同好',
            onPressed: () => _openContactsSheet(context),
            icon: const Icon(Icons.group_rounded),
          ),
        ],
      ),
      body: ConversationsPage(
        embedded: true,
        showEmbeddedToolbar: false,
        onEmptyFindFriends: () => _openContactsSheet(context),
        onEmptyExplore: () => _openMatchSheet(context),
        emptyExploreLabel: '在线匹配',
        emptyExploreIcon: Icons.favorite_rounded,
      ),
    );
  }
}
