import 'package:flutter/material.dart';

import '../../models/ai_agent.dart';
import '../../pages/ai/ai_provider_profiles_page.dart';
import '../../services/ai_chat_session_prefs.dart';
import '../../services/ai_memory_learn_result.dart';
import '../../services/ai_memory_orchestrator.dart';
import '../../services/ai_provider_service.dart';
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
    required AiMemoryTurnStats turnStats,
    required VoidCallback onOpenMemoryManager,
    required ValueChanged<double> onTemperatureChanged,
  }) async {
    var localTemp = temperature;
    final profile =
        await AiProviderService().resolveProfile(agent.providerProfileId);
    final memoryToolsAdvanced =
        profile.supportsToolCalls && !profile.isBackendOllama;
    if (!context.mounted) return;

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
              _MemoryStatusCard(
                status: memoryStatus,
                turnStats: turnStats,
                memoryToolsAdvanced: memoryToolsAdvanced,
                providerName: profile.name,
                onManageProvider: profile.isBuiltinBackend
                    ? null
                    : () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AiProviderProfilesPage(),
                          ),
                        );
                      },
              ),
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
  const _MemoryStatusCard({
    required this.status,
    required this.turnStats,
    required this.memoryToolsAdvanced,
    required this.providerName,
    this.onManageProvider,
  });

  final AiMemoryEnrichResult status;
  final AiMemoryTurnStats turnStats;
  final bool memoryToolsAdvanced;
  final String providerName;
  final VoidCallback? onManageProvider;

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
          if (!paused) ...[
            const SizedBox(height: 8),
            Text(
              '上回合注入：${turnStats.lastInjectedCount} 条 · '
              '写入：${turnStats.lastSavedCount} 条',
              style: AiTheme.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            if (turnStats.hasLearnError) ...[
              const SizedBox(height: 4),
              Text(
                turnStats.lastLearnError!,
                style: AiTheme.caption.copyWith(color: Colors.orange.shade800),
              ),
            ],
            if (status.availableCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                status.injectedCount > 0
                    ? '本轮已在对话上下文中参考 ${status.injectedCount} 条相关记忆。'
                    : '记忆库共 ${status.availableCount} 条，当前话题暂无强相关注入。',
                style: AiTheme.caption,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '默认：发消息前自动查询后端记忆库并注入（不增加聊天次数）。',
              style: AiTheme.caption,
            ),
            const SizedBox(height: 4),
            Text(
              memoryToolsAdvanced
                  ? '高级多轮工具：已开启（$providerName）。可用：检索/读取/保存/列表/日记/删除记忆，约多 1～3 轮中转'
                  : '高级多轮工具：未开启（推荐保持关闭）。',
              style: AiTheme.caption.copyWith(
                color: memoryToolsAdvanced
                    ? Colors.orange.shade800
                    : AiBrandTokens.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onManageProvider != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onManageProvider,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('管理模型来源与记忆工具'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
