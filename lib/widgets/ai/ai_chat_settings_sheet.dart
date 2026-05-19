import 'package:flutter/material.dart';

import '../../models/ai_agent.dart';
import '../../services/ai_chat_session_prefs.dart';
import '../../services/ai_memory_orchestrator.dart';
import 'ai_brand_tokens.dart';
import 'ai_sheet.dart';
import 'ai_theme.dart';

/// 聊天页「更多设置」：生成参数 + 记忆状态说明。
abstract final class AiChatSettingsSheet {
  static Future<void> show({
    required BuildContext context,
    required AiAgent agent,
    required double temperature,
    required AiMemoryEnrichResult memoryStatus,
    required VoidCallback onOpenMemoryManager,
    required ValueChanged<double> onTemperatureChanged,
  }) {
    var localTemp = temperature;
    return AiSheet.show(
      context: context,
      title: '对话设置',
      subtitle: agent.name,
      initialChildSize: 0.55,
      maxChildSize: 0.75,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MemoryStatusCard(status: memoryStatus),
              const SizedBox(height: 20),
              Text('生成温度', style: AiTheme.title.copyWith(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                '越高越发散，越低越稳定。仅影响本角色聊天。',
                style: AiTheme.caption.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: localTemp,
                      min: 0,
                      max: 1.5,
                      divisions: 15,
                      label: localTemp.toStringAsFixed(2),
                      activeColor: AiBrandTokens.primary,
                      onChanged: (v) {
                        setModalState(() => localTemp = v);
                        onTemperatureChanged(v);
                        AiChatSessionPrefs.setTemperature(agent.id, v);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      localTemp.toStringAsFixed(2),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onOpenMemoryManager();
                },
                icon: const Icon(Icons.psychology_rounded),
                label: const Text('打开记忆库'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AiBrandTokens.primary,
                  side: BorderSide(
                    color: AiBrandTokens.primary.withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemoryStatusCard extends StatelessWidget {
  const _MemoryStatusCard({required this.status});

  final AiMemoryEnrichResult status;

  @override
  Widget build(BuildContext context) {
    final paused = status.mode == AiMemoryMode.disabled;
    final color = paused
        ? Colors.orange.shade700
        : status.availableCount > 0
            ? AiBrandTokens.primary
            : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                paused ? Icons.pause_circle_outline : Icons.psychology_rounded,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                paused ? '记忆已暂停' : '记忆状态',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.statusLine,
            style: AiTheme.body.copyWith(height: 1.45),
          ),
          if (!paused && status.availableCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              status.injectedByServer
                  ? '本轮由服务端在请求时注入相关记忆。'
                  : '本轮已向模型注入 ${status.injectedCount} 条相关记忆。',
              style: AiTheme.caption,
            ),
          ],
        ],
      ),
    );
  }
}
