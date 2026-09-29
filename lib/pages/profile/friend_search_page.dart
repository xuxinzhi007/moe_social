import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth_service.dart';
import '../../models/private_conversation_item.dart';
import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import '../../services/user_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../utils/moe_error_copy.dart';

/// 好友页搜索：聊天和通讯录共用，按会话、昵称、邮箱或 Moe 号查找。
class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  static const int _conversationLimit = 120;

  final TextEditingController _query = TextEditingController();
  List<User> _friends = const [];
  List<PrivateConversationItem> _conversations = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQuery);
    _load();
  }

  @override
  void dispose() {
    _query.removeListener(_onQuery);
    _query.dispose();
    super.dispose();
  }

  void _onQuery() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final me = AuthService.currentUser;
    if (me == null) {
      setState(() {
        _loading = false;
        _error = '请先登录';
        _friends = const [];
        _conversations = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await UserService.getFriends(me);
      friends.sort((a, b) => a.username.compareTo(b.username));
      var conversations = const <PrivateConversationItem>[];
      try {
        final page = await ChatService.listPrivateConversations(
          limit: _conversationLimit,
        );
        conversations = page.items;
      } catch (_) {
        // 会话列表失败时仍可按好友搜索。
      }
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _conversations = conversations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  List<_SearchHit> get _matches {
    final keyword = _query.text.trim().toLowerCase();
    if (keyword.isEmpty) return const [];
    bool hit(String value) => value.toLowerCase().contains(keyword);

    final matches = <_SearchHit>[];
    final seen = <String>{};
    for (final user in _friends) {
      if (!hit(user.username) && !hit(user.email) && !hit(user.moeNo)) {
        continue;
      }
      seen.add(user.id);
      final subtitle = user.moeNo.isNotEmpty
          ? 'Moe ${user.moeNo}'
          : (user.email.isNotEmpty ? user.email : '同好');
      matches.add(
        _SearchHit(
          id: user.id,
          name: user.username,
          avatar: user.avatar,
          subtitle: subtitle,
        ),
      );
    }
    for (final conversation in _conversations) {
      final id = conversation.peerUserId.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      if (!hit(conversation.peerName) &&
          !hit(conversation.peerMoeNo) &&
          !hit(id)) {
        continue;
      }
      seen.add(id);
      final name = conversation.peerName.trim().isEmpty
          ? '用户'
          : conversation.peerName.trim();
      matches.add(
        _SearchHit(
          id: id,
          name: name,
          avatar: conversation.peerAvatar,
          subtitle: conversation.peerMoeNo.trim().isEmpty
              ? '会话'
              : 'Moe ${conversation.peerMoeNo.trim()}',
        ),
      );
    }
    return matches;
  }

  void _openChat(_SearchHit hit) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(
      context,
      '/direct-chat',
      arguments: {
        'userId': hit.id,
        'username': hit.name,
        'avatar': hit.avatar,
      },
    );
  }

  void _openProfile(_SearchHit hit) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      '/user-profile',
      arguments: {
        'userId': hit.id,
        'userName': hit.name,
        'userAvatar': hit.avatar,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: MoeTokens.surface1,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            color: MoeTokens.titleText,
            fontSize: MoeTokens.textBase,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            hintText: '搜索会话、好友昵称或 Moe 号',
            hintStyle: TextStyle(
              color: MoeTokens.hintText,
              fontSize: MoeTokens.textBase,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
            isCollapsed: true,
          ),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              tooltip: '清除',
              onPressed: _query.clear,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: MoeLoading());
    }
    if (_error != null) {
      return Center(
        child: MoeErrorState.fromError(
          _error,
          scene: MoeErrorScene.contacts,
          onRetry: _load,
        ),
      );
    }
    final keyword = _query.text.trim();
    if (keyword.isEmpty) {
      return const _SearchHint(
        icon: Icons.person_search_rounded,
        title: '搜索会话或好友',
        subtitle: '输入昵称、邮箱或 Moe 号',
      );
    }
    final matches = _matches;
    if (matches.isEmpty) {
      return const _SearchHint(
        icon: Icons.search_off_rounded,
        title: '没有匹配结果',
        subtitle: '换个关键词试试',
      );
    }
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: PresenceService.online,
      builder: (context, online, _) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final hit = matches[index];
            return _SearchResultRow(
              hit: hit,
              online: online[hit.id] ?? false,
              onOpenChat: () => _openChat(hit),
              onOpenProfile: () => _openProfile(hit),
            );
          },
        );
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: MoeTokens.hintText),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: MoeTokens.titleText,
                fontSize: MoeTokens.textLg,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MoeTokens.hintText,
                fontSize: MoeTokens.textSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHit {
  const _SearchHit({
    required this.id,
    required this.name,
    required this.avatar,
    required this.subtitle,
  });

  final String id;
  final String name;
  final String avatar;
  final String subtitle;
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.hit,
    required this.online,
    required this.onOpenChat,
    required this.onOpenProfile,
  });

  final _SearchHit hit;
  final bool online;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MoeTokens.surface1,
      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      child: InkWell(
        onTap: onOpenChat,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            border: Border.all(
              color: online
                  ? const Color(0xFF2EBD85).withValues(alpha: 0.24)
                  : MoeTokens.surfaceBorder,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onOpenProfile,
                child: NetworkAvatarImage(
                  imageUrl: hit.avatar,
                  radius: 23,
                  placeholderIcon: Icons.person,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MoeTokens.titleText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hit.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MoeTokens.hintText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
