import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// 小说式叙事块（明亮游戏风）。
class GameNarrativeBlock extends StatelessWidget {
  final GameNarrativeLine line;
  final VoidCallback? onHintTap;

  const GameNarrativeBlock({
    super.key,
    required this.line,
    this.onHintTap,
  });

  @override
  Widget build(BuildContext context) {
    if (line.isActionEcho) {
      return Container(
        margin: const EdgeInsets.only(top: 18, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7F7FD5).withValues(alpha: 0.12),
              const Color(0xFF86A8E7).withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.play_arrow_rounded,
                size: 16, color: Color(0xFF7F7FD5)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                line.displayContent,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF5C5C8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (line.isEvent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6F00).withValues(alpha: 0.15),
              const Color(0xFFFFB300).withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB300)),
        ),
        child: Text(
          line.displayContent,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.6,
            color: Colors.orange.shade900,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (line.isHint) {
      final content = Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: Color(0xFFFF9800)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                line.displayContent,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.brown.shade700,
                ),
              ),
            ),
            if (onHintTap != null)
              Icon(Icons.touch_app_outlined,
                  size: 16, color: Colors.brown.shade400),
          ],
        ),
      );
      if (onHintTap == null) return content;
      return InkWell(
        onTap: onHintTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    if (line.isThought) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          line.displayContent,
          style: TextStyle(
            fontSize: 14,
            height: 1.65,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final color =
        line.isHighlight ? const Color(0xFFD84315) : const Color(0xFF3D3D50);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        line.displayContent,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 16.5,
          height: 1.9,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
