import 'package:flutter/material.dart';

import '../../../theme/moe_theme_extension.dart';

/// 同好页顶部分区 Tab：私信 / 同好 / 匹配 / 申请。
class FriendsHubTabStrip extends StatelessWidget {
  const FriendsHubTabStrip({
    super.key,
    required this.controller,
    required this.dmUnreadTotal,
    required this.incomingRequestCount,
  });

  final TabController controller;
  final int dmUnreadTotal;
  final int incomingRequestCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moe = MoeTheme.of(context);
    final track = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : const Color(0xFFE8ECF3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Material(
        color: track,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: TabBar(
            controller: controller,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: moe.cardBackground,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            labelColor: moe.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            splashBorderRadius: BorderRadius.circular(14),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('私信'),
                    if (dmUnreadTotal > 0) ...[
                      const SizedBox(width: 6),
                      _badge(dmUnreadTotal > 99 ? '99+' : '$dmUnreadTotal'),
                    ],
                  ],
                ),
              ),
              const Tab(text: '同好'),
              const Tab(text: '匹配'),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('申请'),
                    if (incomingRequestCount > 0) ...[
                      const SizedBox(width: 6),
                      _badge('$incomingRequestCount'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
