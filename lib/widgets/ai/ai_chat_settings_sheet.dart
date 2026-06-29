import 'package:flutter/material.dart';

import '../../models/ai_agent.dart';
import '../../services/ai_chat_session_prefs.dart';
import 'ai_brand_tokens.dart';
import 'ai_sheet.dart';
import 'ai_theme.dart';

/// 聊天页「更多设置」：生成参数。
abstract final class AiChatSettingsSheet {
  static Future<void> show({
    required BuildContext context,
    required AiAgent agent,
    required double temperature,
    required ValueChanged<double> onTemperatureChanged,
  }) async {
    var localTemp = temperature;
    if (!context.mounted) return;

    return AiSheet.show(
      context: context,
      title: '对话设置',
      subtitle: agent.name,
      initialChildSize: 0.45,
      maxChildSize: 0.6,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
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
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
