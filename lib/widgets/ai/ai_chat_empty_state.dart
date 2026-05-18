import 'package:flutter/material.dart';
import 'ai_brand_tokens.dart';

/// AI 对话/生成页的空状态占位。
class AiChatEmptyState extends StatelessWidget {
  const AiChatEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.forum_outlined,
    this.suggestions = const [],
    this.onSuggestionTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: AiBrandTokens.heroGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AiBrandTokens.primary.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AiBrandTokens.titleColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Colors.grey.shade600,
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '试试这些开场',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: suggestions.map((text) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onSuggestionTap == null
                          ? null
                          : () => onSuggestionTap!(text),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AiBrandTokens.primary.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AiBrandTokens.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
