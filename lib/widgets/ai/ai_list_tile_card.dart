import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';
import 'ai_chip.dart';
import 'ai_surface_card.dart';
import 'ai_theme.dart';

class AiListTileCard extends StatelessWidget {
  const AiListTileCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.tags = const [],
    this.onTap,
    this.statusDot,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<String> tags;
  final VoidCallback? onTap;
  final Widget? statusDot;

  @override
  Widget build(BuildContext context) {
    return AiSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AiBrandTokens.titleColor,
                        ),
                      ),
                    ),
                    if (statusDot != null) statusDot!,
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: AiTheme.caption),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((t) => AiTag(label: t)).toList(),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}
