import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';
import 'ai_scaffold.dart';
import 'ai_status_dot.dart';
import 'ai_theme.dart';

/// 酒馆子页统一骨架：AiScaffold + 下拉刷新 + 一致内边距（避免每页各自拼 ListView）。
class AiListPageLayout extends StatelessWidget {
  const AiListPageLayout({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.children,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.syncStatus,
    this.syncLabel,
    this.bottom,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final AiSyncStatus? syncStatus;
  final String? syncLabel;
  final PreferredSizeWidget? bottom;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return AiScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      bottom: bottom,
      floatingActionButton: floatingActionButton,
      syncStatus: syncStatus,
      syncLabel: syncLabel,
      body: RefreshIndicator(
        color: AiBrandTokens.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: padding ??
              const EdgeInsets.fromLTRB(
                AiTheme.pagePadding,
                AiTheme.sectionGap,
                AiTheme.pagePadding,
                88,
              ),
          children: children,
        ),
      ),
    );
  }
}
