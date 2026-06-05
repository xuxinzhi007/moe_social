import 'package:flutter/material.dart';
import '../../../constants/feature_flags.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../ai/llama_cpp_settings_page.dart';
import '../../ai/llm_model_config_page.dart';
import '../../profile/memory_timeline_page.dart';

class AiSettingsModule extends StatelessWidget {
  const AiSettingsModule({super.key});

  @override
  Widget build(BuildContext context) {
    return MoeMenuCard(
      items: [
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
