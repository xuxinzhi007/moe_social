import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../ai/ai_brand_tokens.dart';

/// 快捷行动按钮栏
class GameQuickActions extends StatelessWidget {
  final List<(String, String)> actions;
  final ValueChanged<String> onTap;

  const GameQuickActions({
    super.key,
    required this.actions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (label, value) in actions) ...[
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                elevation: 1,
                shadowColor:
                    AiBrandTokens.primary.withValues(alpha: 0.15),
                child: InkWell(
                  onTap: () => onTap(value),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Text(
                      label == value ? label : '$label $value',
                      style: TextStyle(
                        fontSize: 13,
                        color: MoeTokens.bodyText,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
