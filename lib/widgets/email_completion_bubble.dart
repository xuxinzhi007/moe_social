import 'package:flutter/material.dart';

/// 叠在邮箱输入框下方的轻量候选层，不占文档流高度（由外层 [Stack] + [Positioned] 承载）。
class EmailCompletionBubble extends StatelessWidget {
  const EmailCompletionBubble({
    super.key,
    required this.candidates,
    required this.onSelected,
    this.accentColor = const Color(0xFF7F7FD5),
  });

  final List<String> candidates;
  final ValueChanged<String> onSelected;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alternate_email_rounded,
                    size: 15, color: accentColor.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Text(
                  '常用后缀',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final full in candidates)
                  Semantics(
                    button: true,
                    label: '补全邮箱后缀 ${full.contains('@') ? full.split('@').last : full}',
                    child: Material(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      // 用 onTapDown：在 ScrollView 里比 onTap 更不容易被「轻滑」吞掉；且早于失焦时序。
                      child: InkWell(
                        onTapDown: (_) => onSelected(full),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Text(
                            full.contains('@') ? full.split('@').last : full,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accentColor.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
