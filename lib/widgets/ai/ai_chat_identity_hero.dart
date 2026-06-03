import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';

class AiChatIdentityHero extends StatelessWidget {
  const AiChatIdentityHero({
    super.key,
    required this.modelName,
    required this.promptReady,
    required this.personaMounted,
    required this.memoryLabel,
    required this.isSyncingModelPrompt,
  });

  final String modelName;
  final bool promptReady;
  final bool personaMounted;
  final String memoryLabel;
  final bool isSyncingModelPrompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AiBrandTokens.identityGradient,
        border: Border.all(
          color: AiBrandTokens.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AiBrandTokens.userBubbleGradient,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _IdentityChip('模型', modelName),
                _IdentityChip('人设', promptReady ? '已启用' : '未设置'),
                if (personaMounted) const _IdentityChip('Persona', '已挂载'),
                _IdentityChip('记忆', memoryLabel),
                if (isSyncingModelPrompt) const _IdentityChip('状态', '同步中'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AiBrandTokens.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        '$label · $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AiBrandTokens.primary,
        ),
      ),
    );
  }
}
