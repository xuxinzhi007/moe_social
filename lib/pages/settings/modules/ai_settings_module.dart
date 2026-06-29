import 'package:flutter/material.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../ai/llm_model_config_page.dart';

class AiSettingsModule extends StatelessWidget {
  const AiSettingsModule({super.key});

  @override
  Widget build(BuildContext context) {
    return MoeMenuCard(
      items: [
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
