import 'package:flutter/material.dart';

import '../../../theme/moe_theme_extension.dart';

/// 未登录时同好页主体。
class FriendsLoggedOutBody extends StatelessWidget {
  const FriendsLoggedOutBody({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moe = MoeTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: scheme.outline),
            const SizedBox(height: 18),
            Text(
              '登录后管理私信、同好与好友申请',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                height: 1.45,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: FilledButton.styleFrom(
                backgroundColor: moe.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }
}
