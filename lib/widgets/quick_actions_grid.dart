import 'package:flutter/material.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'icon': Icons.edit_note,
        'label': '发布动态',
        'color': const Color(0xFF7F7FD5),
        'onTap': () => Navigator.pushNamed(context, '/create-post'),
      },
      {
        'icon': Icons.photo_library,
        'label': '云相册',
        'color': const Color(0xFF4ECDC4),
        'onTap': () => Navigator.pushNamed(context, '/cloud-gallery'),
      },
      {
        'icon': Icons.people,
        'label': '好友',
        'color': const Color(0xFFFF6B6B),
        'onTap': () => Navigator.pushNamed(context, '/friends'),
      },
      {
        'icon': Icons.smart_toy,
        'label': 'AI助手',
        'color': const Color(0xFFFFB347),
        'onTap': () => Navigator.pushNamed(context, '/home', arguments: 2),
      },
      {
        'icon': Icons.games,
        'label': '游戏',
        'color': const Color(0xFF95E1D3),
        'onTap': () => Navigator.pushNamed(context, '/home', arguments: 3),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Text(
                '快捷功能',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _buildActionItem(
                icon: action['icon'] as IconData,
                label: action['label'] as String,
                color: action['color'] as Color,
                onTap: action['onTap'] as VoidCallback,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
