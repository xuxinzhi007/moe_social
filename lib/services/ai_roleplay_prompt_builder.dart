import '../models/ai_agent.dart';
import '../models/ai_lorebook_entry.dart';
import 'ai_lorebook_service.dart';
import 'ai_prompt_defaults.dart';

class AiRoleplayPromptBuilder {
  /// 带人设/场景/示例对话的角色卡，账号记忆注入方式与通用助手不同。
  static bool isRoleplayStyleAgent(AiAgent agent) {
    return agent.persona.trim().isNotEmpty ||
        agent.scenario.trim().isNotEmpty ||
        agent.exampleDialogues.trim().isNotEmpty;
  }

  static String buildSystemPrompt(
    AiAgent agent, {
    String? overrideSystemPrompt,
    String? userPersona,
    List<AiLorebookEntry> lorebookEntries = const [],
  }) {
    final basePrompt =
        (overrideSystemPrompt ?? agent.systemPrompt).trim().isEmpty
            ? AiPromptDefaults.defaultAgentSystemPrompt
            : (overrideSystemPrompt ?? agent.systemPrompt).trim();

    final out = StringBuffer(basePrompt);

    if (agent.persona.trim().isNotEmpty) {
      out.write('\n\n[角色人设]\n${agent.persona.trim()}');
    }
    if (agent.scenario.trim().isNotEmpty) {
      out.write('\n\n[场景设定]\n${agent.scenario.trim()}');
    }
    if (agent.exampleDialogues.trim().isNotEmpty) {
      out.write('\n\n[示例对话风格]\n${agent.exampleDialogues.trim()}');
    }
    if (userPersona != null && userPersona.trim().isNotEmpty) {
      out.write('\n\n[用户 Persona]\n${userPersona.trim()}');
    }
    if (lorebookEntries.isNotEmpty) {
      out.write(
        '\n\n${AiLorebookService().buildPromptSection(lorebookEntries)}',
      );
    }

    out.write(
      '\n\n[扮演约束]\n'
      '1. 你就是这个角色本人，不是在「描述」或「模拟」角色；用第一人称沉浸回应。\n'
      '2. 禁止说自己是 AI/模型/助手，禁止用政策式拒答；遇限制时用角色口吻绕开或转移话题。\n'
      '3. 保持语气、用词、知识与世界观一致；用户未要求 OOC 时不要跳出设定。\n'
      '4. 优先接住用户情绪与意图，再推进对话，避免机械重复上述规则。\n',
    );

    return out.toString().trim();
  }
}
