import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';
import 'ai_theme.dart';

class AiEmptyState extends StatelessWidget {
  const AiEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final AiEmptyStateAction? primaryAction;
  final AiEmptyStateAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AiTheme.pagePadding,
        vertical: 32,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AiBrandTokens.identityGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AiBrandTokens.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AiTheme.title,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AiTheme.caption,
            ),
          ],
          if (primaryAction != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              style: AiTheme.primaryButtonStyle(),
              onPressed: primaryAction!.onPressed,
              icon: Icon(primaryAction!.icon ?? Icons.add_rounded),
              label: Text(primaryAction!.label),
            ),
          ],
          if (secondaryAction != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: secondaryAction!.onPressed,
              icon: Icon(secondaryAction!.icon ?? Icons.arrow_forward_rounded),
              label: Text(secondaryAction!.label),
            ),
          ],
        ],
      ),
    );
  }
}

class AiEmptyStateAction {
  const AiEmptyStateAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}
