import 'package:flutter/material.dart';
import '../../../constants/feature_flags.dart';
import '../../../services/llm_endpoint_config.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../ai/llama_cpp_settings_page.dart';
import '../../ai/llm_model_config_page.dart';
import '../../ai/llm_terminal_mode_settings_page.dart';
import '../../profile/memory_timeline_page.dart';

class AiSettingsModule extends StatelessWidget {
  const AiSettingsModule({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MoeMenuCard(
      items: [
        if (FeatureFlags.showExperimentalFeatures)
          MoeMenuItem(
            icon: Icons.terminal_rounded,
            title: 'raw 调试模式（本地推理）',
            subtitle: '仅调试时开启；日常建议走服务端记忆链路',
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
                        .withValues(alpha: 0.12),
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
        if (FeatureFlags.showLocalModelSettings)
          MoeMenuItem(
            icon: Icons.dns_rounded,
            title: '本机 llama-server',
            subtitle: '配置 llama-server 地址（默认 127.0.0.1:6633）',
            color: const Color(0xFF26A69A),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LlamaCppSettingsPage(),
                ),
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
    );
  }
}
