import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';

/// 通用操作行：图标 + 标题 + 副标题 + 尾部组件。
class MoeActionRow extends StatelessWidget {
  const MoeActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.iconColor,
    this.iconBackgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = 14,
    this.showDefaultTrailing = true,
    this.titleStyle,
    this.selected = false,
    this.backgroundColor,
    this.borderColor,
    this.selectedBackgroundColor,
    this.selectedBorderColor,
    this.selectedTitleColor,
    this.subtitleColor,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showDefaultTrailing;
  final TextStyle? titleStyle;
  final bool selected;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? selectedBackgroundColor;
  final Color? selectedBorderColor;
  final Color? selectedTitleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? MoeTokens.primary;
    final resolvedIconBackground =
        iconBackgroundColor ?? resolvedIconColor.withValues(alpha: 0.12);
    final resolvedBackground = selected
        ? (selectedBackgroundColor ?? resolvedIconColor.withValues(alpha: 0.1))
        : backgroundColor;
    final resolvedBorderColor = selected
        ? (selectedBorderColor ?? resolvedIconColor.withValues(alpha: 0.28))
        : borderColor;
    final resolvedTitleStyle = titleStyle ??
        TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? (selectedTitleColor ?? resolvedIconColor) : null,
        );
    final resolvedSubtitleColor = subtitleColor ??
        (selected
            ? resolvedIconColor.withValues(alpha: 0.85)
            : Colors.grey[600]);

    return Container(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: resolvedBorderColor == null
            ? null
            : Border.all(color: resolvedBorderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: resolvedIconBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: resolvedIconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolvedTitleStyle,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        DefaultTextStyle(
                          style: TextStyle(
                            color: resolvedSubtitleColor,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (showDefaultTrailing && onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
