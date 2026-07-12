import 'package:flutter/material.dart';

import '../utils/main_tab_navigation.dart';
import '../utils/responsive.dart';
import 'motion/moe_pressable.dart';
import 'motion/moe_reveal.dart';

class QuickActionsGrid extends StatelessWidget {
  final Future<void> Function(dynamic result)? onCreatePostSuccess;

  const QuickActionsGrid({
    super.key,
    this.onCreatePostSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Map<String, Object>>[
      {
        'icon': Icons.edit_note_rounded,
        'label': '发动态',
        'hint': '记录现在',
        'color': const Color(0xFF7F7FD5),
        'onTap': () async {
          final result = await Navigator.pushNamed(context, '/create-post');
          if (result != null) {
            await onCreatePostSuccess?.call(result);
          }
        },
      },
      {
        'icon': Icons.forum_rounded,
        'label': '社区',
        'hint': '找同好',
        'color': const Color(0xFF5B8DEF),
        'onTap': () => Navigator.pushNamed(context, '/community'),
      },
      {
        'icon': Icons.contacts_rounded,
        'label': '联系人',
        'hint': '看消息',
        'color': const Color(0xFFFF6B6B),
        'onTap': () => Navigator.pushNamed(context, '/friends'),
      },
      {
        'icon': Icons.photo_library_rounded,
        'label': '云相册',
        'hint': '翻照片',
        'color': const Color(0xFF4ECDC4),
        'onTap': () => Navigator.pushNamed(context, '/cloud-gallery'),
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'label': 'AI 互动',
        'hint': '找灵感',
        'color': const Color(0xFFFFB347),
        'onTap': () => openMainTab(context, 2),
      },
      {
        'icon': Icons.settings_rounded,
        'label': '设置',
        'hint': '调偏好',
        'color': const Color(0xFFF39BC8),
        'onTap': () => Navigator.pushNamed(context, '/settings'),
      },
    ];

    final scheme = Theme.of(context).colorScheme;
    final horizontalPadding = Responsive.pageHorizontalPadding(context);

    return MoeReveal(
      child: Container(
        margin: EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 8),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            final columns = isNarrow ? 3 : 6;
            final spacing = 10.0;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * spacing) / columns;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7F7FD5), Color(0xFF9E8CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.flash_on_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '常用入口',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '把最常用的动作收在这里，少一点跳转负担',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: actions.map((action) {
                    return SizedBox(
                      width: itemWidth,
                      child: _QuickActionTile(
                        icon: action['icon'] as IconData,
                        label: action['label'] as String,
                        hint: action['hint'] as String,
                        color: action['color'] as Color,
                        onTap: action['onTap'] as VoidCallback,
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              hint,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
