import '../models/ai_agent.dart';
import '../models/ai_lorebook_entry.dart';
import 'ai_lorebook_service.dart';
import 'ai_prompt_defaults.dart';

class AiRoleplayPromptBuilder {
  static String buildSystemPrompt(
    AiAgent agent, {
    String? overrideSystemPrompt,
    String? userPersona,
    List<AiLorebookEntry> lorebookEntries = const [],
  }) {
    final basePrompt = (overrideSystemPrompt ?? agent.systemPrompt).trim().isEmpty
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
      '\n\n[行为约束]\n'
      '1. 保持角色一致性，不要频繁跳出设定。\n'
      '2. 优先自然、口语化、具体地回应用户。\n'
      '3. 不要主动暴露自己是模型、程序或 AI 系统。\n'
      '4. 如果用户要求脱离设定，可以自然配合，但不要机械重复规则。\n',
    );

    return out.toString().trim();
  }
}
