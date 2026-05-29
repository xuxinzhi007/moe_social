import 'package:flutter/material.dart';

import '../theme/moe_theme_extension.dart';
import '../theme/moe_tokens.dart';
import 'custom_button.dart';

class MoeEmptyStateAction {
  const MoeEmptyStateAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

/// 全局空态 / 错误态占位（图标 + 文案 + 可选 CTA）。
class MoeEmptyState extends StatelessWidget {
  const MoeEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.primaryAction,
    this.secondaryAction,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final MoeEmptyStateAction? primaryAction;
  final MoeEmptyStateAction? secondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    final vertical = compact ? 16.0 : 32.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: vertical),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 64 : 88,
            height: compact ? 64 : 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  moe.primary.withValues(alpha: 0.12),
                  moe.secondary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 30 : 40,
              color: moe.primary,
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: MoeTokens.titleText,
              height: 1.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: MoeTokens.hintText,
                height: 1.5,
              ),
            ),
          ],
          if (primaryAction != null) ...[
            SizedBox(height: compact ? 16 : 24),
            CustomButton(
              text: primaryAction!.label,
              onPressed: primaryAction!.onPressed,
              backgroundColor: moe.primary,
              width: 200,
              elevation: 0,
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
