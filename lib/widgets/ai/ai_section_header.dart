import 'package:flutter/material.dart';

import 'ai_theme.dart';

class AiSectionHeader extends StatelessWidget {
  const AiSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AiTheme.pagePadding,
        AiTheme.sectionGapLg,
        AiTheme.pagePadding,
        AiTheme.sectionGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AiTheme.display.copyWith(fontSize: 20)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AiTheme.caption),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
