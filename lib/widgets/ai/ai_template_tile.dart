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
    this.icon,
    this.gradient,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData? icon;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final tileGradient = gradient ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE7F6), Color(0xFFF3E5F5), Color(0xFFFCE4EC)],
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AiTheme.sectionGap),
      child: AiSurfaceCard(
        onTap: onTap,
        gradient: tileGradient,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AiTheme.radiusSm),
                boxShadow: [
                  BoxShadow(
                    color: AiBrandTokens.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon ?? Icons.auto_awesome_rounded,
                color: AiBrandTokens.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AiBrandTokens.titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AiBrandTokens.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AiTheme.radiusSm),
              ),
              child: Icon(
                Icons.add_rounded,
                color: AiBrandTokens.primary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
