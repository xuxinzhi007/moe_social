import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';
import 'ai_theme.dart';

enum AiSyncStatus { idle, syncing, success, warning, error }

class AiStatusDot extends StatelessWidget {
  const AiStatusDot({
    super.key,
    required this.status,
    this.label,
  });

  final AiSyncStatus status;
  final String? label;

  Color get _color {
    switch (status) {
      case AiSyncStatus.idle:
        return Colors.grey.shade400;
      case AiSyncStatus.syncing:
        return AiBrandTokens.secondary;
      case AiSyncStatus.success:
        return AiTheme.success;
      case AiSyncStatus.warning:
        return AiTheme.warning;
      case AiSyncStatus.error:
        return AiTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == AiSyncStatus.syncing)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _color,
            ),
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(label!, style: AiTheme.caption),
        ],
      ],
    );
  }
}
