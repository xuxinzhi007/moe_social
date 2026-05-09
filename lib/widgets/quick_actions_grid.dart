import 'package:flutter/material.dart';

import '../pages/ai/agent_list_page.dart';
import '../pages/game/game_lobby_page.dart';
import '../utils/responsive.dart';

class QuickActionsGrid extends StatelessWidget {
  final Future<void> Function(dynamic result)? onCreatePostSuccess;

  const QuickActionsGrid({
    super.key,
    this.onCreatePostSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final showComposerOnHome =
        MediaQuery.sizeOf(context).width >= 360;
    final actions = <Map<String, Object>>[
      if (!showComposerOnHome)
        {
          'icon': Icons.edit_note,
          'label': '发布动态',
          'color': const Color(0xFF7F7FD5),
          'onTap': () async {
            final result = await Navigator.pushNamed(context, '/create-post');
            if (result != null) {
              await onCreatePostSuccess?.call(result);
            }
          },
        },
      {
        'icon': Icons.photo_library,
        'label': '云相册',
        'color': const Color(0xFF4ECDC4),
        'onTap': () => Navigator.pushNamed(context, '/cloud-gallery'),
      },
      {
        'icon': Icons.contacts_rounded,
        'label': '联系人',
        'color': const Color(0xFFFF6B6B),
        'onTap': () => Navigator.pushNamed(context, '/friends'),
      },
      {
        'icon': Icons.smart_toy,
        'label': 'AI助手',
        'color': const Color(0xFFFFB347),
        'onTap': () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const AgentListPage(),
            ),
          );
        },
      },
      {
        'icon': Icons.games,
        'label': '游戏',
        'color': const Color(0xFF95E1D3),
        'onTap': () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const GameLobbyPage(),
            ),
          );
        },
      },
      {
        'icon': Icons.card_giftcard,
        'label': '抽卡',
        'color': const Color(0xFFF38181),
        'onTap': () => Navigator.pushNamed(context, '/gacha'),
      },
      {
        'icon': Icons.wallet,
        'label': '钱包',
        'color': const Color(0xFFAA96DA),
        'onTap': () => Navigator.pushNamed(context, '/wallet'),
      },
      {
        'icon': Icons.settings,
        'label': '设置',
        'color': const Color(0xFFFCBAD3),
        'onTap': () => Navigator.pushNamed(context, '/settings'),
      },
    ];

    final scheme = Theme.of(context).colorScheme;
    final horizontalPadding = Responsive.pageHorizontalPadding(context);
    final listHeight = Responsive.isCompact(context) ? 100.0 : 112.0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '快捷功能',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 每项约 52+6+文字行高+竖向 padding，90 在部分字体缩放下会溢出
          SizedBox(
            height: listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: actions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final action = actions[index];
                return _buildActionItem(
                  context,
                  icon: action['icon'] as IconData,
                  label: action['label'] as String,
                  color: action['color'] as Color,
                  onTap: action['onTap'] as VoidCallback,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
