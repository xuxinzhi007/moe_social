import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/user.dart';
import '../../../theme/moe_tokens.dart';
import '../../../widgets/avatar_image.dart';
import '../../../widgets/moe_empty_state.dart';

/// 好友申请列表（同意 / 拒绝）。供通讯录 Sheet 与枢纽复用。
class FriendRequestsPanel extends StatefulWidget {
  const FriendRequestsPanel({
    super.key,
    required this.requests,
    required this.onRefresh,
    required this.onAccept,
    required this.onReject,
    this.primaryColor = MoeTokens.primary,
  });

  final List<Map<String, dynamic>> requests;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId) onReject;
  final Color primaryColor;

  static Map<String, dynamic>? applicantFromRequest(
    Map<String, dynamic> request,
  ) {
    final from = request['from_user'];
    if (from is Map) return Map<String, dynamic>.from(from);
    final u = request['user'];
    if (u is Map) return Map<String, dynamic>.from(u);
    return null;
  }

  @override
  State<FriendRequestsPanel> createState() => _FriendRequestsPanelState();
}

class _FriendRequestsPanelState extends State<FriendRequestsPanel> {
  final List<User> _justAccepted = [];

  List<Map<String, dynamic>> get _renderable {
    return widget.requests.where((row) {
      final map = FriendRequestsPanel.applicantFromRequest(row);
      if (map == null || map.isEmpty) return false;
      try {
        User.fromJson(map);
      } catch (_) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _handleAccept(String requestId, User user) async {
    try {
      await widget.onAccept(requestId);
      if (!mounted) return;
      setState(() {
        if (!_justAccepted.any((u) => u.id == user.id)) {
          _justAccepted.insert(0, user);
        }
      });
    } catch (_) {
      // 错误由上层 Toast；此处不记入刚通过
    }
  }

  void _openChat(User user) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      '/direct-chat',
      arguments: {
        'userId': user.id,
        'username': user.username,
        'avatar': user.avatar,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderable = _renderable;
    final showEmpty = renderable.isEmpty && _justAccepted.isEmpty;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: widget.primaryColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_justAccepted.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        '刚通过 · 去打个招呼',
                        style: TextStyle(
                          fontSize: MoeTokens.textSm,
                          fontWeight: FontWeight.w700,
                          color: MoeTokens.hintText,
                        ),
                      ),
                    ),
                    for (final user in _justAccepted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AcceptedChatCard(
                          user: user,
                          primaryColor: widget.primaryColor,
                          onChat: () => _openChat(user),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                renderable.isEmpty && _justAccepted.isNotEmpty
                    ? '没有更多待处理申请'
                    : '待你处理的好友申请',
                style: TextStyle(
                  fontSize: MoeTokens.textSm,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (showEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: MoeEmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: '暂无申请',
                  subtitle: '有人想加你时会出现在这里 · 下拉可刷新',
                  compact: true,
                  showCard: false,
                ),
              ),
            )
          else if (renderable.isEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 24))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final row = renderable[i];
                    final u = User.fromJson(
                      FriendRequestsPanel.applicantFromRequest(row)!,
                    );
                    final rid = row['id']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RequestCard(
                        user: u,
                        requestId: rid,
                        primaryColor: widget.primaryColor,
                        onAccept: () => _handleAccept(rid, u),
                        onReject: () => widget.onReject(rid),
                      ),
                    );
                  },
                  childCount: renderable.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AcceptedChatCard extends StatelessWidget {
  const _AcceptedChatCard({
    required this.user,
    required this.primaryColor,
    required this.onChat,
  });

  final User user;
  final Color primaryColor;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MoeTokens.softLavenderBg,
      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.22),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            NetworkAvatarImage(imageUrl: user.avatar, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const Text(
                    '已是好友',
                    style: TextStyle(
                      fontSize: MoeTokens.textSm,
                      color: MoeTokens.hintText,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onChat,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 16),
              label: const Text('去聊天'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.user,
    required this.requestId,
    required this.primaryColor,
    required this.onAccept,
    required this.onReject,
  });

  final User user;
  final String requestId;
  final Color primaryColor;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Material(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
              border: Border.all(color: MoeTokens.surfaceBorder),
              boxShadow: MoeTokens.shadowCard(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
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
                    child: NetworkAvatarImage(
                      imageUrl: user.avatar,
                      radius: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: MoeTokens.titleText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.moeNo.isNotEmpty)
                          Text(
                            'Moe ${user.moeNo}',
                            style: const TextStyle(
                              fontSize: MoeTokens.textSm,
                              color: MoeTokens.hintText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (compact)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: requestId.isEmpty ? null : onReject,
                          child: const Text('拒绝'),
                        ),
                        FilledButton(
                          onPressed: requestId.isEmpty ? null : onAccept,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('同意'),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: requestId.isEmpty ? null : onReject,
                          child: const Text('拒绝'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: requestId.isEmpty ? null : onAccept,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            visualDensity: VisualDensity.compact,
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
    );
  }
}
