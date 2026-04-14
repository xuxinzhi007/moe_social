import 'package:flutter/material.dart';
import '../../../services/llm_endpoint_config.dart';
import '../../../widgets/fade_in_up.dart';
import '../../../widgets/moe_menu_card.dart';
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
                MaterialPageRoute(builder: (context) => const MemoryTimelinePage()),
              );
            },
          ),
          MoeMenuItem(
            icon: Icons.settings_suggest_rounded,
            title: 'AI 模型配置',
            subtitle: '管理 AI 模型参数和配置',
            color: Colors.indigo,
            onTap: () => _showAIModelConfigSheet(context),
          ),
        ],
      ),
    );
  }

  void _showAIModelConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'AI 模型配置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.model_training_rounded, color: Colors.indigo, size: 20),
                        ),
                        title: const Text('模型参数设置', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('调整模型的温度、最大 tokens 等参数', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 显示模型参数设置
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('功能开发中')),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_rounded, color: Colors.purple, size: 20),
                        ),
                        title: const Text('云端模型', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('管理云端 AI 模型连接', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 显示云端模型设置
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('功能开发中')),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_fire_department_rounded, color: Colors.teal, size: 20),
                        ),
                        title: const Text('模型性能优化', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('优化模型运行性能和响应速度', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 显示模型性能优化设置
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('功能开发中')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
