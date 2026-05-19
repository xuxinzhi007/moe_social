import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';
import 'ai_surface_card.dart';
import 'ai_theme.dart';

/// 酒馆模板行（世界书/角色等列表顶部的可点模板项）。
class AiTemplateTile extends StatelessWidget {
  const AiTemplateTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AiTheme.sectionGap),
      child: AiSurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AiTheme.cardPadding),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AiBrandTokens.heroGradient,
                borderRadius: BorderRadius.circular(AiTheme.radiusSm),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AiTheme.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AiTheme.caption),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline_rounded,
              color: AiBrandTokens.primary.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}
