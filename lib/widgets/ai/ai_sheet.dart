import 'package:flutter/material.dart';

import '../moe_action_row.dart';
import '../motion/moe_reveal.dart';
import '../motion/moe_sheet.dart';
import 'ai_brand_tokens.dart';
import 'ai_theme.dart';

abstract final class AiSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
    Widget? footer,
    bool isScrollControlled = true,
    double initialChildSize = 0.92,
    double minChildSize = 0.5,
    double maxChildSize = 0.95,
  }) {
    return MoeSheet.showDraggable<T>(
      context,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      backgroundColor: AiTheme.surface,
      padding: EdgeInsets.zero,
      builder: (sheetContext, scrollController) {
        return Column(
          children: [
            MoeReveal(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AiTheme.title),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle, style: AiTheme.caption),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: MoeReveal(
                  delay: const Duration(milliseconds: 40),
                  child: child,
                ),
              ),
            ),
            if (footer != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: footer,
                ),
              ),
          ],
        );
      },
    );
  }

  static Future<T?> showActions<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<AiSheetAction<T>> actions,
  }) {
    return show<T>(
      context: context,
      title: title,
      subtitle: subtitle,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      child: Column(
        children: actions
            .map(
              (action) => MoeActionRow(
                icon: action.icon,
                title: action.label,
                subtitle:
                    action.subtitle == null ? null : Text(action.subtitle!),
                iconColor: AiBrandTokens.primary,
                onTap: () => Navigator.pop(context, action.value),
              ),
            )
            .toList(),
      ),
    );
  }
}

class AiSheetAction<T> {
  const AiSheetAction({
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final T? value;
}
