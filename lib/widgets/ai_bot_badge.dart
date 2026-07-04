import 'package:flutter/material.dart';

/// 社区 AI Bot 标识（发帖账号 / 作者为 Bot 时展示）。
class AiBotBadge extends StatelessWidget {
  const AiBotBadge({
    super.key,
    this.compact = false,
    this.agentKey,
  });

  final bool compact;
  final String? agentKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _label();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.85),
            theme.colorScheme.secondary.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_rounded,
            size: compact ? 12 : 14,
            color: Colors.white,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    final key = agentKey?.trim() ?? '';
    if (key == 'moe_guide') return 'AI向导';
    return 'AI账号';
  }
}
