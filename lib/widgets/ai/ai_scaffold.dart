import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';
import 'ai_status_dot.dart';

class AiScaffold extends StatelessWidget {
  const AiScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.syncStatus,
    this.syncLabel,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final AiSyncStatus? syncStatus;
  final String? syncLabel;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: subtitle == null
            ? Text(title)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17)),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
        backgroundColor: backgroundColor ?? AiBrandTokens.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          if (syncStatus != null && syncStatus != AiSyncStatus.idle)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AiBrandTokens.primary.withValues(alpha: 0.06),
              child: AiStatusDot(status: syncStatus!, label: syncLabel),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
