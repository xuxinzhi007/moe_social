import 'package:flutter/material.dart';

import '../../services/ai_memory_orchestrator.dart';
import 'ai_brand_tokens.dart';
import 'ai_theme.dart';

/// 聊天页记忆注入/写入状态条（上回合结果一目了然）。
class AiMemoryStatusStrip extends StatelessWidget {
  const AiMemoryStatusStrip({
    super.key,
    this.enrich,
    this.onTapSettings,
  });

  final AiMemoryEnrichResult? enrich;
  final VoidCallback? onTapSettings;

  @override
  Widget build(BuildContext context) {
    final orchestrator = AiMemoryOrchestrator();
    final stats = orchestrator.turnStats;
    final mode = enrich?.mode;
    final paused = mode == AiMemoryMode.disabled;

    final Color accent = paused
        ? Colors.orange.shade700
        : (enrich != null && enrich!.injectedCount > 0)
            ? AiBrandTokens.primary
            : Colors.blueGrey.shade700;

    final statusText = enrich?.statusLine ??
        (paused ? '记忆未开启' : '发消息后显示注入与写入结果');

    return Material(
      color: accent.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTapSettings,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                paused ? Icons.pause_circle_outline : Icons.psychology_rounded,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: AiTheme.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    if (!paused && stats.updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '上回合 · 注入 ${stats.lastInjectedCount} 条 · '
                        '写入 ${stats.lastSavedCount} 条',
                        style: AiTheme.caption.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (stats.hasLearnError) ...[
                        const SizedBox(height: 2),
                        Text(
                          stats.lastLearnError!,
                          style: AiTheme.caption.copyWith(
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (onTapSettings != null)
                Icon(Icons.tune_rounded, size: 18, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
