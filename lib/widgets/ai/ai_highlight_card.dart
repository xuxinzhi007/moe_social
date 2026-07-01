import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';
import 'ai_theme.dart';

/// 顶部说明/模式卡片（渐变浅底 + 统一圆角）。
class AiHighlightCard extends StatelessWidget {
  const AiHighlightCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
  });

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AiTheme.cardPadding),
      decoration: BoxDecoration(
        gradient: AiBrandTokens.identityGradient,
        borderRadius: BorderRadius.circular(AiTheme.radiusAiCard),
        border: Border.all(color: AiBrandTokens.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AiBrandTokens.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AiTheme.body.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: AiTheme.caption.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}
