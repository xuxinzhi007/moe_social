import 'package:flutter/material.dart';

import '../../services/companion_service.dart';
import '../../widgets/ai/ai_brand_tokens.dart';

class MemoryConflictCard extends StatelessWidget {
  const MemoryConflictCard({
    super.key,
    required this.conflict,
    required this.onAccept,
    required this.onReject,
  });

  final CompanionMemoryConflictData conflict;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D5A6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_problem_rounded,
                  size: 18, color: Color(0xFFB46B00)),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  '这段记忆需要你确认',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AiBrandTokens.titleColor,
                  ),
                ),
              ),
              Text(
                '${(conflict.confidence * 100).round()}%',
                style: TextStyle(color: Colors.brown.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'TA 记录到了不同的说法。选择后会立即影响之后的对话。',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF806847),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            conflict.candidateContent,
            style: const TextStyle(
              color: AiBrandTokens.titleColor,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onReject, child: const Text('保留原记忆')),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: AiBrandTokens.primary,
                ),
                child: const Text('采用新记忆'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
