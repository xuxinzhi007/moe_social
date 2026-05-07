import 'package:flutter/material.dart';
import '../../../services/llm_endpoint_config.dart';
import '../../../widgets/fade_in_up.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../ai/llm_model_config_page.dart';
import '../../ai/llm_terminal_mode_settings_page.dart';
import '../../profile/memory_timeline_page.dart';

class AiSettingsModule extends StatelessWidget {
  const AiSettingsModule({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: MoeMenuCard(
        items: [
          MoeMenuItem(
            icon: Icons.terminal_rounded,
            title: '终端同款（本地 Ollama）',
            subtitle: '直连电脑 Ollama，尽量对齐终端输出',
            color: Colors.deepPurpleAccent,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LlmTerminalModeSettingsPage(),
                ),
              );
            },
            trailing: FutureBuilder<bool>(
              future: LlmEndpointConfig.isTerminalModeEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data == true;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (enabled ? Colors.green : Colors.grey)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    enabled ? '已开启' : '未开启',
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.green : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          MoeMenuItem(
            icon: Icons.psychology_rounded,
            title: '模型记忆线',
            subtitle: '查看模型记录的所有记忆',
            color: Colors.deepPurple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MemoryTimelinePage()),
              );
            },
          ),
          MoeMenuItem(
            icon: Icons.settings_suggest_rounded,
            title: 'AI 模型配置',
            subtitle: '管理 AI 模型参数和配置',
            color: Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LlmModelConfigPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
